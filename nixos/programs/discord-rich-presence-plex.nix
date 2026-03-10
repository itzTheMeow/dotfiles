{
  config,
  pkgs,
  xelib,
  ...
}:
let
  # this is just a shorthand name so its not repeated 12 times in the file
  DRRP = "discord-rich-presence-plex";
  dataDir = "/var/lib/${DRRP}";

  configYAML = {
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
        enabled = false;
        imgurClientID = "";
        maxSize = 256;
        fit = false;
      };
      buttons = [ ];
    };
    users = [
      {
        token = config.sops.placeholder.${DRRP};
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
  systemd.paths.${DRRP} = {
    description = "Watch for Discord IPC socket";
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathExists = "/run/user/1000/discord-ipc-0";
    };
  };
  systemd.services.${DRRP} = {
    description = "Discord Rich Presence for Plex";

    serviceConfig = {
      ExecStartPre = [
        # set permissions on the IPC socket for the user
        "+${pkgs.acl}/bin/setfacl -m u:${DRRP}:rw /run/user/1000/discord-ipc-0"

        # symlink config to the data directory
        (pkgs.writeShellScript "copy-config" ''
          mkdir -p ./data
          ln -sf "$CREDENTIALS_DIRECTORY/config" ./data/config.yaml
        '')
      ];
      # actually run the app
      ExecStart = "${pkgs.${DRRP}}/bin/${DRRP}";

      StateDirectory = DRRP;
      WorkingDirectory = dataDir;
      # load the credential using systemd so the dynamic user has access
      LoadCredential = "config:${config.sops.templates."${DRRP}-config.yaml".path}";

      DynamicUser = true;
      # pass /run/user/1000 to the service for the IPC socket
      BindPaths = [ "/run/user/1000" ];
      Environment = "XDG_RUNTIME_DIR=/run/user/1000";

      Restart = "always";
      RestartSec = 5;
    };
  };

  sops.secrets.${DRRP} = {
    sopsFile = ../../${config.sops.opSecrets.plex.path};
    key = "token";
  };
  sops.opSecrets.plex.keys.token = "op://Private/sqrukknhtojit3kzwplkvy3zji/Token";
  sops.templates."${DRRP}-config.yaml".content = xelib.toYAMLString configYAML;

  # gives permission to groups to traverse the /run/user directory
  services.udev.extraRules = ''
    SUBSYSTEM=="tmpfs", KERNEL=="user", MODE="0710"
  '';
}
