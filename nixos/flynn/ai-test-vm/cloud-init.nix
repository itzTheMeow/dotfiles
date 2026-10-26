# cloud-init (NoCloud) data for the throwaway Debian VM in nixos/flynn/ai-test-vm.
#
# The whole user-data document is emitted as JSON on purpose: cloud-init parses
# YAML, JSON is valid YAML, and building it like this keeps hand-written
# indentation and escaping out of the module.
{
  mountUnit,
  username,
  authorizedKey,
  instanceId ? "debian",
  guestWorkspace ? "/home/${username}/workspace",
  shareTag ? "aiworkspace",
}:
let
  packages = [
    # common denominator for agent tooling (node CLIs, python scripts)
    "nodejs"
    "npm"
    "python3"
    "python3-pip"
    "python3-venv"
    "perl" # shasum
    "git"
    "curl"
    "tar"
    "ca-certificates"
    "golang-1.27"

    # everyday tooling inside the test VM
    "build-essential"
    "pkg-config"
    "ripgrep"
    "fd-find"
    "jq"
    "tmux"
    "vim"
    "less"
    "file"
    "unzip"
    "rsync"
    "procps"

    # ssh and the host share
    "openssh-server"
    "sudo"
  ];
in
{
  metaData = {
    instance-id = instanceId;
    "local-hostname" = "debian";
  };

  userData = {
    hostname = "debian";
    manage_etc_hosts = true;

    users = [
      {
        name = username;
        # virtiofsd runs unprivileged (--sandbox none) and switches to the
        # requesting uid/gid per operation; any guest id the host user does
        # not have makes its setegid/setgroups fail with EPERM, and then
        # every create on the share fails (reads are unaffected). So the ids
        # must be a subset of the host's: uid 1000 matches, "users" is gid
        # 100 on both sides, and there are no supplementary groups - the
        # NOPASSWD sudoers entry below does not need the sudo group.
        primary_group = "users";
        shell = "/bin/bash";
        lock_passwd = true;
        sudo = [ "ALL=(ALL) NOPASSWD:ALL" ];
        ssh_authorized_keys = [ authorizedKey ];
      }
    ];

    package_update = true;
    package_upgrade = false;
    packages = packages;

    write_files = [
      {
        # dpkg fsyncs constantly and apt pulls recommends by default; both
        # dominated provisioning time (fsync through qcow2 on btrfs is very
        # slow, and recommends alone nearly doubled the dependency tree).
        # The image is throwaway and an interrupted provision discards the
        # base, so unsafe IO is acceptable here.
        path = "/etc/apt/apt.conf.d/90ai-test-vm";
        content = ''
          APT::Install-Recommends "false";
          APT::Install-Suggests "false";
          Dpkg::Options { "--force-unsafe-io"; };
        '';
      }
      {
        path = "/etc/ssh/sshd_config.d/ai-test-vm.conf";
        content = ''
          PasswordAuthentication no
          KbdInteractiveAuthentication no
          PermitRootLogin no
        '';
      }
      {
        # the host folder shared in as the workspace, as a systemd unit instead
        # of an fstab entry so nothing cloud-init owns can get clobbered
        path = "/etc/systemd/system/${mountUnit}.mount";
        content = ''
          [Unit]
          Description=workspace share from the host

          [Mount]
          What=${shareTag}
          Where=${guestWorkspace}
          Type=virtiofs
          Options=nosuid,nodev
          TimeoutSec=30

          [Install]
          WantedBy=multi-user.target
        '';
      }
      {
        path = "/usr/local/bin/ai-test-vm-shutdown";
        # cloud-init 25.x validates write_files against a schema that dropped the old
        # "mode" key in favour of "permissions"
        permissions = "0755";
        content = ''
          #!/bin/sh
          # The host launcher calls this over ssh and the dead-man's switch
          # runs it directly. Every fuse-touching step is timeout-guarded:
          # a dead or wedged share daemon would otherwise block the shutdown
          # sync forever (the guest never finishes powering off and qemu
          # lingers on the host, running but unreachable). Aborting the fuse
          # connection first also makes pending requests fail immediately,
          # which keeps the umount fast even under memory pressure.
          timeout 30 sh -c 'for c in /sys/fs/fuse/connections/*; do
            [ -w "$c/abort" ] && echo 1 > "$c/abort" 2>/dev/null
          done' 2>/dev/null || true
          timeout 30 umount ${guestWorkspace} 2>/dev/null || true
          timeout 30 sync || true
          systemctl poweroff
        '';
      }
      {
        # dead-man's switch: the host launcher touches the heartbeat every 10s
        # while it is attached. If that stops (kitty window closed, launcher
        # killed, host rebooted) the VM powers itself off instead of idling
        # forever. No heartbeat file yet means "not armed" (fresh boot).
        path = "/usr/local/bin/ai-vm-watchdog";
        permissions = "0755";
        content = ''
          #!/bin/sh
          hb=/var/lib/ai-vm/heartbeat
          [ -f "$hb" ] || exit 0
          last=$(stat -c %Y "$hb" 2>/dev/null) || exit 0
          # interactive shells still attached? keep the VM alive regardless
          # of the launcher - it powers off once the last shell leaves
          [ "$(pgrep -fc 'sshd-session: .*@pts' 2>/dev/null)" -gt 0 ] && exit 0
          [ $(( $(date +%s) - last )) -gt 60 ] && /usr/local/bin/ai-test-vm-shutdown
          exit 0
        '';
      }
      {
        path = "/etc/systemd/system/ai-vm-watchdog.service";
        content = ''
          [Unit]
          Description=AI test VM dead-man's switch

          [Service]
          Type=oneshot
          ExecStart=/usr/local/bin/ai-vm-watchdog
          # the shutdown helper may legitimately take a while (fuse aborts
          # under memory pressure); systemd must never kill it mid-poweroff
          TimeoutStartSec=0
        '';
      }
      {
        path = "/etc/systemd/system/ai-vm-watchdog.timer";
        content = ''
          [Unit]
          Description=Run the AI test VM dead-man's switch

          [Timer]
          OnBootSec=15s
          OnUnitActiveSec=10s

          [Install]
          WantedBy=timers.target
        '';
      }
    ];

    runcmd = [
      "systemctl daemon-reload"
      "systemctl enable ${mountUnit}.mount"
      "systemctl start ${mountUnit}.mount || true"
      # sentinel the launcher waits for before the base image counts as ready
      "install -d /var/lib/ai-vm"
      "touch /var/lib/ai-vm/provisioned"
      # dead-man's switch for the throwaway session VMs
      "systemctl enable --now ai-vm-watchdog.timer"
    ];

    final_message = "provisioned in $UPTIME seconds";
  };
}
