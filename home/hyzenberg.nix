{ pkgs, utils, ... }:
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

    packages = with pkgs; [ 
    ];

    file = {

    }
    // utils.mkSecretFile ".ssh/authorized_keys" "op://Private/Hyzenberg SSH Key/public key";
  };
}
