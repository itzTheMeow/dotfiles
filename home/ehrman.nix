{
  host,
  hostname,
  xelib,
  ...
}:
{
  imports = [
    ./common
    ./common/headless.nix

    ./programs/beszel-agent
  ];

  home = {
    username = host.username;

    sessionVariables = {
      NTFY_TAGS = hostname;
    };

    file =
      { }
      # secrets
      // xelib.mkSecretFile ".ssh/authorized_keys" "op://Private/vywbzem32jihjjvgldmz5tr5mu/public key";
  };
}
