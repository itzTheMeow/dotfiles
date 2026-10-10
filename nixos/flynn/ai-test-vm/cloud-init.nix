# cloud-init (NoCloud) data for the throwaway Debian VM in nixos/flynn/ai-test-vm.
#
# The whole user-data document is emitted as JSON on purpose: cloud-init parses
# YAML, JSON is valid YAML, and building it like this keeps hand-written
# indentation and escaping out of the module.
{
  mountUnit,
  username,
  authorizedKey,
  instanceId ? "ai-test-vm",
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
    "ffmpeg"

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
    "local-hostname" = "ai-test-vm";
  };

  userData = {
    hostname = "ai-test-vm";
    manage_etc_hosts = true;

    users = [
      {
        name = username;
        gecos = "AI Test VM";
        groups = [ "sudo" ];
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
        path = "/etc/modules-load.d/ai-test-vm-9p.conf";
        content = "9pnet_virtio\n";
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
          Description=AI test VM workspace (9p share from the host)
          After=systemd-modules-load.service network-online.target
          Wants=network-online.target

          [Mount]
          What=${shareTag}
          Where=${guestWorkspace}
          Type=9p
          Options=trans=virtio,version=9p2000.L,cache=loose,msize=131072,nosuid,nodev
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
          # Flushing everything and letting systemd unmount the share before
          # powering off. The host launcher calls this over ssh when the
          # interactive shell exits.
          sync
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
          [ $(( $(date +%s) - last )) -gt 60 ] && systemctl poweroff
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
      {
        path = "/etc/profile.d/ai-test-vm.sh";
        content = ''
          printf '\n  AI test VM -- throwaway guest, nothing here survives a shutdown.\n  Workspace: ~/workspace (shared with the host, survives)\n  Type exit to shut down and throw this VM away.\n\n'
        '';
      }
    ];

    runcmd = [
      "systemctl daemon-reload"
      "systemctl enable ${mountUnit}.mount"
      # the 9p device may show up after cloud-init starts; mounting is retried
      # by the launcher, so a failure here must not abort provisioning
      "systemctl start ${mountUnit}.mount || true"
      # sentinel the launcher waits for before the base image counts as ready
      "install -d /var/lib/ai-vm"
      "touch /var/lib/ai-vm/provisioned"
      # dead-man's switch for the throwaway session VMs
      "systemctl enable --now ai-vm-watchdog.timer"
    ];

    final_message = "ai-test-vm: provisioned in $UPTIME seconds";
  };
}
