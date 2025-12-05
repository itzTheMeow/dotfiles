{ pkgs, utils, ... }:
let
  username = "meow";
in
{
  imports = [
    ./common
    ./common/darwin.nix
    ./common/desktop.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/Users/meow";

    file = {

    }
    // utils.mkSecretFile ".ssh/authorized_keys" "op://Private/ton3e65pkunjzq6gua2mef6gkq/public key";
  };
}
