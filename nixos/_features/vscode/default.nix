{ pkgs, xelib, ... }: {
  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-stores; [
      nixpkgs.aaron-bond.better-comments # Better Comments #TODO: look into alternatives
      nixpkgs.docker.docker # Docker DX
      nixpkgs.editorconfig.editorconfig # EditorConfig
      nixpkgs.esbenp.prettier-vscode # Prettier
      nixpkgs.github.vscode-github-actions # GitHub Actions
      nixpkgs.github.vscode-pull-request-github # GitHub Pull Requests
      nixpkgs.jock.svg # SVG
      nixpkgs.ms-vscode.makefile-tools # Makefile Tools
      nixpkgs.ms-vsliveshare.vsliveshare # Live Share
      nixpkgs.redhat.vscode-xml # XML
      nixpkgs.redhat.vscode-yaml # YAML
      nixpkgs.tamasfe.even-better-toml # Even Better TOML
      nixpkgs.tomoki1207.pdf # vscode-pdf
      nixpkgs.vadimcn.vscode-lldb # CodeLLDB
      nixpkgs.wakatime.vscode-wakatime # WakaTime
      openvsx.actboy168.tasks # Tasks
      openvsx.antfu.iconify # Iconify IntelliSense
      openvsx.ctcuff.font-preview # Font Preview
      openvsx.mjmlio.vscode-mjml # MJML Official
      openvsx.pascalreitermann93.vscode-yaml-sort # YAML Sort
      openvsx.tyriar.luna-paint # Luna Paint
      openvsx.vivaxy.vscode-conventional-commits # Conventional Commits
      marketplace.alexcvzz.vscode-sqlite # SQLite
      marketplace.fabiospampinato.vscode-diff # Diff
      #marketplace.local-smart.excel-live-server # XVBA - Live Server VBA
      marketplace.plibither8.remove-comments # Remove Comments
      marketplace.pwabuilder.pwa-studio # PWABuilder Studio #TODO: deprecate
      # python
      nixpkgs.ms-python.black-formatter # Black Formatter
      nixpkgs.ms-python.isort # isort
      nixpkgs.ms-python.debugpy # Python Debugger
      nixpkgs.ms-python.python # Python
      nixpkgs.ms-python.vscode-pylance # Pylance
      # java
      nixpkgs.redhat.java # Language Support for Java
      # html/css
      nixpkgs.svelte.svelte-vscode # Svelte for VS Code
      nixpkgs.bradlc.vscode-tailwindcss # Tailwind CSS IntelliSense
      nixpkgs.tauri-apps.tauri-vscode # Tauri
      # themes
      nixpkgs.zguolee.tabler-icons # Tabler Product Icons
      nixpkgs.emmanuelbeziat.vscode-great-icons # VSCode Great Icons
      # vscode markdown preview look like gh
      nixpkgs.bierner.markdown-checkbox # Markdown Checkboxes
      nixpkgs.bierner.markdown-emoji # Markdown Emoji
      nixpkgs.bierner.markdown-footnotes # Markdown Footnotes
      nixpkgs.bierner.markdown-mermaid # Markdown Preview Mermaid Support
      nixpkgs.bierner.markdown-preview-github-styles # Markdown Preview Github Styling
      marketplace.yahyabatulu.vscode-markdown-alert # Markdown Preview for Github Alerts
      # html/css
      openvsx.csstools.postcss # PostCSS Language Support
      openvsx.sysoev.language-stylus # stylus
      # python
      openvsx.ms-python.vscode-python-envs # Python Environments
      # html/css
      marketplace.george-alisson.html-preview-vscode # HTML Preview
      # themes
      marketplace.garytyler.darcula-pycharm # Darcula PyCharm Theme
      marketplace.squarelogic.theme-bright-day # Bright Day Theme
      marketplace.onecrayon.theme-quietlight-vsc # Quiet Light for VSC
      marketplace.larxx.zero-theme # zero theme
    ];
  };
  #TODO: fix this server thing
  /*
    services.vscode-server = {
      enable = true;
      installPath = "$HOME/.vscode";
    };
  */

  # we have to manage settings with home-manager
  home-manager.importUser = [
    (_: {
      programs.vscode = {
        enable = true;
        package = null;
        profiles.default = {
          keybindings = import ./keybinds.nix;
          userSettings = import ./settings.nix {
            inherit pkgs xelib;
          };
        };
      };
    })
  ];
}
