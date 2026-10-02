{ pkgs, xelib, ... }: {
  programs.zed-editor = {
    enable = true;
    #TODO:26.11 flip back to stable
    package = pkgs.unstable.zed-editor-fhs;
    mutableUserSettings = false;
    extraPackages = with pkgs; [
      nixd
      nixfmt
    ];
    extensions = [
      # languages
      "deno"
      "git-firefly"
      "java"
      "svelte"
      "nix"
      "toml"
      "xml"
      "sql"
      "make"
      # tooling
      "dockerfile"
      "docker-compose"
      "github-actions"
      "wakatime"
      # markdown/web
      "mermaid"
      "comment" # better comments
      "emmet"
      "scss"
      "stylus"
      "mjml"
      "live-server"
      # icon theme
      "vscode-great-icons"
    ];
    userSettings = {
      disable_ai = true;
      auto_update = false;
      icon_theme = "VSCode Great Icons Theme";
      telemetry = {
        diagnostics = true;
        metrics = false;
      };
      search.search_on_type = true;
      git.inline_blame.enabled = false;
      git_panel = {
        show_count_badge = true;
        file_icons = true;
        tree_view = true;
        default_width = 280.0;
        dock = "left";
      };
      buffer_font_family = xelib.globals.fonts.code.name;
      terminal = {
        font_family = xelib.globals.fonts.terminal.name;
        show_count_badge = true;
      };
      project_panel = {
        hide_root = true;
        git_status_indicator = true;
        diagnostic_badges = true;
        scrollbar.horizontal_scroll = false;
        indent_size = 16.0;
        default_width = 280.0;
        dock = "left";
      };
      tabs = {
        show_diagnostics = "all";
        git_status = true;
        file_icons = true;
      };
      tab_bar.show_nav_history_buttons = false;
      toolbar = {
        quick_actions = false;
        breadcrumbs = true;
      };
      title_bar = {
        show_user_picture = false;
        show_user_menu = false;
        show_sign_in = false;
      };
      collaboration_panel.button = false;
      outline_panel.button = false;
      agent.button = false;
      prettier.allowed = true;
      colorize_brackets = true;
      middle_click_paste = false;
      completion_menu_item_kind = "symbol";
      tab_size = 2;
      buffer_font_size = 14.0;
      drag_and_drop_selection.delay = 500;
      autoscroll_on_clicks = true;
      hide_mouse = "never";
      multi_cursor_modifier = "cmd_or_ctrl";
      ui_font_family = "Noto Sans";
      languages.Nix = {
        language_servers = [
          "nixd"
          "!nil"
        ];
        formatter.external.command = "${pkgs.nixfmt}/bin/nixfmt";
      };
    };
  };

  catppuccin.zed = {
    enable = true;
  };
}
