{ host, ... }:
{
  imports = [
    ./common
    ./common/headless.nix
  ];

  home = {
    username = host.username;
  };
}
