{
  config,
  host,
  hostname,
  lib,
  pkgs,
  xelib,
  ...
}:
let
  app = xelib.apps.rustdesk;
  user = host.username;
  configDir = "/home/${user}/.config/rustdesk";

  # merge one `key = "value"` line into the [options] table, so options changed
  # in the GUI survive a re-seed (these are inlined into the script body, so they
  # use the `$rustdesk2` variable directly rather than arguments)
  setOption = key: value: ''
    if grep -q '^${key} = ' "$rustdesk2"; then
      sed -i 's|^${key} = .*|${key} = "${value}"|' "$rustdesk2"
    else
      sed -i '/^\[options\]/a ${key} = "${value}"' "$rustdesk2"
    fi
  '';

  # replace a top-level key with the contents of a sops secret, but only when the
  # intended value changed (`.nix-<key>` sentinel holding the sha256 of the
  # secret): rustdesk re-encrypts `id`/`password` on every store, so the
  # plaintext on disk is not a usable comparison
  setValue = key: delRegex: secretFile: ''
    actual=$(sha256sum '${secretFile}' | cut -d' ' -f1)
    if [ "$(cat '$dir/.nix-${key}' 2>/dev/null)" != "$actual" ]; then
      value=$(tr -d '\n' < '${secretFile}')
      escaped=$(printf '%s' "$value" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
      sed -i -E '/^(${delRegex})[[:space:]]*=/d' "$rustdesk"
      printf '${key} = "%s"\n' "$escaped" | cat - "$rustdesk" > "$rustdesk.new"
      mv "$rustdesk.new" "$rustdesk"
      chmod 0600 "$rustdesk"
      printf '%s' "$actual" > "$dir/.nix-${key}"
    fi
  '';

  # like setOption, but the value is read at runtime from a sops secret file
  setOptionFromFile = key: secretFile: ''
    sed -i '/^${key} = /d' "$rustdesk2"
    value=$(tr -d '\n' < '${secretFile}')
    escaped=$(printf '%s' "$value" | sed -e 's/[\\&|]/\\&/g')
    sed -i "s|^\[options\]|[options]\n${key} = \"$escaped\"|" "$rustdesk2"
  '';

  seedConfig = pkgs.writeShellApplication {
    name = "rustdesk-seed-config";
    runtimeInputs = with pkgs; [
      coreutils
      diffutils
      gnugrep
      gnused
    ];
    text = ''
      dir=$1
      user=$2

      umask 0077
      install -d -m 0700 -o root -g root "$dir"
      rustdesk="$dir/RustDesk.toml"
      rustdesk2="$dir/RustDesk2.toml"

      if [ ! -f "$rustdesk2" ]; then
        printf '[options]\n' > "$rustdesk2"
        chmod 0600 "$rustdesk2"
      fi
      ${setOption "custom-rendezvous-server" "${app.ip}"}
      ${setOption "relay-server" "${app.ip}"}
      ${setOption "api-server" "${app.url}"}
      ${setOptionFromFile "key" "${config.sops.groupPaths.rustdesk.server-public-key}"}

      if [ ! -f "$rustdesk" ]; then
        : > "$rustdesk"
        chmod 0600 "$rustdesk"
      fi
      # `id` is stored encrypted as `enc_id` on its own, so both keys go
      ${setValue "id" "id|enc_id" "${config.sops.groupPaths.rustdesk.id}"}
      ${setValue "password" "password" "${config.sops.groupPaths.rustdesk.client-password}"}

      chown -R "$user" "$dir"
    '';
  };
in
{
  environment.systemPackages = [ pkgs.rustdesk-flutter ];

  sops.groups.rustdesk = {
    id = "op://Private/RustDesk ${hostname}/username";
    client-password = "op://Private/RustDesk ${hostname}/password";
    server-public-key = "op://Private/okqmygckmjgcburvovuedkkxjm/username";
  };

  # seed the config before the service starts its first --server process
  systemd.services.rustdesk-config = {
    description = "Seed the RustDesk client config";
    wantedBy = [ "multi-user.target" ];
    before = [ "rustdesk.service" ];
    after = [
      "sops-install-secrets.service"
      "local-fs.target" # the persisted dir has to be mounted first
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${lib.getExe seedConfig} ${configDir} ${user}
    '';
  };

  # root service: uinput IPC (/dev/uinput) serves the input path for Wayland,
  # `--service` is also what logs in the session and spawns `rustdesk --server`
  # as the active user, which is how the ScreenCast portal path gets enabled
  systemd.services.rustdesk = {
    description = "RustDesk";
    wantedBy = [ "multi-user.target" ];
    # don't run with stale or missing seeded config (seed failure = no service)
    requires = [ "rustdesk-config.service" ];
    after = [
      "rustdesk-config.service"
      "network.target"
      "systemd-user-sessions.service"
    ];
    environment = {
      PULSE_LATENCY_MSEC = "60";
      PIPEWIRE_LATENCY = "1024/48000";
      # the wrappers dir first so `sudo` is the configured wrapper; the rest are
      # used by the rustdesk service itself (`ps`/`pkill`/`awk`, `run_as_user`)
      PATH = lib.mkForce (
        "/run/wrappers/bin:"
        + lib.makeBinPath [
          pkgs.coreutils
          pkgs.findutils
          pkgs.gawk
          pkgs.procps
          pkgs.util-linux
        ]
      );
    };
    serviceConfig = {
      ExecStart = "${pkgs.rustdesk-flutter}/bin/rustdesk --service";
      Restart = "on-failure";
      RestartSec = "10s";
      KillMode = "mixed";
      TimeoutStopSec = 30;
      LimitNOFILE = 100000;
      # hardening that doesn't break uinput IPC / run-as-user portal flows
      LockPersonality = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "full";
      RestrictRealtime = true;
    };
  };

  persist.ed.home.userDirectories = [ ".config/rustdesk" ];
}
