{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      cmake
      dpkg
    ];

    shellAliases = {
      # shortcuts for linux-like shell commands
      code = "open -a /Applications/Visual\\ Studio\\ Code.app";
      tailscale = "/Applications/Tailscale.app/Contents/MacOS/Tailscale";

      # remove quarantine status from files
      unquarantine = "xattr -r -d com.apple.quarantine";
    };
  };
}
