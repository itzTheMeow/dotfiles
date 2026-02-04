{ xelib, xelpkgs, ... }:
let
  username = "mike";
in
{
  imports = [
    ./common
    ./common/headless.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/home/${username}";

    sessionVariables = {
      NTFY_TAGS = "ehrman";
    };

    file =
      { }
      # secrets
      // xelib.mkSecretFile ".ssh/authorized_keys" "op://Private/vywbzem32jihjjvgldmz5tr5mu/public key";
  };
}
