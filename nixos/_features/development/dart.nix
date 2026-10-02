# dart/flutter
{
  config,
  host,
  pkgs,
  utils,
  ...
}:
let
  dir =
    if (config.persist.ed ? cache) then "${config.persist.ed.cache.path}/dart" else "/opt/dart_cache";
in
{
  environment.systemPackages = with pkgs; [
    flutter # provides dart too
  ];

  # set cache path to persisted directory
  environment.variables.PUB_CACHE = dir;
  systemd.tmpfiles.rules = [
    "d ${dir} 0755 ${host.username} users -"
  ];

  programs.vscode.extensions = with pkgs.vscode-stores; [
    nixpkgs.dart-code.dart-code # Dart
    nixpkgs.dart-code.flutter # Flutter
  ];

  home-manager.importUser = [
    (utils.vscodeSettings {
      "[dart]".editor = {
        rulers = [ 80 ];
        selectionHighlight = false;
        tabCompletion = "onlySnippets";
      };

      dart.checkForSdkUpdates = false;
      dart.hotReloadOnSave = "manual";
      dart.projectSearchDepth = 2;
    })
    (utils.zedExtensions [ "dart" ])
    # disable dart/flutter telemetry
    (_: {
      # version may need bumped if telemetry settings change
      home.file.".dart-tool/dart-flutter-telemetry.config".text = ''
        reporting=0

        vscode-plugins=2026-09-25,1
        flutter-tool=2026-09-25,1
        dart-tool=2026-09-25,1
      '';
    })
  ];
}
