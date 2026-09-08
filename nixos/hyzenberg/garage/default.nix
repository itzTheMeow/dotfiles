{
  config,
  lib,
  pkgs,
  ...
}:
let
  app = config.apps.garage;
  garage = "${config.services.garage.package}/bin/garage";
in
{
  apps.garage = {
    domain = "garage.xela";
    port = 12870;
    enableProxy = true;
    details = {
      rpcPort = 12871;
      adminPort = 12872;
      # buckets that are automatically created
      buckets = [ "siyuan" ];
    };
  };

  services.garage = {
    enable = true;
    package = pkgs.garage_2;
    environmentFile = config.sops.secrets.garage.path;
    settings = {
      replication_factor = 1;
      metadata_dir = "/var/lib/garage/meta";
      data_dir = "/var/lib/garage/data";
      rpc_bind_addr = "127.0.0.1:${toString app.details.rpcPort}";
      s3_api = {
        api_bind_addr = "${app.ip}:${app.portString}";
        s3_region = "master";
      };
      admin = {
        api_bind_addr = "127.0.0.1:${toString app.details.adminPort}";
      };
    };
  };

  # the nixpkgs module doesn't expose a way to pass --single-node
  systemd.services.garage.serviceConfig.ExecStart = lib.mkForce "${garage} server --single-node";

  sops.envFiles.garage = {
    GARAGE_RPC_SECRET = "op://Private/tc3lcp6iqeryw544ethx4yopiq/RPC Secret";
    GARAGE_ADMIN_TOKEN = "op://Private/tc3lcp6iqeryw544ethx4yopiq/Admin Token";
  };

  #  creates any declared buckets and their access keys
  #  retreive keys for buckets as needed with:
  #? garage key info <bucket>
  systemd.services.garage-buckets = {
    description = "Create Garage buckets";
    after = [ "garage.service" ];
    requires = [ "garage.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets.garage.path;
    };
    script = lib.concatMapStringsSep "\n" (bucket: ''
      ${garage} bucket create ${bucket} 2>/dev/null || true
      if ! ${garage} key info ${bucket} >/dev/null 2>&1; then
        ${garage} key create ${bucket} >/dev/null 2>&1
      fi
      ${garage} bucket allow --read --write --owner ${bucket} --key ${bucket} 2>/dev/null || true
    '') app.details.buckets;
  };
}
