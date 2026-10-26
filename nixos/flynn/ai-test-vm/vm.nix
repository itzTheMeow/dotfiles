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
      # file backing the guest RAM (see start_vm); removed on teardown
      guest_mem=$state/guest-mem
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
        # established connections to a dying guest (sshd gone, qemu's slirp
        # still accepting) would otherwise hang forever; this caps any such
        # wedge at ~15s
        -o ServerAliveInterval=5
        -o ServerAliveCountMax=3
        -o BatchMode=yes
        ${username}@127.0.0.1
      )

      # the tty can vanish mid-run (window closed, ssh dropped); a failed
      # print must not kill the launcher via errexit, or teardown gets skipped
      # and qemu is left running but unreachable
      msg() { printf '\033[1;36m==>\033[0m %s\n' "$*" 2>/dev/null || true; }
      die() {
        printf '\033[1;31merror:\033[0m %s\n' "$*" 2>/dev/null || true
        exit 1
      }

      # shellcheck disable=SC2029 # ssh_args is ours, expanding it locally is the point
      vm_ssh() { ssh "''${ssh_args[@]}" "$@"; }

      vm_running() { [ -s "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }

      # graceful poweroff, then escalation. Sessions are throwaway overlays,
      # so a guest that refuses to die is simply discarded; only the
      # provision path gets a longer grace since there qemu writes the base
      # image. The escalation exists because a share whose daemon died
      # mid-session wedges the guest's shutdown (sync waits forever on the
      # dead fuse connection) - qemu used to be left running but
      # unreachable because of exactly that.
      stop_vm() { # grace_s
        if vm_running; then
          msg "shutting the VM down"
          # the guest helper aborts the share's fuse connection before
          # powering off; it can block on a wedged connection, so it runs in
          # the background - the grace window and escalation below reap qemu
          # regardless of whether the helper ever finishes
          vm_ssh "sudo -n /usr/local/bin/ai-test-vm-shutdown" >/dev/null 2>&1 &
          local i=0 pid
          pid=$(cat "$pidfile" 2>/dev/null || true)
          while [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ $i -lt $(( $1 * 5 )) ]; do
            sleep 0.2
            i=$((i + 1))
          done
          if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            i=0
            while kill -0 "$pid" 2>/dev/null && [ $i -lt 25 ]; do sleep 0.2; i=$((i + 1)); done
            if kill -0 "$pid" 2>/dev/null; then
              kill -9 "$pid" 2>/dev/null || true
              msg "the guest would not power off, discarded it"
            fi
          fi
        fi
        if [ -n "''${vfsd_pid:-}" ]; then
          kill "$vfsd_pid" 2>/dev/null || true
          vfsd_pid=
        fi
        rm -f "$pidfile" "$session" "$vfsd_sock" "$guest_mem"
      }

      # The guest powers itself off once the heartbeat file goes stale for
      # 60s, so a launcher that dies without running cleanup (kitty window
      # closed, ssh dropped, killed) still cannot leave the VM behind. The
      # loop itself exits as soon as this launcher is gone, so the beats stop
      # exactly when we do.
      heartbeat() {
        share_dead=0
        while kill -0 "$main_pid" 2>/dev/null; do
          # closing the kitty window revokes the launcher's tty without
          # necessarily killing it; /proc then reports the fd as deleted.
          # Stop beating so the guest watchdog powers the VM off, and poke
          # the launcher so it cleans up if/once it notices.
          case "$(readlink "/proc/$main_pid/fd/1" 2>/dev/null)" in
            *deleted*)
              kill -TERM "$main_pid" 2>/dev/null || true
              # the main shell may be wedged on the interactive ssh and
              # unable to run its own exit trap; tear the VM down from here
              stop_vm 30
              break
              ;;
          esac
          # the beat doubles as a share health probe: a daemon that died
          # mid-session otherwise makes every access to the mount hang with
          # no hint why (the daemon's own output goes to $state/virtiofsd.log).
          # An unlisted mount is not a failure - the first provision boot
          # only mounts the share late, from cloud-init's final stage - so
          # the probe only reports when the mount exists but does not answer,
          # and only after two consecutive failures so a slow moment under
          # heavy guest load does not produce a false alarm
          if vm_ssh "sudo -n touch /var/lib/ai-vm/heartbeat; if grep -qs ' ${guestWorkspace} virtiofs' /proc/mounts; then timeout 10 ls ${guestWorkspace} >/dev/null || exit 42; fi" 2>/dev/null; then
            share_dead=0
          else
            share_dead=$((share_dead + 1))
            if [ "$share_dead" -eq 2 ]; then
              msg "WARNING: the workspace share stopped responding - ${guestWorkspace} will hang; restart the VM when convenient (see $state/virtiofsd.log)"
            fi
          fi
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
        # a provision interrupted before the guest marker appeared leaves a
        # half-provisioned base image that sessions would silently boot with
        # packages missing - discard it so the next run re-provisions
        [ "''${provisioning:-}" = 1 ] && rm -f "$base"
        stop_vm 30 >>"$state/launcher.log" 2>&1 || true
        exit $rc
      }

      usage() {
        cat <<EOF
      ai-test-vm - throwaway Debian VM for running AI coding-agent tests

      usage: ai-test-vm [command]

        run         boot a fresh throwaway VM, drop into a shell, and throw the
                    VM away when that shell exits (default)
        shell       attach a shell to an already running VM
        stop        stop a running (or stuck) VM and throw it away
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
          die "a VM is already running (pid $(cat "$pidfile")) - use: ai-test-vm shell (or: ai-test-vm stop if it is stuck)"
        fi
      }

      # whatever is being tested has to be in the shared folder, this launcher
      # does not care what it is
      ensure_workspace() {
        [ -d "$workspace" ] ||
          die "$workspace does not exist yet - it is created by systemd-tmpfiles, run: sudo systemctl-tmpfiles --create $workspace"
      }

      start_vm() { # disk log mem_override
        rm -f "$vfsd_sock" "$vfsd_sock.pid"
        # setsid and stdin from /dev/null on purpose: the daemon must survive
        # the launcher's terminal dying (a SIGHUP to the launcher's process
        # group would otherwise kill it mid-session, and then every access
        # to the share hangs and the guest shutdown wedges). Its log only
        # belongs in a file - post-mortems read it when the daemon dies.
        ${pkgs.util-linux}/bin/setsid ${pkgs.virtiofsd}/bin/virtiofsd --xattr --socket-path "$vfsd_sock" --sandbox none --seccomp none --cache auto --shared-dir "$workspace" </dev/null >"$state/virtiofsd.log" 2>&1 &
        vfsd_pid=$!
        local i=0
        while [ $i -lt 100 ] && [ ! -S "$vfsd_sock" ]; do
          sleep 0.1
          i=$((i + 1))
        done
        [ -S "$vfsd_sock" ] || die "virtiofsd failed to create $vfsd_sock"
        # vhost-user devices have to mmap the guest RAM from the daemon, so
        # the machine needs a shared memory backend; without it virtiofsd
        # dies the moment the guest boots with HandleRequest(InvalidParam)
        # and the share mounts into a black hole. The backend is a plain file
        # rather than memfd on purpose: memfd pages cannot be reclaimed, and
        # on a memory-tight host that OOM-kills desktop apps (and can reset
        # the guest mid-boot), while file-backed guest RAM is just evictable
        # page cache
        # cache=unsafe: the session overlay is discarded and the base gets
        # re-provisioned on corruption anyway; dpkg's fsync storm through
        # qcow2 on btrfs dominated provisioning time
        qemu-system-x86_64 \
          -name ai-test-vm \
          -object memory-backend-file,id=mem,size="''${3:-$mem}"M,mem-path="$guest_mem",share=on,discard-data=on \
          -machine q35,accel=kvm,memory-backend=mem -cpu host \
          -m "''${3:-$mem}" -smp "$cores" \
          -display none -monitor none -serial "file:$2" \
          -nic "user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:$port-:22,dns=1.1.1.1" \
          -drive "file=$1,if=virtio,format=qcow2,cache=unsafe" \
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

      # checks /proc/mounts instead of stat'ing the path: stat on a share
      # whose daemon died blocks forever (and would wedge the launcher),
      # reading /proc/mounts never does
      share_mounted() {
        vm_ssh "grep -qs ' ${guestWorkspace} virtiofs' /proc/mounts"
      }

      ensure_guest_share() {
        share_mounted 2>/dev/null && return
        msg "the workspace share was not mounted at boot, mounting it now"
        # remote timeout so a wedged systemd cannot hang the launcher
        vm_ssh "timeout 30 sudo -n systemctl restart ${guestMountUnit}.mount" >/dev/null 2>&1 || true
        share_mounted 2>/dev/null ||
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

        # apt does not need the full runtime memory, and a smaller guest
        # keeps the memory-tight host from evicting the file-backed guest
        # RAM mid-install
        start_vm "$base" "$state/provision-console.log" "''${AI_VM_MEMORY:-2048}"
        msg "first boot: cloud-init is installing the guest packages (apt runs inside the VM, this takes ~10+ minutes)"
        wait_boot 300
        start_heartbeat
        provisioning=1
        local i=0
        while [ $i -lt 3600 ]; do
          vm_ssh "test -f /var/lib/ai-vm/provisioned" 2>/dev/null && break
          sleep 5
          i=$((i + 5))
        done
        provisioning=
        vm_ssh "test -f /var/lib/ai-vm/provisioned" ||
          {
            rm -f "$base"
            die "provisioning did not finish - the incomplete base image was discarded, retry: ai-test-vm provision"
          }
        ensure_guest_share

        # close the guest cleanly so the base image is not left with a dirty fs
        stop_heartbeat
        stop_vm 120
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
        # count interactive guest sessions by their sshd process title: a
        # utmp entry can linger after its session dies (which would pin the
        # VM as "still connected" forever), while this probe's own session
        # is @notty and never matches
        local conns
        conns=$(vm_ssh "pgrep -fc 'sshd-session: .*@pts'" 2>/dev/null) || conns=0
        if [ "$conns" -le 0 ]; then
          trap - EXIT INT TERM HUP
          stop_heartbeat
          stop_vm 30
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
        vm_running && die "stop the running VM first (exit its shell, or: ai-test-vm stop)"
        rm -rf "$state"
        msg "removed $state"
      }

      # the vm_running check is first on purpose: a wedged qemu (guest stuck
      # in shutdown) is exactly the state stop_vm's escalation exists for
      stop() {
        if vm_running; then
          stop_vm 30
          msg "VM stopped and thrown away"
        else
          rm -f "$pidfile" "$session" "$vfsd_sock" "$guest_mem"
          msg "no VM was running, cleared leftover state"
        fi
      }

      case "''${1:-run}" in
        run) run_vm ;;
        shell)
          vm_ssh -t 2>/dev/null ||
            if vm_running; then
              die "the VM (pid $(cat "$pidfile")) is running but not reachable on 127.0.0.1:$port - it is probably wedged, try: ai-test-vm stop"
            else
              die "no VM reachable on 127.0.0.1:$port - boot one with: ai-test-vm"
            fi
          ;;
        stop) stop ;;
        provision) provision ;;
        status) status ;;
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
