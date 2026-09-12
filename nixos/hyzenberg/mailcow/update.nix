{
  config,
  lib,
  pkgs,
  ...
}:
{
  # mailcow's update.sh hard-codes `/etc/docker/daemon.json` and refuses to continue
  # if it doesn't contain the IPv6 keys it wants (see mailcow/mailcow-dockerized#6167).
  environment.etc."docker/daemon.json" = lib.mkIf config.virtualisation.docker.enable {
    text = builtins.toJSON config.virtualisation.docker.daemon.settings;
  };

  environment.systemPackages = [
    # Runs mailcow's update.sh with every binary it needs available.
    (pkgs.writeShellApplication {
      name = "mailcow-update";
      runtimeInputs = with pkgs; [
        bash # hooks (pre/post_update_hook.sh) and `#!/usr/bin/env bash`
        coreutils # cp, date, head, mktemp, mv, sed? no, sleep, sort, timeout, tr, ...
        curl
        docker
        docker-compose # both the `docker compose` plugin and `docker-compose`
        findutils # find, xargs
        gawk
        git
        gnugrep # GNU grep (needs -oP)
        gnused
        iproute2 # ip (IPv6 probing)
        iptables # iptables (nat table cleanup); ip6tables is never invoked
        iputils # ping, ping6 (IPv6 probing)
        jq # required by get_installed_tools + daemon.json editing
        openssl
        systemd # systemctl (docker restart fallback)
      ];
      text = ''
        # Runs the mailcow update script from its installation directory with
        # all required binaries on PATH. Arguments are forwarded to update.sh.
        set -euo pipefail

        dir=${lib.escapeShellArg "/opt/mailcow-dockerized"}
        if [[ ! -d "$dir" ]]; then
          echo "mailcow not found at '$dir' - clone it first (https://docs.mailcow.email/getstarted/install/)" >&2
          exit 1
        fi
        if [[ ! -x "$dir/update.sh" ]]; then
          echo "update.sh not found or not executable in '$dir' - is mailcow installed?" >&2
          exit 1
        fi

        # let `docker compose` resolve the compose plugin shipped by nixpkgs
        export DOCKER_CLI_PLUGIN_EXTRA_DIRS="${pkgs.docker-compose}/libexec/docker/cli-plugins"

        # allow running the script as root even if the clone is user-owned
        export GIT_CONFIG_COUNT=1
        export GIT_CONFIG_KEY_0=safe.directory
        export GIT_CONFIG_VALUE_0="$dir"

        cd "$dir"
        exec ./update.sh "$@"
      '';
    })
  ];
}
