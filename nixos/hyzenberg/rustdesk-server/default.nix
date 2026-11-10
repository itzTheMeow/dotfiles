{
  config,
  ...
}:
let
  app = config.apps.rustdesk;
  dataDir = "/var/lib/sctgdesk";
  # tag digest-pinned (sctg-v1.1.16-sctg.2, verified 2026-11-10) so the
  # third-party image can't drift under the tag
  image = "docker.io/sctg/sctgdesk-server:sctg-v1.1.16-sctg.2@sha256:a0328552165a3dba18e50eca86edb0bd4c699372ba96b622cab1354657233643";
in
{
  apps.rustdesk = {
    domain = "rustdesk.xela";
    port = 21114; # hbbs web console / API
    enableProxy = true;

    name = "RustDesk";
    description = "Remote Desktop";

    details = {
      relayPort = 21117;
    };
  };

  sops.groups.rustdesk = {
    server-key = "op://Private/okqmygckmjgcburvovuedkkxjm/password";
    server-public-key = "op://Private/okqmygckmjgcburvovuedkkxjm/username";
  };

  # the keypair has to exist before the servers start
  systemd.services.sctgdesk-keypair = {
    description = "Install the RustDesk server keypair";
    wantedBy = [ "multi-user.target" ];
    before = [
      "docker-hbbr.service"
      "docker-hbbs.service"
    ];
    after = [ "sops-install-secrets.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 0700 ${dataDir}
      install -m 0600 ${config.sops.groupPaths.rustdesk.server-key} ${dataDir}/id_ed25519
      install -m 0600 ${config.sops.groupPaths.rustdesk.server-public-key} ${dataDir}/id_ed25519.pub
    '';
  };

  systemd.services."docker-hbbr" = {
    requires = [ "sctgdesk-keypair.service" ];
    after = [ "sctgdesk-keypair.service" ];
  };
  systemd.services."docker-hbbs" = {
    requires = [ "sctgdesk-keypair.service" ];
    after = [ "sctgdesk-keypair.service" ];
  };

  virtualisation.oci-containers.containers = {
    hbbs = {
      image = image;
      autoStart = true;
      cmd = [
        "hbbs"
        "-r"
        "${app.ip}:${toString app.details.relayPort}"
      ];
      ports = [
        "${app.ip}:${app.portString}:${app.portString}"
        "${app.ip}:21115:21115"
        "${app.ip}:21116:21116"
        "${app.ip}:21116:21116/udp"
        "${app.ip}:21118:21118"
      ];
      volumes = [ "${dataDir}:/usr/local/share/sctgdesk" ];
      environment = {
        # force the relay instead of leaving clients to race a (firewalled)
        # direct peer connection that always ends up timing out into the relay
        ALWAYS_USE_RELAY = "Y";
      };
      dependsOn = [ "hbbr" ];
    };

    hbbr = {
      image = image;
      autoStart = true;
      cmd = [ "hbbr" ];
      ports = [
        "${app.ip}:21117:21117"
        "${app.ip}:21119:21119"
      ];
      volumes = [ "${dataDir}:/usr/local/share/sctgdesk" ];
    };
  };
}
