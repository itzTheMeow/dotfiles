{
  config,
  host,
  pkgs,
  xelib,
  ...
}:
{
  environment.systemPackages = [ pkgs.immich-cli ];

  # authenticate the user automatically
  sops.groups.immich-cli.key = "op://Private/lfuwax7zpv45oqen4zj7yu65tq/API Keys/CLI";
  sops.templates."immich-auth.yaml" = {
    content = xelib.toYAMLString {
      url = "https://${xelib.apps.immich.domain}/api";
      key = config.sops.groupPlaceholders.immich-cli.key;
    };
    path = "/home/${host.username}/.config/immich/auth.yml";
    owner = host.username;
  };
}
