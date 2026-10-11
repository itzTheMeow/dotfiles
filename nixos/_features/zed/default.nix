{
  home-manager.importUser = [ ./zed.hm.nix ];

  # set zed to default visual editor
  environment.sessionVariables.VISUAL = "zeditor --wait";
}
