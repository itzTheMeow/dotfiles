{ config, host, ... }:
let
  addr = "${host.ip}:19789";
  dataDir = "/var/lib/multi-scrobbler";
in
{
  virtualisation.oci-containers.containers.multi-scrobbler = {
    image = "docker.io/foxxmd/multi-scrobbler:0.13.1";
    autoStart = true;
    ports = [ "${addr}:9078" ];
    volumes = [ "${dataDir}:/config" ];
    environment = {
      TZ = config.time.timeZone;
      BASE_URL = "http://${addr}";
      TAUTULLI_USER = "brayden.indigo";
    };
    environmentFiles = [
      config.sops.secrets.multi-scrobbler.path
    ];
  };

  sops.envFiles.multi-scrobbler = {
    LASTFM_API_KEY = "op://Private/3mgphqtpmtklwoaud2hbenuyy4/username";
    LASTFM_SECRET = "op://Private/3mgphqtpmtklwoaud2hbenuyy4/credential";
  };

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0755 root root -"
  ];
}
