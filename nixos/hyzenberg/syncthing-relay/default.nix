{ config, ... }:
let
  app = config.apps.syncthing-relay;
in
{
  apps.syncthing-relay = {
    name = "syncthing-relay";
    port = 20089;

    details = {
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
        # we dont need any of this
        globalAnnounceEnabled = false;
        localAnnounceEnabled = false;
        relaysEnabled = false;
        natEnabled = false;
      };
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
