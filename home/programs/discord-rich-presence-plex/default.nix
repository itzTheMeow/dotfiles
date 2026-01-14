{ pkgs, utils, ... }:
let
  config = {
    logging = {
      debug = true;
      writeToFile = false;
    };
    display = {
      duration = false;
      genres = true;
      album = true;
      albumImage = true;
      artist = true;
      artistImage = true;
      year = true;
      statusIcon = false;
      progressMode = "bar";
      statusTextType = {
        watching = "title";
        listening = "artist";
      };
      paused = false;
      posters = {
        enabled = true;
        imgurClientID = "";
        maxSize = 256;
        fit = false;
      };
      buttons = [ ];
    };
    users = [
      {
        token = "op://Private/Plex/Token";
        servers = [
          {
            name = "MeowVPS";
            listenForUser = "ALEXMEOW4560";
          }
        ];
      }
    ];
  };
in
{
  home = {
    packages = [ pkgs.discord-rich-presence-plex ];
    file = utils.mkSecretFile ".local/share/discord-rich-presence-plex/data/config.yaml" (
      builtins.readFile ((pkgs.formats.yaml { }).generate "discord-plex-config" config).outPath
    );

    # we have to (re)start after secrets are injected into the config file
    activation.startDiscordPlex = {
      after = [ "opinject" ];
      before = [ ];
      data = ''
        $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user restart discord-rich-presence-plex.service
      '';
    };
  };

  systemd.user.services.discord-rich-presence-plex = {
    Unit = {
      Description = "Discord Rich Presence for Plex";
      After = [ "network.target" ];
    };

    Service = {
      ExecStart = "${pkgs.discord-rich-presence-plex}/bin/discord-rich-presence-plex";
      WorkingDirectory = "%h/.local/share/discord-rich-presence-plex";
      Restart = "always";
      RestartSec = 5;
    };

    Install = {
      WantedBy = [ ];
    };
  };
}
