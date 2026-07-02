{ host, pkgs, ... }:
{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox-devedition;
  };

  # enable 1Password browser integration
  environment.etc."1password/custom_allowed_browsers" = {
    text = ''
      firefox-devedition
    '';
    mode = "0755";
  };

  # set as default browser
  home-manager.users.${host.username}.xdg.mimeApps.defaultApplications = {
    "text/html" = "firefox-devedition.desktop";
    "x-scheme-handler/http" = "firefox-devedition.desktop";
    "x-scheme-handler/https" = "firefox-devedition.desktop";
    "x-scheme-handler/about" = "firefox-devedition.desktop";
    "x-scheme-handler/unknown" = "firefox-devedition.desktop";
  };
}
