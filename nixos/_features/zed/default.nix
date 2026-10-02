{
  home-manager.importUser = [ ./zed.hm.nix ];

  # set zed to default visual editor
  environment.variables.VISUAL = "zeditor --wait";
}
