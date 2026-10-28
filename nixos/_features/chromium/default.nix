{ pkgs, ... }:
{
  # module doesnt install it i dont think
  environment.systemPackages = [ pkgs.chromium ];
  programs.chromium = {
    enable = true;
    extensions = [
      "aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password
      "cndibmoanboadcifjkjbdpjgfedanolh" # BetterCanvas
      "bkkmolkhemgaeaeggcmfbghljjjoofoh" # Catppuccin Mocha
      "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
      "cimiefiiaegbelhefglklhhakcgmhkai" # Plasma Integration
      "clngdbkpkpeebahjckkjfobafhncgmne" # Stylus
      "dhdgffkkebhmkfjojejmpbldmpobfkfo" # Tampermonkey
      "ddkjiahejlhfcafbddmgiahcphecmpfh" # uBlock Origin Lite
    ];
    enablePlasmaBrowserIntegration = true;
  };

  persist.ed.home.userDirectories = [
    ".config/chromium"
    ".pki" # chromium certs
  ];
  persist.ed.cache.userDirectories = [
    ".cache/chromium"
  ];
}
