{
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
    environmentFile = "/home/${host.username}/.local/share/beszel/env";
  };
}
