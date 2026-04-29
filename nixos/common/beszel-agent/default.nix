{
  config,
  host,
  pkgs-unstable,
  xelib,
  ...
}:
{
  services.beszel.agent = {
    enable = true;
    package = pkgs-unstable.beszel;
    environment = {
      HUB_URL = xelib.apps.beszel.url;
      LISTEN = "${host.ip}:${toString host.ports.beszel-agent}";
    };
    environmentFile = config.sops.secrets.beszel_agent.path;
  };
  systemd.services.beszel-agent.after = [ "tailscale-online.service" ];

  sops.envFiles.beszel_agent = {
    KEY = "op://Private/Beszel Hub Key/public key";
    TOKEN = "op://Private/Beszel Hub Universal Token/password";
  };
}
