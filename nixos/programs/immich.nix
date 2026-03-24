{
  config,
  host,
  pkgs,
  xelib,
  ...
}:
{
  environment.systemPackages = [ pkgs.immich-cli ];

  sops.secrets.immich-cli = {
    sopsFile = config.sops.opSecrets.immich.fullPath;
    key = "key";
  };
  sops.opSecrets.immich.keys.key = "op://Private/lfuwax7zpv45oqen4zj7yu65tq/API Keys/CLI";
  sops.templates."immich-auth.yaml" = {
    content = xelib.toYAMLString {
      url = "https://immich.xela.codes/api";
      key = config.sops.placeholder.immich-cli;
    };
    path = "/home/${host.username}/.config/immich/auth.yml";
    owner = host.username;
  };
}
