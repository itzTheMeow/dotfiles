{
  config,
  host,
  lib,
  self,
  xelib,
  ...
}:
let
  app = config.apps.syncthing-relay;

  # aggregate sync folders from all hosts into { folderName = [ hosts... ]; }
  syncFolders = lib.mapAttrs (_: lib.unique) (
    lib.foldAttrs (a: b: a ++ b) [ ] (
      map (
        host:
        let
          cfg = self.nixosConfigurations.${host}.config.persist.sync or { };
        in
        lib.genAttrs (builtins.attrNames cfg) (_: [ host ])
      ) (builtins.attrNames self.nixosConfigurations)
    )
  );
in
{
  apps.syncthing-relay = {
    domain = "syncthing.xela";
    port = 20088; # web UI port
    enableProxy = true;

    name = "Syncthing Relay";
    description = "File Sync Status";
    icon = "syncthing";

    details = {
      # sync ID of this relay, for other hosts to consume
      id = "CGZGNUC-E3AKRNY-5ABDCXC-U4TXJAU-SB4RWGJ-H74RL32-I4I2VUN-2CUJDQY";
      # port for syncthing itself
      syncPort = 20089;
      # default syncthing options to share between relay/hosts
      settings = {
        gui.theme = "black";
        options = {
          urAccepted = 3;
          # we dont need any of this
          startBrowser = false;
          globalAnnounceEnabled = false;
          localAnnounceEnabled = false;
          relaysEnabled = false;
          natEnabled = false;
        };
      };
    };
  };

  services.syncthing = {
    enable = true;
    cert = config.sops.secrets.syncthing-relay-cert.path;
    key = config.sops.secrets.syncthing-relay-key.path;

    overrideDevices = true;
    overrideFolders = true;

    # gui has to be on localhost for API to work
    guiAddress = "127.0.0.1:${app.portString}";
    guiPasswordFile = config.sops.secrets.syncthing-relay-password.path;

    settings = lib.recursiveUpdate {
      gui.user = host.username;
      gui.insecureSkipHostcheck = true;
      options.listenAddresses = [ "tcp://${app.ip}:${toString app.details.syncPort}" ];
      # map all possible sync targets to devices
      devices = lib.genAttrs (builtins.attrNames (lib.filterAttrs (_: h: h ? syncID) xelib.hosts)) (
        hn:
        let
          host = xelib.hosts.${hn};
        in
        {
          id = host.syncID;
          addresses = [ "tcp://${host.ip}:${toString host.ports.syncthing}" ];
        }
      );
      folders = lib.mapAttrs (name: devices: {
        path = "~/${name}";
        type = "receiveencrypted";
        inherit devices;
        ignorePerms = false;
      }) syncFolders;
    } app.details.settings;
  };
  systemd.services.syncthing.after = [ "tailscale-online.service" ];
  # host needs overridden to local for the webui
  nginx.proxy.${app.domain}.target.host = lib.mkForce "127.0.0.1";

  sops.secrets.syncthing-relay-cert = {
    sopsFile = config.sops.opSecrets.syncthing-relay.fullPath;
    key = "cert";
  };
  sops.secrets.syncthing-relay-key = {
    sopsFile = config.sops.opSecrets.syncthing-relay.fullPath;
    key = "key";
  };
  sops.secrets.syncthing-relay-password = {
    sopsFile = config.sops.opSecrets.syncthing-relay.fullPath;
    key = "password";
    owner = config.services.syncthing.user;
  };
  sops.opSecrets.syncthing-relay.keys = {
    cert = "op://Private/hhigbwqelxxbtmnltlrwklilyy/cert";
    key = "op://Private/hhigbwqelxxbtmnltlrwklilyy/key";
    password = "op://Private/mlozpipzstum3fe7cdu4yh3254/password";
  };
}
