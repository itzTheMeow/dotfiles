{
  config,
  host,
  hostname,
  lib,
  self,
  utils,
  xelib,
  ...
}:
let
  inherit (lib)
    listToAttrs
    mapAttrsToList
    mkIf
    mkOption
    nameValuePair
    types
    ;

  cfg = config.persist;
  usingSyncthing = cfg.sync != { };
  syncthingRelay = xelib.apps.syncthing-relay;

  syncthingGuiAddress = "127.0.0.1:8384";
  syncthingApiKey = builtins.substring 0 32 (
    builtins.hashString "sha256" "syncthing-tray-${toString self.lastModified}-${hostname}"
  );

  pathTreeType =
    let
      self = lib.types.nullOr (
        lib.types.oneOf [
          lib.types.str
          (lib.types.listOf (
            lib.types.oneOf [
              lib.types.str
              self
            ]
          ))
          (lib.types.attrsOf self)
        ]
      );
    in
    self;

  # clean path joiner
  joinPath =
    prefix: suffix:
    if prefix == "" then
      # root key should be an absolute path
      if lib.hasPrefix "/" suffix then suffix else "/${suffix}"
    else
    # make sure theres no double-slash path
    if lib.hasSuffix "/" prefix || lib.hasPrefix "/" suffix then
      "${prefix}${suffix}"
    else
      "${prefix}/${suffix}";

  flattenPathTree =
    prefix: value:
    # if value is null, return nothing
    if isNull value then
      [ ]
    # attrsets get flattened into paths at the current prefix
    else if builtins.isAttrs value then
      lib.concatLists (
        lib.mapAttrsToList (name: child: flattenPathTree (joinPath prefix name) child) value
      )
    # lists get expanded into paths
    else if builtins.isList value then
      # if a list is empty, then just use the prefix as the file
      if value == [ ] then
        # if at the root level, return nothing
        (if prefix == "" then [ ] else [ prefix ])
      else
        # expand the list at the current prefix
        lib.concatLists (map (item: flattenPathTree prefix item) value)
    else
      # strings get joined to the current prefix
      [ (joinPath prefix (toString value)) ];

  flattenPaths = value: flattenPathTree "" value;

  mkBtrfsMount = subvolume: compression: compressForce: {
    device = cfg.settings.device;
    fsType = "btrfs";
    options = [
      "subvol=${subvolume}"
      "compress${if compressForce then "-force" else ""}=zstd:${toString compression}"
      "noatime"
    ];
    neededForBoot = true;
  };
  mkMount = subvolume: entry: mkBtrfsMount subvolume entry.compression entry.compressForce;

  # sync directories that dont start with a `/` are relative to user
  mkSyncPath = path: if lib.hasPrefix "/" path then path else "/home/${host.username}/${path}";

  mkPersistence = entry: {
    hideMounts = true;
    allowTrash = true;
    directories = flattenPaths entry.directories;
    files = flattenPaths entry.files;
    users.${host.username} = {
      directories = flattenPaths entry.userDirectories;
      files = flattenPaths entry.userFiles;
    };
  };
in
{
  options.persist = {
    settings = mkOption {
      type = types.submodule (
        { ... }:
        {
          options = {
            device = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Block device used for persisted files. If unset the module will be disabled.";
            };

            dir = mkOption {
              type = types.str;
              default = "/z";
              description = "Base directory for persistent subvolumes.";
            };

            wipeOnBoot = mkOption {
              type = types.submodule (
                { ... }:
                {
                  options = {
                    enable = mkOption {
                      type = types.bool;
                      default = false;
                      description = "Whether to wipe and recreate the root subvolume on boot.";
                    };

                    keepDays = mkOption {
                      type = types.int;
                      default = 7;
                      description = "How many days of old root subvolumes to keep.";
                    };
                  };
                }
              );
              default = { };
              description = "Boot-time root wiping settings.";
            };
          };
        }
      );
      default = { };
      description = "Global persistence settings.";
    };

    ed = mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              path = mkOption {
                type = types.str;
                readOnly = true;
                default = "${cfg.settings.dir}/${name}";
                description = "Persistent storage path for this entry.";
              };

              directories = mkOption {
                type = pathTreeType;
                default = null;
                description = "Directories to persist.";
              };

              files = mkOption {
                type = pathTreeType;
                default = null;
                description = "Files to persist.";
              };

              userDirectories = mkOption {
                type = pathTreeType;
                default = null;
                description = "User directories to persist.";
              };

              userFiles = mkOption {
                type = pathTreeType;
                default = null;
                description = "User files to persist.";
              };

              compression = mkOption {
                type = types.int;
                default = 3;
                description = "Btrfs zstd compression level for this subvolume.";
              };

              compressForce = mkOption {
                type = types.bool;
                default = false;
                description = "Whether to use compress-force instead of compress.";
              };
            };
          }
        )
      );
      default = { };
      description = "Persistent storage entries.";
    };

    sync = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Directories to be synced with syncthing. Automatically creates 'sync' as a persistent dir if enabled.
        Attr name is syncthing folder name, value is the path to sync.
        If the path starts with a /, it is absolute, otherwise it is relative to the user home directory.
      '';
    };
  };

  config = mkIf (cfg.settings.device != null) {
    boot.initrd.supportedFilesystems = [ "btrfs" ];

    environment.persistence = listToAttrs (
      mapAttrsToList (_: entry: nameValuePair entry.path (mkPersistence entry)) cfg.ed
    );

    # these volumes always should exist
    fileSystems = {
      "/" = mkBtrfsMount "root" 1 false;
      "/nix" = mkBtrfsMount "nix" 5 true;
    }
    # mount custom persistent btrfs volumes
    // listToAttrs (mapAttrsToList (name: entry: nameValuePair entry.path (mkMount name entry)) cfg.ed)
    # syncthing bind mounts for directories
    // lib.optionalAttrs usingSyncthing (
      listToAttrs (
        mapAttrsToList (
          name: value:
          nameValuePair (mkSyncPath value) {
            device = "${config.persist.ed.sync.path}/${name}";
            fsType = "none";
            options = [ "bind" ];
            depends = [ config.persist.ed.sync.path ];
          }
        ) cfg.sync
      )
    );

    boot.initrd.systemd.services.wipe-file-systems = mkIf cfg.settings.wipeOnBoot.enable {
      unitConfig.DefaultDependencies = false;
      serviceConfig.Type = "oneshot";
      wantedBy = [ "initrd.target" ];
      before = [ "sysroot.mount" ];

      requires = [ "${utils.escapeSystemdPath cfg.settings.device}.device" ];
      after = [
        "${utils.escapeSystemdPath cfg.settings.device}.device"
        "local-fs-pre.target"
      ];

      script = ''
        mkdir /btrfs_tmp
        mount ${cfg.settings.device} /btrfs_tmp
        mkdir -p /btrfs_tmp/old_roots

        # delete roots older than keepDays
        # do this before moving
        for i in $(find /btrfs_tmp/old_roots/ -mindepth 1 -maxdepth 1 -mtime +${toString cfg.settings.wipeOnBoot.keepDays}); do
          btrfs subvolume delete -R "$i"
        done

        if [[ -e /btrfs_tmp/root ]]; then
          timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
          mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
        fi

        btrfs subvolume create /btrfs_tmp/root
        umount /btrfs_tmp
      '';
    };

    # syncthing secrets
    sops = mkIf usingSyncthing {
      groups.syncthing =
        let
          s = value: {
            inherit value;
            owner = host.username;
          };
        in
        {
          cert = s "op://Private/Syncthing ${hostname}/cert";
          key = s "op://Private/Syncthing ${hostname}/key";
          password = s "op://Private/txjsx55u5llawardzjrgttafdi/password";
        };
    };
    # enable /z/sync but dont persist anything from it
    persist.ed.sync = mkIf usingSyncthing { };
    # make sure bind mounted directories exist on the persistent dir
    systemd.tmpfiles.rules = lib.mkIf usingSyncthing (
      map (name: "d ${config.persist.ed.sync.path}/${name} 0755 ${host.username} users -") (
        builtins.attrNames cfg.sync
      )
    );
    # set up local syncthing service, using home-manager bc its user-scoped
    home-manager.users.${host.username} = mkIf usingSyncthing {
      services.syncthing = {
        enable = true;
        tray.enable = true;
        guiAddress = syncthingGuiAddress;
        cert = config.sops.groupPaths.syncthing.cert;
        key = config.sops.groupPaths.syncthing.key;

        overrideDevices = true;
        overrideFolders = true;

        settings = lib.recursiveUpdate {
          gui.apiKey = syncthingApiKey;
          options.listenAddresses = [ "tcp://${host.ip}:${toString host.ports.syncthing}" ];
          # connect to the relay server
          devices.relay = {
            inherit (syncthingRelay.details) id;
            addresses = [ "tcp://${syncthingRelay.ip}:${toString syncthingRelay.details.syncPort}" ];
          };
          folders = lib.mapAttrs (name: _: {
            path = config.persist.ed.sync.path + "/" + name;
            devices = [
              {
                name = "relay";
                encryptionPasswordFile = config.sops.groupPaths.syncthing.password;
              }
            ];
            ignorePerms = false;
          }) cfg.sync;
        } syncthingRelay.details.settings;
      };

      # declarative syncthing-tray config so it auto-connects
      xdg.configFile."syncthingtray.ini".text = ''
        [General]
        v=2.1.0

        [tray]
        connections\size=1
        connections\1\label=Primary instance
        connections\1\syncthingUrl=http://${syncthingGuiAddress}
        connections\1\apiKey=${syncthingApiKey}
        connections\1\authEnabled=false
        connections\1\autoConnect=true
        connections\1\reconnectInterval=30000
        connections\1\requestTimeout=60000
        connections\1\longPollingTimeout=60000
        connections\1\trafficPollInterval=5000
        connections\1\devStatsPollInterval=60000
        connections\1\errorsPollInterval=30000
        connections\1\diskEventLimit=200
        connections\1\forceSuspend=false
        connections\1\pauseOnMetered=false
        connections\1\localPath=
        connections\1\httpsCertPath=
        connections\1\statusComputionFlags=127
        showTraffic=true
        showDownloads=false
        showTabTexts=true
        showStIcons=true
        windowType=0
        frameStyle=16
        tabPos=1
        defaultTab=0
        lastTab=0
        trayMenuSize=@Size(575 475)
        ignoreInavailabilityAfterStart=15
        notifyOnDisconnect=true
        notifyOnErrors=true
        notifyOnLauncherErrors=true
        notifyOnLocalSyncComplete=false
        notifyOnRemoteSyncComplete=false
        showSyncthingNotifications=true
        notifyOnNewDeviceConnects=false
        notifyOnNewDirectoryShared=false
        preferIconsFromTheme=false
        distinguishTrayIcons=false
        usePaletteForStatusIcons=false
        usePaletteForTrayIcons=false
        dbusNotifications=false
      '';

      systemd.user.services.syncthingtray = {
        Unit = {
          After = [ "syncthing-init.service" ];
          Requires = [ "syncthing-init.service" ];
        };
      };
    };
  };
}
