{
  config,
  host,
  xelib,
  ...
}:
{
  persist.settings.wipeOnBoot = {
    enable = true;
    keepDays = 7;
  };

  persist.ed = {
    persist = {
      directories = [
        "/etc/NetworkManager/system-connections"
        {
          var = {
            lib = [
              "bluetooth"
              "tailscale"
            ];
          };
        }
      ];
    };

    home = {
      userDirectories = [
        xelib.locationDir
        ".config/1Password"
        ".config/app.yaak.desktop"
        ".config/blender"
        ".config/chromium"
        ".config/Code"
        ".config/Element"
        ".config/figma-linux"
        ".config/gh" # TODO: make declarative
        ".config/GIMP"
        ".config/godot"
        ".config/inkscape"
        ".config/Joplin" # electron
        ".config/joplin-desktop" # user data
        ".config/libreoffice"
        ".config/MongoDB Compass"
        ".config/obs-studio"
        ".config/pcloud"
        ".config/Pinta"
        ".config/Plexamp"
        ".config/RSS Guard 4"
        ".config/teams-for-linux"
        ".config/timefinder-electron"
        ".config/vesktop"
        ".local"
        ".mozilla"
        ".pcloud"
        ".pki" # chromium certs
        ".thunderbird"
        ".vscode-shared"
        ".vscode"
        ".wakatime"
        ".wine"
        "ActivityWatchSync"
        "Documents"
        "Downloads"
        "JoplinBackup"
        "Music"
        "Pictures"
        "Videos"
      ];
      userFiles = [
        ".ssh/known_hosts"
        ".wakatime.cfg"
        ".config/Fougue Ltd/Mayo.conf"
        ".config/discordchatexporter/Settings.dat"
        ".config/op/config"
        ".config/pegasus-frontend/stats.db"
        ".config/qalculate/qalculate-qt.cfg"
        ".config/qdiskinfo/qdiskinfo.conf" # TODO: make declarative
      ];
    };

    cache = {
      userDirectories = [
        ".local/share/Trash"
        {
          ".cache" = [
            "chromium"
            "mozilla"
            "nix"
            "rustic"
            "typescript"
            "vscode-cpptools"
          ];
        }
      ];
      compression = 5;
      compressForce = true;
    };
  };

  # sops needs direct access to the key
  sops.age.sshKeyPaths = [
    "${config.persist.ed.persist.path}/etc/ssh/ssh_host_ed25519_key"
  ];

  # set custom store paths for tools
  environment.variables = {
    # bun
    BUN_INSTALL = "${config.persist.ed.cache.path}/bun"; # this isnt documented but its in the bun source code
    # dart
    PUB_CACHE = "${config.persist.ed.cache.path}/dart";
    # go
    GOCACHE = "${config.persist.ed.cache.path}/go/build";
    GOPATH = "${config.persist.ed.cache.path}/go/path";
    # pnpm
    PNPM_HOME = "${config.persist.ed.cache.path}/pnpm";
  };

  # make sure referenced directories exist
  systemd.tmpfiles.rules =
    map (dir: "d ${config.persist.ed.cache.path}/${dir} 0755 ${host.username} users -")
      [
        "bun"
        "dart"
        "go"
        "pnpm"
      ];
}
