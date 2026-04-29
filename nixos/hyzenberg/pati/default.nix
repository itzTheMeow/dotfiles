{ pkgs, ... }:
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
      DynamicUser = true;
      StateDirectory = "pati";
      EnvironmentFile = "";

      # hardening
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
}
