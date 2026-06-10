{
  config,
  host,
  lib,
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
    directories = entry.directories;
    files = entry.files;
    users.${host.username} = {
      directories = entry.userDirectories;
      files = entry.userFiles;
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
                type = types.listOf types.str;
                default = [ ];
                description = "Directories to persist.";
              };

              files = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Files to persist.";
              };

              userDirectories = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "User directories to persist.";
              };

              userFiles = mkOption {
                type = types.listOf types.str;
                default = [ ];
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

        if [[ -e /btrfs_tmp/root ]]; then
          mkdir -p /btrfs_tmp/old_roots
          timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
          mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
        fi

        # delete roots older than keepDays
        for i in $(find /btrfs_tmp/old_roots/ -mindepth 1 -maxdepth 1 -mtime +${toString cfg.settings.wipeOnBoot.keepDays}); do
          btrfs subvolume delete -R "$i"
        done

        btrfs subvolume create /btrfs_tmp/root
        umount /btrfs_tmp
      '';
    };
  };
}
