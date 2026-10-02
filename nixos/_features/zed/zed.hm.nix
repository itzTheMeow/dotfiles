{
  pkgs,
  xelib,
  lib,
  hm,
  ...
}:
let
  # all for catppuccin theme
  inherit (hm.config.catppuccin.zed) flavor accent italics;
  catppuccinThemeJSON = builtins.fromJSON (
    builtins.readFile "${hm.config.catppuccin.sources.zed}/catppuccin-${
      lib.optionalString (!italics) "no-italics-"
    }${accent}.json"
  );
  catppuccinThemeName =
    "Catppuccin ${
      {
        latte = "Latte";
        frappe = "Frappé";
        macchiato = "Macchiato";
        mocha = "Mocha";
      }
      .${flavor}
    }"
    + lib.optionalString (accent != "mauve") " (${accent})"
    + lib.optionalString (!italics) " - No Italics";
in
{
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
      "comment"
      "emmet"
      "scss"
      "stylus"
      "mjml"
      # icon theme
      "vscode-great-icons"
    ];
    userSettings = {
      disable_ai = true;
      auto_update = false;
      icon_theme = "VSCode Great Icons Theme";
      # fix comment colors not matching theme
      theme_overrides.${catppuccinThemeName}.syntax =
        let
          theme = lib.findFirst (
            t: t.name == catppuccinThemeName
          ) (throw "catppuccin zed theme '${catppuccinThemeName}' not found") catppuccinThemeJSON.themes;
          commentColor = scope: theme.style.syntax.${scope}.color;
        in
        {
          "constant.comment.todo".color = commentColor "comment.todo";
          "string.comment.info".color = commentColor "comment.info";
          "property.comment.error".color = commentColor "comment.error";
          "keyword.comment.warn".color = commentColor "comment.warn";
        };
      window_title_separator = " | ";
      window_title_format = "\${projectName}\${separator}\${fileName}";
      telemetry = {
        diagnostics = true;
        metrics = false;
      };
      search.search_on_type = true;
      inlay_hints = {
        show_type_hints = false;
        enabled = true;
      };
      format_on_save = "on";
      indent_guides.coloring = "indent_aware";
      inline_code_actions = false;
      gutter.git_gutter_width.custom = 1.0;
      sticky_scroll.enabled = true;
      git.inline_blame.enabled = false;
      git_panel = {
        folder_indicator = "both";
        group_by = "staging";
        fallback_branch_name = "main";
        status_style = "label_color";
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
        folder_indicator = "both";
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
      toolbar.quick_actions = false;
      title_bar = {
        show_branch_status_icon = true;
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

  catppuccin.zed.enable = true;
}
