{ config, pkgs, ... }:
let
  pati = pkgs.callPackage ./package.nix { };
in
{
  systemd.services.pati = {
    description = "Pati Node.js Service";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${pati}/bin/pati";
      StateDirectory = "pati";
      EnvironmentFile = config.sops.secrets.pati.path;
      Restart = "always";

      # hardening
      DynamicUser = true;
      ProtectSystem = "strict";
      CapabilityBoundingSet = "";
    };

    environment = {
      DATA_ROOT = "/var/lib/pati";
    };
  };

  sops.envFiles.pati = {
    TOKEN = "op://2whv374zwx3mc54pgiv5t3k4ui/eqa7quqxqdb6kknkz6iwn6niv4/credential";
  };
}
