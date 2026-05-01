{
  config,
  xelib,
  ...
}:
let
  app = config.apps.freshrss;
  dataDir = "/var/lib/freshrss";
in
{
  apps.freshrss = {
    domain = "freshrss.xela";
    port = 39803;
    enableProxy = true;

    name = "FreshRSS";
    description = "RSS Reader";
  };

  # we have to use docker here because the nixos module doesnt support OIDC
  virtualisation.oci-containers.containers.freshrss = {
    image = "docker.io/freshrss/freshrss:1.28.1";
    autoStart = true;
    ports = [ "${app.ip}:${app.portString}:80" ];
    volumes = [ "${dataDir}:/var/www/FreshRSS/data" ];
    environment = {
      TZ = config.time.timeZone;
      BASE_URL = app.url;
      SERVER_DNS = app.domain;
      CRON_MIN = "2,32";
      TRUSTED_PROXY = "127.0.0.1 5.161.177.144 172.16.0.1/12 192.168.0.1/16";

      OIDC_ENABLED = "1";
      OIDC_PROVIDER_METADATA_URL = "${xelib.apps.pocket-id.url}/.well-known/openid-configuration";
      OIDC_SCOPES = "openid email profile";
      OIDC_X_FORWARDED_HEADERS = "X-Forwarded-Proto X-Forwarded-Host";
      OIDC_REMOTE_USER_CLAIM = "preferred_username";
    };
    environmentFiles = [
      config.sops.secrets.freshrss.path
    ];
  };

  sops.envFiles.freshrss = {
    OIDC_CLIENT_ID = "op://Private/biypnpycbanvctdetai5ljx2ku/username";
    OIDC_CLIENT_SECRET = "op://Private/biypnpycbanvctdetai5ljx2ku/credential";
  };

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0755 root root -"
  ];
}
