{ xelib, ... }:
let
  username = "root";
in
{
  imports = [
    ./common
    ./common/headless.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/root";

    sessionVariables = {
      NTFY_TAGS = "hyzenberg";
    };

    file =
      { }
      # secrets
      // xelib.mkSecretFile ".ssh/authorized_keys" "op://Private/Hyzenberg SSH Key/public key"
      # opunattended secrets
      // xelib.mkOPUnattendedSecret "op://Private/fxxd4a76am6kr6okubzdohp3nm/password";
  };
}
