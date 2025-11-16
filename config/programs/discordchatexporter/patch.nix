{ pkgs }:
with pkgs;
discordchatexporter-desktop.overrideAttrs (old: {
  # add a desktop file with an icon
  nativeBuildInputs = old.nativeBuildInputs ++ [ copyDesktopItems ];
  postFixup = old.postFixup + ''
    mkdir -p $out/share/icons/hicolor/256x256/apps
    cp $src/favicon.png $out/share/icons/hicolor/256x256/apps/discordchatexporter.png
  '';
  desktopItems = [
    (makeDesktopItem {
      name = "discordchatexporter";
      desktopName = "Discord Chat Exporter";
      exec = "discordchatexporter";
      icon = "discordchatexporter";
      comment = "Export Discord chat logs";
      categories = [ "Utility" ];
    })
  ];
})
