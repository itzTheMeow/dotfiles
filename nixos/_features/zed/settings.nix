{
  hm,
  lib,
  xelib,
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
  # editor
  format_on_save = "on";
  tab_size = 2;
  inline_code_actions = false;
  sticky_scroll.enabled = true;
  indent_guides.coloring = "indent_aware";
  gutter.git_gutter_width.custom = 1.0;
  colorize_brackets = true;
  middle_click_paste = false;
  multi_cursor_modifier = "cmd_or_ctrl";
  drag_and_drop_selection.delay = 500;
  autoscroll_on_clicks = true;
  hide_mouse = "never";
  completion_menu_item_kind = "symbol";
  search.search_on_type = true;
  inlay_hints = {
    enabled = true;
    show_type_hints = false;
  };

  # appearance
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
  ui_font_family = xelib.globals.fonts.system.name;
  buffer_font_family = xelib.globals.fonts.code.name;
  agent_buffer_font_family = xelib.globals.fonts.system.name;
  buffer_font_size = 14.0;
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
  agent = {
    dock = "right";
    threads_sidebar = {
      auto_open = false;
      position = "right";
    };
  };
  window_title_separator = " | ";
  window_title_format = "\${projectName}\${separator}\${fileName}";

  # terminal
  terminal = {
    font_family = xelib.globals.fonts.terminal.name;
    show_count_badge = true;
  };

  # git
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

  # cli
  cli_default_open_behavior = "existing_window";

  # telemetry
  telemetry = {
    diagnostics = true;
    metrics = false;
  };

  # updates
  auto_update = false;

  # languages
  prettier.allowed = true;
  languages.Java.code_actions_on_format."source.organizeImports" = true;
}
