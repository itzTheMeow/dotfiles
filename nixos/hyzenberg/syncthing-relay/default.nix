{
  config,
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
    port = 20089;
    details = {
      # sync ID of this relay, for other hosts to consume
      id = "CGZGNUC-E3AKRNY-5ABDCXC-U4TXJAU-SB4RWGJ-H74RL32-I4I2VUN-2CUJDQY";
    };
  };

  services.syncthing = {
    enable = true;
    cert = config.sops.secrets.syncthing-relay-cert.path;
    key = config.sops.secrets.syncthing-relay-key.path;

    overrideDevices = true;
    overrideFolders = true;

    settings = {
      options = {
        listenAddresses = [ "tcp://${app.ip}:${app.portString}" ];
        # we dont need any of this
        globalAnnounceEnabled = false;
        localAnnounceEnabled = false;
        relaysEnabled = false;
        natEnabled = false;
      };
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
      }) syncFolders;
    };
  };
  systemd.services.syncthing.after = [ "tailscale-online.service" ];

  sops.secrets.syncthing-relay-cert = {
    sopsFile = config.sops.opSecrets.syncthing-relay.fullPath;
    key = "cert";
  };
  sops.secrets.syncthing-relay-key = {
    sopsFile = config.sops.opSecrets.syncthing-relay.fullPath;
    key = "key";
  };
  sops.opSecrets.syncthing-relay.keys = {
    cert = "op://Private/hhigbwqelxxbtmnltlrwklilyy/cert";
    key = "op://Private/hhigbwqelxxbtmnltlrwklilyy/key";
  };
}
