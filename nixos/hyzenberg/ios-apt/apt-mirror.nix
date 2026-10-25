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
      name = "bigboss";
      url = "https://apt.thebigboss.com/repofiles/cydia";
    }
    {
      name = "cydia";
      url = "https://apt.saurik.com";
      distribution = "tangelo";
    }
    {
      name = "modmyi";
      url = "http://modmyi.saurik.com";
      distribution = "stable";
    }
    {
      name = "chariz";
      url = "https://repo.chariz.com";
    }
    {
      name = "havoc";
      url = "https://havoc.app";
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
      name = "igamegod";
      url = "https://igamegod.app/repo";
    }
    {
      name = "zebra";
      url = "https://getzbra.com/repo";
    }
    {
      name = "coolbooter";
      url = "https://coolbooter.com";
    }
    {
      name = "adrienrl1"; # AppDrop
      url = "https://adrienrl1.github.io/cydia";
    }
    {
      name = "zestlabs"; # ReformX
      url = "https://zestlabs.github.io";
    }
    {
      name = "kittymaxine";
      url = "https://kittymaxine.com/repo";
    }
    {
      name = "julioverne";
      url = "https://julioverne.github.io";
    }
    {
      name = "preloading";
      url = "https://cydia.preloading.dev";
    }
    {
      name = "lenglengyu";
      url = "https://lenglengyu.com";
    }
    {
      name = "frida";
      url = "https://build.frida.re";
    }
    {
      name = "ellekit";
      url = "https://ellekit.space";
    }
    {
      name = "opa334";
      url = "https://opa334.github.io";
    }
    {
      name = "palera1n";
      url = "https://repo.palera.in";
    }
    {
      name = "getutm";
      url = "https://cydia.getutm.app";
    }
    {
      name = "dxcool223-repo";
      url = "https://dxcool223-repo.github.io/repo";
    }
    {
      name = "0xilis";
      url = "https://0xilis.github.io/rootless";
    }

    # https://cydia.ichitaso.com
    # https://ios.jjolano.me
    # https://paisseon.github.io
    # https://poomsmart.github.io/repo
    # https://apt.procurs.us
    # https://sparkdev.me
  ];

  mirrorConfig = pkgs.writeText "apt-mirror-config.json" (
    builtins.toJSON {
      dataDir = dataDir;
      publicUrl = "https://${subdomain}.${xelib.domain}";
      repos = map (r: {
        url = r.url;
        name = r.name or "";
        distribution = r.distribution or "";
        insecure = r.insecure or false;
      }) repos;
    }
  );

  # static package-manager app icons
  appIcons = pkgs.linkFarm "apt-mirror-app-icons" [
    {
      name = "cydia.png";
      path = pkgs.fetchurl {
        url = "https://web.archive.org/web/20110826042342im_/http://cydia.saurik.com/icon.png";
        hash = "sha256-STJa0dO86A5/tmSM271qAydycn8IaZOBKXUV91iXbqw=";
      };
    }
    {
      name = "sileo.png";
      path = pkgs.fetchurl {
        url = "https://web.archive.org/web/20261003142242im_/https://getsileo.app/img/icon.png";
        hash = "sha256-zUqseciAkV9iDWkgbHbIKwqV1vZbJUH2RRImaKZey8Q=";
      };
    }
    {
      name = "zebra.png";
      path = pkgs.fetchurl {
        url = "https://web.archive.org/web/20220105021954im_/https://getzbra.com/apple-touch-icon.png";
        hash = "sha256-EqIVyGmFkYfPQLsXH9a2ZgAcnIE2/0k5w4T4IsyTy4w=";
      };
    }
  ];
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
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p ${dataDir}/assets/apps"
        "${pkgs.coreutils}/bin/cp -f ${appIcons}/cydia.png ${appIcons}/sileo.png ${appIcons}/zebra.png ${dataDir}/assets/apps/"
      ];
      ExecStart = "${mirror}/bin/xela-apt-mirror --config ${mirrorConfig}";
      User = "apt-mirror";
      Group = "apt-mirror";
      StateDirectory = "apt-mirrors";
      StateDirectoryMode = "0755";
      UMask = "0022";
      TimeoutStartSec = "6h";

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
