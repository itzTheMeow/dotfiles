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
      HUB_URL = "https://${xelib.services.beszel.domain}";
      LISTEN = "${host.ip}:${builtins.toString host.ports.beszel-agent}";
    };
    environmentFile = config.sops.secrets.beszel_agent.path;
  };

  sops.secrets.beszel_agent = {
    format = "dotenv";
    sopsFile = ../../../${config.sops.opSecrets.beszel_agent.path};
    key = "";
  };
  sops.opSecrets.beszel_agent = {
    format = "dotenv";
    keys = {
      KEY = "op://Private/Beszel Hub Key/public key";
      TOKEN = "op://Private/Beszel Hub Universal Token/password";
    };
  };
}
