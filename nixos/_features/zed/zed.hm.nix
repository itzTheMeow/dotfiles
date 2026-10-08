{
  hm,
  lib,
  pkgs,
  xelib,
  ...
}:
let
  #TODO:26.11 flip back to stable
  zed-editor = pkgs.unstable.zed-editor.overrideAttrs (old: {
    # ctrl-enter commits untracked files too when nothing is staged
    patches = (old.patches or [ ]) ++ [ ../../../patches/zed-commit-untracked.patch ];
  });
in
{
  programs.zed-editor = {
    enable = true;
    package = zed-editor.fhs;
    extensions = [
      # languages
      "git-firefly"
      "java"
      "svelte"
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

    mutableUserKeymaps = false;
    userKeymaps = import ./keymap.nix;

    mutableUserSettings = false;
    userSettings = import ./settings.nix {
      inherit hm lib xelib;
    };
  };
  catppuccin.zed.enable = true;

  # allow opening zed in current directory from dolphin
  xdg.dataFile = xelib.mkDolphinContextAction {
    name = "zed-open-here";
    action = "openZedHere";
    menuName = "Open Zed Here";
    icon = "zed";
    tryExec = "zeditor";
    exec = "zeditor %f";
  };

  # let zed edit its own keymap/settings, but reset them on every activation
  home.hijackEditable = {
    "${hm.config.xdg.configHome}/zed/keymap.json" = { };
    "${hm.config.xdg.configHome}/zed/settings.json" = { };
  };

  # no maximized/new window dimension setting in zed, so we use a kwin rule
  programs.plasma.window-rules = [
    {
      description = "Always start Zed maximized";
      match.window-class = {
        value = "dev.zed.Zed";
        match-whole = false;
      };
      match.window-types = [ "normal" ];
      apply = {
        maximizehorizontally = true;
        maximizevertically = true;
      };
    }
  ];
}
