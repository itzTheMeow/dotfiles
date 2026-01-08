{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Fetch Catppuccin userstyle
  catppuccinLess = pkgs.fetchurl {
    url = "https://github.com/catppuccin/userstyles/raw/4134d01e8dc76dde49730977d4b4716b60c5dc6b/styles/snapchat-web/catppuccin.user.less";
    sha256 = "sha256-vA8tM7Qoio8YW1dS24QUeLVTB5K5ZpoojI+4sI9faVM=";
  };

  # Fetch Catppuccin lib.less dependency
  catppuccinLib = pkgs.fetchurl {
    url = "https://userstyles.catppuccin.com/lib/lib.less";
    sha256 = "sha256-CsurGVIjN9Dbdj9zvq+YfvCr1FNhnvR77E2aUckEImE=";
  };

  # Fetch Snapchat icon
  snapchatIcon = pkgs.fetchurl {
    url = "https://static.snapchat.com/favicon.ico";
    sha256 = "sha256-GC6SwOhh5P0xYiiB0Elj/5G5WxJySzWb9A9oQyZizdg=";
  };

  # Compile LESS to CSS and add custom styles
  customCSS =
    pkgs.runCommand "snapchat-custom.css"
      {
        buildInputs = [ pkgs.nodePackages.less ];
      }
      ''
        # Copy lib.less and catppuccin LESS file
        cp ${catppuccinLib} lib.less
        cp ${catppuccinLess} catppuccin.user.less

        # Replace the URL import with local file import
        sed -i 's|@import "https://userstyles.catppuccin.com/lib/lib.less";|@import "lib.less";|g' catppuccin.user.less

        # Compile the catppuccin LESS file to CSS
        lessc catppuccin.user.less > catppuccin.css

        # Combine with custom CSS
        cat catppuccin.css > $out
        echo "" >> $out
        echo "/* Custom styles */" >> $out
        cat ${./custom.css} >> $out
      '';

  # Wrapper script to launch Snapchat Web
  snapchatWebLauncher = pkgs.writeScriptBin "snapchat-web" ''
    #!${pkgs.bash}/bin/bash

    # Create config directory if it doesn't exist
    CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/snapchat-web"
    mkdir -p "$CONFIG_DIR"

    # Copy custom CSS to config directory
    cp ${customCSS} "$CONFIG_DIR/custom.css"

    # Launch Chromium in app mode with custom user stylesheet
    exec ${pkgs.chromium}/bin/chromium \
      --app=https://web.snapchat.com \
      --user-data-dir="$CONFIG_DIR/chromium-profile" \
      --class=SnapchatWeb \
      --name=SnapchatWeb \
      --user-stylesheet="file://$CONFIG_DIR/custom.css" \
      "$@"
  '';

  desktopEntry = pkgs.makeDesktopItem {
    name = "snapchat-web";
    desktopName = "Snapchat Web";
    comment = "Snapchat is a fast and fun way to share the moment with your friends and family 👻";
    exec = "${snapchatWebLauncher}/bin/snapchat-web";
    icon = "${snapchatIcon}";
    keywords = [ "snap" ];
    categories = [
      "Network"
      "Chat"
      "InstantMessaging"
    ];
    startupWMClass = "SnapchatWeb";
  };

in
{
  home.packages = [
    snapchatWebLauncher
    desktopEntry
  ];
}
