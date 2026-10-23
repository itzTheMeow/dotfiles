{
  hostname,
  pkgs,
  xelib,
  ...
}:
let
  mirror = pkgs.xela-apt-mirror;
  subdomain = "apt-mirrors";
  dataDir = "/var/lib/apt-mirrors";

  # master repo list
  repos = [
    {
      name = "cydia";
      url = "https://apt.saurik.com";
    }
    {
      name = "zodttd";
      url = "https://zodttd.saurik.com/repo/cydia";
    }
    {
      name = "victorlobe";
      url = "https://repo.victorlobe.me/";
    }
    {
      name = "invoxiplaygames";
      url = "https://cydia.invoxiplaygames.uk/";
    }
    {
      name = "invoxiplaygames-beta";
      url = "https://cydia.invoxiplaygames.uk/beta";
    }
    {
      name = "zebra";
      url = "https://getzbra.com/repo";
    }
    # http://modmyi.saurik.com
  ];

  mirrorConfig = pkgs.writeText "apt-mirror-config.json" (
    builtins.toJSON {
      dataDir = dataDir;
      publicUrl = "https://${subdomain}.${xelib.domain}";
      repos = map (r: {
        url = r.url;
        name = r.name or "";
        insecure = r.insecure or false;
      }) repos;
    }
  );
in
{
  services.nginx.virtualHosts."${subdomain}.${xelib.domain}" = {
    addSSL = true;
    enableACME = true;
    root = dataDir;
    locations."/".extraConfig = ''
      autoindex on;
      index index.html;
    '';
    locations."~* /_archive/depictions/.*\\.html$".extraConfig = ''
      add_header Content-Security-Policy "default-src 'none'; script-src 'none'; img-src 'self'; style-src 'self' 'unsafe-inline'; frame-ancestors 'none';" always;
    '';
  };

  dnszones.list.${xelib.domain}.subdomains.${subdomain} = with xelib.dns; pointHost hostname;

  # needs a dedicated /var/lib directory/user
  # we cant use DynamicUser because it needs to be readable for nginx
  users.users.apt-mirror = {
    isSystemUser = true;
    group = "apt-mirror";
  };
  users.groups.apt-mirror = { };

  systemd.services.apt-mirror = {
    description = "Mirror legacy iOS apt repositories";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${mirror}/bin/xela-apt-mirror --config ${mirrorConfig}";
      User = "apt-mirror";
      Group = "apt-mirror";
      StateDirectory = "apt-mirrors";
      StateDirectoryMode = "0755";
      UMask = "0022";
      TimeoutStartSec = "2h";

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ dataDir ];
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      CapabilityBoundingSet = "";
    };
  };

  systemd.timers.apt-mirror = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
