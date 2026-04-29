{
  config,
  xelib,
  ...
}:
let
  app = config.apps.vencloud;
  dockerIP = "172.17.0.1";
in
{
  apps.vencloud = {
    domain = "vencloud.xela";
    port = 8856;
    enableProxy = true;
    details = {
      redisPort = 21839;
    };
  };

  services.redis.servers.vencloud = {
    enable = true;
    bind = dockerIP;
    port = app.details.redisPort;
    save = [
      [
        300
        1
      ]
      [
        60
        10
      ]
    ];
    settings.protected-mode = "no";
  };
  # open redis in the firewall for docker
  networking.firewall.extraCommands = ''
    iptables -A INPUT -i docker0 -p tcp --dport ${toString app.details.redisPort} -j ACCEPT
  '';

  # we have to use docker for this until this is stable:
  # https://github.com/NixOS/nixpkgs/pull/374132
  virtualisation.oci-containers.containers = {
    vencloud = {
      image = "ghcr.io/vencord/vencloud";
      autoStart = true;
      ports = [ "${app.ip}:${app.portString}:8080" ];
      environment = {
        HOST = "0.0.0.0";
        PORT = "8080";
        REDIS_URI = "${dockerIP}:${toString app.details.redisPort}";
        ROOT_REDIRECT = "https://github.com/Vencord/Vencloud";
        DISCORD_CLIENT_ID = "1387503793616191669";
        DISCORD_REDIRECT_URI = app.url + "/v1/oauth/callback";
        ALLOWED_USERS = xelib.myDiscordID;
        PROMETHEUS = "false";
        PROXY_HEADER = "X-Forwarded-For";
        SIZE_LIMIT = "32000000"; # 32MB
      };
      environmentFiles = [
        config.sops.secrets.vencloud.path
      ];
    };
  };
  systemd.services.docker.after = [ "redis-vencloud.service" ];

  sops.envFiles.vencloud = {
    DISCORD_CLIENT_SECRET = "op://Private/73o55de5oggdocdq7prt3jlu7u/Discord Client Secret";
    PEPPER_SECRETS = "op://Private/73o55de5oggdocdq7prt3jlu7u/Pepper Secrets";
    PEPPER_SETTINGS = "op://Private/73o55de5oggdocdq7prt3jlu7u/Pepper Settings";
  };
}
