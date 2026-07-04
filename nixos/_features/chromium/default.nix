{ pkgs, ... }:
{
  # module doesnt install it i dont think
  environment.systemPackages = [ pkgs.chromium ];
  programs.chromium = {
    enable = true;
    extensions = [
      "aeblfdkhhhdcdjpifhhbdiojplfjncoa" # 1Password
      "cndibmoanboadcifjkjbdpjgfedanolh" # BetterCanvas
      "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
      "cimiefiiaegbelhefglklhhakcgmhkai" # Plasma Integration
      "clngdbkpkpeebahjckkjfobafhncgmne" # Stylus
      "dhdgffkkebhmkfjojejmpbldmpobfkfo" # Tampermonkey
      "ddkjiahejlhfcafbddmgiahcphecmpfh" # uBlock Origin Lite
    ];
    enablePlasmaBrowserIntegration = true;
  };
}
