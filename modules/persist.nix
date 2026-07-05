{
  config,
  host,
  hostname,
  lib,
  xelib,
  utils,
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

    fileSystems = {
      "/" = mkBtrfsMount "root" 1 false;
      "/nix" = mkBtrfsMount "nix" 5 true;
    }
    // listToAttrs (mapAttrsToList (name: entry: nameValuePair entry.path (mkMount name entry)) cfg.ed);

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

    # syncthing stuff
    sops = mkIf usingSyncthing {
      secrets = {
        syncthing-cert = {
          sopsFile = config.sops.opSecrets.syncthing.fullPath;
          key = "cert";
          owner = host.username;
        };
        syncthing-key = {
          sopsFile = config.sops.opSecrets.syncthing.fullPath;
          key = "key";
          owner = host.username;
        };
        syncthing-encryption = {
          sopsFile = config.sops.opSecrets.syncthing.fullPath;
          key = "password";
          owner = host.username;
        };
      };
      opSecrets.syncthing.keys = {
        cert = "op://Private/Syncthing ${hostname}/cert";
        key = "op://Private/Syncthing ${hostname}/key";
        password = "op://Private/txjsx55u5llawardzjrgttafdi/password";
      };
    };
    persist.ed.sync = mkIf usingSyncthing {
      # directories that dont start with a `/` are relative to user
      directories = lib.filter (v: lib.hasPrefix "/" v) (lib.attrValues cfg.sync);
      userDirectories = lib.filter (v: !(lib.hasPrefix "/" v)) (lib.attrValues cfg.sync);
    };
    home-manager.users.${host.username}.services.syncthing = mkIf usingSyncthing {
      enable = true;
      tray.enable = true;
      cert = config.sops.secrets.syncthing-cert.path;
      key = config.sops.secrets.syncthing-key.path;

      overrideDevices = true;
      overrideFolders = true;

      settings = lib.recursiveUpdate {
        options = {
          listenAddresses = [ "tcp://${host.ip}:${toString host.ports.syncthing}" ];
        };
        devices.relay = {
          inherit (syncthingRelay.details) id;
          addresses = [ "tcp://${syncthingRelay.ip}:${toString syncthingRelay.details.syncPort}" ];
        };
        folders = lib.mapAttrs (
          name: value:
          let
            # append home directory to non-absolute paths
            path = if lib.hasPrefix "/" value then value else "/home/${host.username}/${value}";
          in
          {
            path = config.persist.ed.sync.path + path;
            devices = [
              {
                name = "relay";
                encryptionPasswordFile = config.sops.secrets.syncthing-encryption.path;
              }
            ];
          }
        ) cfg.sync;
      } syncthingRelay.details.settings;
    };
  };
}
