{
  config,
  lib,
  pkgs,
  ...
}:
let
  app = config.apps.minio;
  mc = "${pkgs.minio-client}/bin/mc";
in
{
  apps.minio = {
    domain = "minio.xela";
    port = 12870;
    enableProxy = true;
    details = {
      buckets = [ "siyuan" ];
    };
  };

  services.minio = {
    enable = true;
    listenAddress = "${app.ip}:${app.portString}";
    dataDir = [ "/var/lib/minio/data" ];
    configDir = "/var/lib/minio/config";
    browser = false;
    rootCredentialsFile = config.sops.secrets.minio.path;
  };

  sops.envFiles.minio = {
    MINIO_ROOT_USER = "op://Private/czdrz6yoojzkvpcyyoii4ttwxq/username";
    MINIO_ROOT_PASSWORD = "op://Private/czdrz6yoojzkvpcyyoii4ttwxq/password";
  };

  # creates the minio buckets declaratively if they dont exist already
  systemd.services.minio-create-buckets = {
    description = "Create MinIO buckets";
    after = [ "minio.service" ];
    requires = [ "minio.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = config.sops.secrets.minio.path;
    };
    script = ''
      ${mc} alias set local http://${app.ip}:${app.portString} \
        "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
      ${lib.concatMapStringsSep "\n" (
        bucket: "${mc} mb --ignore-existing local/${bucket}"
      ) app.details.buckets}
    '';
  };
}
