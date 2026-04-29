{ config, pkgs, ... }:
let
  pati = pkgs.callPackage ./package.nix { };
in
{
  systemd.services.pati = {
    description = "Pati Node.js Service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${pati}/bin/pati";
      StateDirectory = "pati";
      EnvironmentFile = config.sops.secrets.pati.path;

      # hardening
      DynamicUser = true;
      ProtectSystem = "strict";
      CapabilityBoundingSet = "";
    };

    environment = {
      DATA_ROOT = "/var/lib/pati";
      # assorted env vars for prod
      clientId = "1399236707349561414";
      testServer = "946959817170378803";
      mainServer = "1379699654836617260";
    };
  };

  sops.envFiles.pati = {
    TOKEN = "op://Private/4qjwtji7howkyesw6ppos7hgvu/credential";
  };
}
