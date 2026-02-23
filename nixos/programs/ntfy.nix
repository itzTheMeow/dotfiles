{
  config,
  host,
  hostname,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [ ntfy-sh ];
  environment.sessionVariables.NTFY_TAGS = hostname;

  sops.secrets.ntfy_cli = {
    sopsFile = ../../${config.sops.opSecrets.ntfy_cli.path};
    path = "/home/${host.username}/.config/ntfy/client.yml";
    owner = host.username;
    key = "";
  };
  sops.opSecrets.ntfy_cli = {
    format = "yaml";
    keys = {
      default-token = "op://Private/6hzhuyrsumkvp5cw4fymth4mqa/Access Tokens/${hostname}";
    };
  };
}
