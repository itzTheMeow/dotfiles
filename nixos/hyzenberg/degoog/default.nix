{
  config,
  lib,
  pkgs,
  xelib,
  ...
}:
let
  app = config.apps.degoog;
  mullvad = xelib.apps.mullvad-exit-nodes;

  # custom declarative settings to be merged into the non-declarative settings file on startup
  settings = {
    proxyEnabled = true;
    proxyUrls = lib.concatStringsSep "\n" (
      map (node: "socks5://${mullvad.ip}:${toString (mullvad.details.basePorts.socks5 + node.index)}") (
        xelib.exitNodes
      )
    );
    searxCompatEnabled = true;
  };
in
{
  apps.degoog = {
    domain = "degoog.xela";
    port = 64335;
    enableProxy = true;
    allowedAppHosts = [ "open-webui" ];
    details.valkeyPort = 64336;

    description = "Private Search";
    icon = "sh-degoog";
  };

  # set up redis for valkey
  services.redis.servers.degoog = {
    enable = true;
    port = app.details.valkeyPort;
    save = [
      [
        300
        1
      ]
      [
        60
        10
      ]
    ];
  };

  services.degoog = {
    enable = true;
    environmentFile = config.sops.secrets.degoog.path;
    # for searx compat layer
    binPaths.python = pkgs.python3.withPackages (
      ps: with ps; [
        babel
        python-dateutil
        lxml
      ]
    );
    environment = {
      DEGOOG_BIND_ADDRESS = app.ip;
      DEGOOG_PORT = app.port;
      DEGOOG_BASE_URL = app.url;
      DEGOOG_PUBLIC_INSTANCE = false;
      DEGOOG_WIZARD = false;
      DEGOOG_VALKEY_URL = "redis://127.0.0.1:${toString app.details.valkeyPort}";
      LOG_LEVEL = "info";
    };
  };
  systemd.services.degoog.after = [
    "degoog-settings.service"
    "tailscale-online.service"
  ];
  systemd.services.degoog-settings = {
    description = "Merge declarative settings into degoog's server-settings.json";
    wantedBy = [ "degoog.service" ];
    before = [ "degoog.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = lib.escapeShellArgs [
        (lib.getExe (
          pkgs.writeShellApplication {
            name = "degoog-merge-settings";
            runtimeInputs = with pkgs; [
              coreutils
              jq
            ];
            text = ''
              set -euo pipefail

              file="$1"
              ours="$2"

              mkdir -p "$(dirname "$file")"
              tmp="$(mktemp "$(dirname "$file")/.server-settings.json.XXXXXX")"
              trap 'rm -f "$tmp"' EXIT

              if [[ -f "$file" ]]; then
                jq --slurpfile ours "$ours" '.settings = ((.settings // {}) + $ours[0])' "$file" >"$tmp"
              else
                jq -n --slurpfile ours "$ours" '{ settings: $ours[0] }' >"$tmp"
              fi

              chmod 0644 "$tmp"
              mv -f "$tmp" "$file"
            '';
          }
        ))
        "${config.systemd.services.degoog.serviceConfig.WorkingDirectory}/server-settings.json"
        "${pkgs.writeText "degoog-declarative-settings.json" (builtins.toJSON settings)}"
      ];
    };
  };

  sops.envFiles.degoog.DEGOOG_SETTINGS_PASSWORDS = "op://Private/iv2fs5qjw3veizdodpzs5ra63e/password";
}
