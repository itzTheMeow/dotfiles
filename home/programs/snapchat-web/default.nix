{
  globals,
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
    url = "https://upload.wikimedia.org/wikipedia/en/thumb/c/c4/Snapchat_logo.svg/330px-Snapchat_logo.svg.png";
    sha256 = "sha256-VlPAEZ116oLawxMoouOwknKJpi0weC8wWYv2dXySw/Q=";
  };

  # Compile LESS to CSS and add custom styles
  customCSS =
    pkgs.runCommand "snapchat-custom.css"
      {
        buildInputs = [ pkgs.nodePackages.less ];
      }
      ''
        # Copy the catppuccin LESS file
        cp ${catppuccinLess} catppuccin.user.less

        # Create a new file with variables and lib.less content inlined
        cat > processed.user.less << 'EOF'
        @darkFlavor: ${globals.catppuccin.flavor};
        @lightFlavor: latte;
        @accentColor: ${globals.catppuccin.accent};
        EOF

        # Append lib.less content
        cat ${catppuccinLib} >> processed.user.less

        # Append the original catppuccin.user.less, but skip the import line, @moz-document line, and trailing }
        sed -e '/^@import.*lib\.less/d' \
            -e '/^@-moz-document/d' \
            -e '$s/^}$//' \
            catppuccin.user.less >> processed.user.less

        # Compile the processed LESS file to CSS
        lessc processed.user.less > catppuccin.css

        # Combine with custom CSS
        cat catppuccin.css > $out
        echo "" >> $out
        echo "/* Custom styles */" >> $out
        cat ${./custom.css} >> $out
      '';

  # Create a Chrome extension to inject the CSS
  cssExtension = pkgs.runCommand "snapchat-css-extension" { } ''
    mkdir -p $out

    # Create manifest.json
    cat > $out/manifest.json << 'EOF'
    {
      "manifest_version": 3,
      "name": "Snapchat Web Custom Styles",
      "version": "1.0",
      "description": "Injects custom CSS into Snapchat Web",
      "content_scripts": [
        {
          "matches": ["https://web.snapchat.com/*"],
          "css": ["custom.css"],
          "run_at": "document_start"
        }
      ]
    }
    EOF

    # Copy the custom CSS
    cp ${customCSS} $out/custom.css
  '';

in
{
  #programs.chromium.extensions = [
  #  {
  #    id = "snapchat-web-styles";
  #    updateUrl = "file://${cssExtension}";
  #  }
  #];

  programs.chromium.extraOpts = {
    "WebAppInstallForceList" = [
      {
        "custom_name" = "Snapchat Web";
        "custom_icon" = {
          "url" = "${snapchatIcon}";
        };
        "create_desktop_shortcut" = true;
        "default_launch_container" = "window";
        "url" = "https://snapchat.com/web";
      }
    ];
    #"ExtensionSettings" = {
    #  "${cssExtension}" = {
    #    "installation_mode" = "force_installed";
    #    "update_url" = "file://${cssExtension}/manifest.json";
    #  };
    #};
  };
}
