# Builder for the throwaway Debian test VM used to run AI coding-agent
# harnesses (see default.nix for the options and the NixOS wiring).
#
# Produces three things:
#   baseImage - the pinned Debian qcow2 from the store
#   seedIso   - the cloud-init NoCloud seed (user-data + meta-data)
#   script    - the `ai-test-vm` launcher that boots, attaches and disposes of
#               throwaway per-session images on top of baseImage
#
# The per-session image is a qcow2 overlay that is deleted on shutdown, so the
# guest's home directory and anything the agent installs are thrown away while
# the host workspace folder survives.
{
  username,
  workspaceDir ? "/home/${username}/ai-workspace",
  memorySize ? 4096,
  cores ? 4,
  diskSize ? "16G",
  sshPort ? 2222,
  guestWorkspace ? "/home/${username}/workspace",
  shareTag ? "aiworkspace",
  # the generic (not genericcloud) image on purpose: Debian's cloud kernel is
  baseImageUrl ? "https://cloud.debian.org/images/cloud/trixie/20261001-2618/debian-13-generic-amd64-20261001-2618.qcow2",
  baseImageHash ? "sha256-B/n+Bf58sXAgRwNIMBULrd1myL4G4jO7ImyEqoonUmM=",
  pkgs,
}:
let
  inherit (pkgs) lib;

  # systemd derives .mount unit names from the escaped path: "/" becomes "-"
  # and the leading separator is dropped, so /home/xela/workspace becomes
  # home-xela-workspace.mount
  guestMountUnit = lib.removePrefix "-" (lib.replaceStrings [ "/" ] [ "-" ] guestWorkspace);

  cloudInit = import ./cloud-init.nix {
    inherit
      guestWorkspace
      shareTag
      username
      ;
    mountUnit = guestMountUnit;
    authorizedKey = sshPubKey;
  };

  baseImage = pkgs.fetchurl {
    name = "debian-13-generic-amd64";
    url = baseImageUrl;
    hash = baseImageHash;
  };

  # throwaway key baked into the base image: the VM is only ever reachable on
  # 127.0.0.1 and is discarded after every session, so it protects nothing
  sshKey = pkgs.runCommand "ai-test-vm-ssh-key" { nativeBuildInputs = [ pkgs.openssh ]; } ''
    mkdir -p "$out"
    ssh-keygen -q -t ed25519 -N "" -C ai-test-vm -f "$out/id_ed25519"
    chmod 0600 "$out/id_ed25519"
  '';

  sshPubKey = builtins.readFile "${sshKey}/id_ed25519.pub";

  userData = pkgs.writeText "ai-test-vm-user-data" (
    "#cloud-config\n" + builtins.toJSON cloudInit.userData
  );
  metaData = pkgs.writeText "ai-test-vm-meta-data" (builtins.toJSON cloudInit.metaData);

  seedIso = pkgs.runCommand "ai-test-vm-seed.iso" { nativeBuildInputs = [ pkgs.libisoburn ]; } ''
    mkdir -p "$out" "$TMPDIR/seed"
    install -m 0644 ${userData} "$TMPDIR/seed/user-data"
    install -m 0644 ${metaData} "$TMPDIR/seed/meta-data"
    # cloud-init looks for an ISO9660 volume labelled "cidata"
    ${pkgs.libisoburn}/bin/xorriso -as mkisofs -quiet -o "$out/seed.iso" \
      -volid cidata -rock -joliet "$TMPDIR/seed" >/dev/null
  '';

  # changing the guest image, the seed (cloud-init) or the disk size has to
  # produce a new base image, everything else is a per-session overlay
  configHash = builtins.substring 0 12 (
    builtins.hashString "sha256" "${baseImage} ${seedIso} ${diskSize}"
  );

  script = pkgs.writeShellApplication {
    name = "ai-test-vm";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnutar
      pkgs.openssh
      pkgs.qemu_kvm # qemu-system-x86_64 + qemu-img
      pkgs.virtiofsd
    ];
    text = ''
      state=''${AI_VM_STATE_DIR:-$HOME/.local/state}/ai-test-vm
      workspace=''${AI_VM_WORKSPACE:-${workspaceDir}}
      mem=''${AI_VM_MEMORY:-${toString memorySize}}
      cores=''${AI_VM_CORES:-${toString cores}}
      disk=''${AI_VM_DISK:-${diskSize}}
      port=''${AI_VM_PORT:-${toString sshPort}}

      base=$state/base-${configHash}.qcow2
      session=$state/session.qcow2
      pidfile=$state/qemu.pid
      vfsd_sock=$state/virtiofsd.sock
      vfsd_pid=
      console=$state/console.log

      # pid of this launcher; the heartbeat loop below lives on only while it
      # does, which is what arms the guest's dead-man's switch
      main_pid=$BASHPID
      hb_pid=

      image=${baseImage}
      seed=${seedIso}/seed.iso
      key=${sshKey}/id_ed25519

      # destination last, so callers can just append a command
      ssh_args=(
        -i "$key"
        -p "$port"
        -o IdentitiesOnly=yes
        -o StrictHostKeyChecking=no
        -o UserKnownHostsFile=/dev/null
        -o LogLevel=ERROR
        -o ConnectTimeout=5
        -o BatchMode=yes
        ${username}@127.0.0.1
      )

      msg() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
      die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

      # shellcheck disable=SC2029 # ssh_args is ours, expanding it locally is the point
      vm_ssh() { ssh "''${ssh_args[@]}" "$@"; }

      vm_running() { [ -s "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }

      # graceful poweroff: the guest flushes the share before systemd tears
      # it down, then qemu goes away on its own
      stop_vm() {
        if vm_running; then
          msg "shutting the VM down"
          vm_ssh "sudo -n systemctl poweroff" >/dev/null 2>&1 || true
          local i=0
          while vm_running && [ $i -lt 300 ]; do sleep 0.2; i=$((i + 1)); done
          vm_running && kill "$(cat "$pidfile")" 2>/dev/null || true
        fi
        if [ -n "''${vfsd_pid:-}" ]; then
          kill "$vfsd_pid" 2>/dev/null || true
          vfsd_pid=
        fi
        rm -f "$pidfile" "$session" "$vfsd_sock"
      }

      # The guest powers itself off once the heartbeat file goes stale for
      # 60s, so a launcher that dies without running cleanup (kitty window
      # closed, ssh dropped, killed) still cannot leave the VM behind. The
      # loop itself exits as soon as this launcher is gone, so the beats stop
      # exactly when we do.
      heartbeat() {
        while kill -0 "$main_pid" 2>/dev/null; do
          # closing the kitty window revokes the launcher's tty without
          # necessarily killing it; /proc then reports the fd as deleted.
          # Stop beating so the guest watchdog powers the VM off, and poke
          # the launcher so it cleans up if/once it notices.
          case "$(readlink "/proc/$main_pid/fd/1" 2>/dev/null)" in
            *deleted*)
              kill -TERM "$main_pid" 2>/dev/null || true
              break
              ;;
          esac
          vm_ssh "sudo -n touch /var/lib/ai-vm/heartbeat" >/dev/null 2>&1 || true
          sleep 10
        done
      }

      start_heartbeat() {
        heartbeat &
        hb_pid=$!
      }

      stop_heartbeat() {
        if [ -n "''${hb_pid:-}" ]; then
          kill "$hb_pid" 2>/dev/null || true
          hb_pid=
        fi
      }

      cleanup() {
        local rc=$?
        trap - EXIT INT TERM HUP PIPE
        # the terminal can be gone by now (kitty window closed), so teardown
        # talks to the log file instead of the pty it may no longer have
        stop_heartbeat
        stop_vm >>"$state/launcher.log" 2>&1 || true
        exit $rc
      }

      usage() {
        cat <<EOF
      ai-test-vm - throwaway Debian VM for running AI coding-agent tests

      usage: ai-test-vm [command]

        run         boot a fresh throwaway VM, drop into a shell, and throw the
                    VM away when that shell exits (default)
        shell       attach a shell to an already running VM
        provision   rebuild the base image (apt packages)
        status      show images, workspace and VM state
        nuke        delete the base image and all VM state

      environment:
        AI_VM_WORKSPACE  host folder shared into the guest (${workspaceDir})
        AI_VM_MEMORY     guest RAM in MiB (${toString memorySize})
        AI_VM_CORES      guest vCPUs (${toString cores})
        AI_VM_DISK       guest disk size (${diskSize})
        AI_VM_PORT       host ssh port, 127.0.0.1 only (${toString sshPort})
        AI_VM_STATE_DIR  images and logs (\$HOME/.local/state/ai-test-vm)
      EOF
      }

      preflight() {
        [ -e /dev/kvm ] || die "/dev/kvm is missing: this launcher needs KVM acceleration"
        [ -r /dev/kvm ] && [ -w /dev/kvm ] || die "/dev/kvm is not usable by $(id -un)"
        mkdir -p "$state"
        if vm_running; then
          die "a VM is already running (pid $(cat "$pidfile")) - use: ai-test-vm shell"
        fi
      }

      # whatever is being tested has to be in the shared folder, this launcher
      # does not care what it is
      ensure_workspace() {
        [ -d "$workspace" ] ||
          die "$workspace does not exist yet - it is created by systemd-tmpfiles, run: sudo systemctl-tmpfiles --create $workspace"
      }

      start_vm() { # disk log
        rm -f "$vfsd_sock"
        ${pkgs.virtiofsd}/bin/virtiofsd --xattr --socket-path "$vfsd_sock" --sandbox none --seccomp none --cache auto --shared-dir "$workspace" &
        vfsd_pid=$!
        local i=0
        while [ $i -lt 100 ] && [ ! -S "$vfsd_sock" ]; do
          sleep 0.1
          i=$((i + 1))
        done
        [ -S "$vfsd_sock" ] || die "virtiofsd failed to create $vfsd_sock"
        qemu-system-x86_64 \
          -name ai-test-vm \
          -machine q35,accel=kvm -cpu host \
          -m "$mem" -smp "$cores" \
          -display none -monitor none -serial "file:$2" \
          -nic "user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:$port-:22,dns=1.1.1.1" \
          -drive "file=$1,if=virtio,format=qcow2,cache=writeback" \
          -drive "file=$seed,if=virtio,format=raw,readonly=on" \
          -device virtio-rng-pci \
          -chardev "socket,id=vfs0,path=$vfsd_sock" \
          -device vhost-user-fs-pci,chardev=vfs0,tag=${shareTag} \
          -pidfile "$pidfile" -daemonize
      }

      wait_boot() { # timeout_s
        local i=0
        while [ $i -lt $(( $1 * 2 )) ]; do
          vm_ssh true 2>/dev/null && return
          sleep 0.5
          i=$((i + 1))
        done
        die "the VM did not come up within $1s - see $console"
      }

      ensure_guest_share() {
        vm_ssh "mountpoint -q ${guestWorkspace}" 2>/dev/null && return
        msg "the workspace share was not mounted at boot, mounting it now"
        vm_ssh "sudo -n systemctl restart ${guestMountUnit}.mount" >/dev/null 2>&1 || true
        vm_ssh "mountpoint -q ${guestWorkspace}" ||
          die "could not mount ${guestWorkspace} in the guest - see $console"
      }

      provision() {
        preflight
        ensure_workspace
        # same teardown guarantee as run: a provision that dies mid-apt must
        # not leave qemu behind (run_vm installs its own trap afterwards)
        trap cleanup EXIT INT TERM HUP
        rm -f "$base"
        msg "creating the base image ($disk) - this runs once per configuration change"
        install -m 0644 "$image" "$base.part"
        qemu-img resize -f qcow2 "$base.part" "$disk"
        mv "$base.part" "$base"

        start_vm "$base" "$state/provision-console.log"
        msg "first boot: cloud-init is installing the guest packages"
        wait_boot 300
        start_heartbeat
        local i=0
        while [ $i -lt 3600 ]; do
          vm_ssh "test -f /var/lib/ai-vm/provisioned" 2>/dev/null && break
          sleep 5
          i=$((i + 5))
        done
        vm_ssh "test -f /var/lib/ai-vm/provisioned" ||
          die "provisioning did not finish - see $state/provision-console.log"
        ensure_guest_share

        # close the guest cleanly so the base image is not left with a dirty fs
        stop_heartbeat
        stop_vm
        msg "base image ready: $base"
        trap - EXIT INT TERM HUP
      }

      run_vm() {
        preflight
        ensure_workspace
        [ -f "$base" ] || provision

        trap cleanup EXIT INT TERM HUP
        # leftovers from a launcher that was killed before it could clean up
        rm -f "$session" "$pidfile"
        qemu-img create -q -f qcow2 -F qcow2 -b "$base" "$session"
        msg "booting a throwaway VM ($mem MiB, $cores cpus, ssh on 127.0.0.1:$port)"
        start_vm "$session" "$console"
        wait_boot 240
        ensure_guest_share
        start_heartbeat

        cat <<EOF

      Workspace   ${guestWorkspace}  <-  $workspace   (virtiofs share, persists)

      Everything else - including \$HOME and installed packages - is discarded
      when you exit this shell.

      EOF

        local rc=0
        ssh -t "''${ssh_args[@]}" || rc=$?
        # If another shell is still connected, keep the VM running
        local conns
        conns=$(vm_ssh 'who | wc -l' 2>/dev/null || echo 0)
        if [ "$conns" -le 0 ]; then
          trap - EXIT INT TERM HUP
          stop_heartbeat
          stop_vm
        else
          trap - EXIT INT TERM HUP
          stop_heartbeat
          msg "Another shell is still connected; keeping the VM running"
        fi
        msg "VM stopped and thrown away"
        if [ $rc -ne 0 ]; then
          printf '\nssh exited with %s, press enter to close this window' "$rc"
          read -r _ || true
        fi
      }

      status() {
        printf 'state      %s\n' "$state"
        printf 'workspace  %s%s\n' "$workspace" "$([ -d "$workspace" ] || echo '  (missing)')"
        printf 'base image %s%s\n' "$base" "$([ -f "$base" ] || echo '  (not built yet)')"
        printf 'session    %s%s\n' "$session" "$([ -f "$session" ] || echo '  (none)')"
        if vm_running; then
          printf 'qemu       running as pid %s, ssh on 127.0.0.1:%s\n' "$(cat "$pidfile")" "$port"
        else
          printf 'qemu       not running\n'
        fi
        printf 'console    %s%s\n' "$console" "$([ -f "$console" ] || echo '  (none)')"
        if [ -d "$workspace" ]; then
          printf '\nworkspace contents:\n'
          ls -l "$workspace"
        fi
      }



      nuke() {
        vm_running && die "stop the running VM first (exit its shell, or: ai-test-vm shell)"
        rm -rf "$state"
        msg "removed $state"
      }

      case "''${1:-run}" in
        run) run_vm ;;
        shell) vm_ssh -t || die "no VM reachable on 127.0.0.1:$port" ;;
        provision) provision ;;
        status) status ;;
        bench) bench ;;
        nuke) nuke ;;
        -h | --help | help) usage ;;
        *) usage; exit 1 ;;
      esac
    '';
  };
in
{
  inherit
    baseImage
    configHash
    script
    seedIso
    sshKey
    ;
  inherit (cloudInit) metaData userData;
}
