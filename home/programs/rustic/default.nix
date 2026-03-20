{
  config,
  hostname,
  lib,
  pkgs-unstable,
  pkgs,
  xelib,
  ...
}:
let
  pCloudPath = # pCloud Drive path changes per system
    if pkgs.stdenv.isDarwin then "/Users/meow/pCloud Drive" else "rclone:pcloud:";

  # creates a hook shell script and points to its executable
  mkHook =
    name: "${pkgs.writeShellScriptBin name (builtins.readFile ./hooks/${name}.sh)}/bin/${name}";
  mkConfigOld =
    name: central: password: source:
    {
      before ? [ ], # additional run-before hooks to add
      finally ? [ ], # additional run-finally hooks to add
      as ? null, # add `as-path` to this value
      noxattrs ? false, # disable xattrs on the backup
      ...
    }:
    {
      "rustic/${name}_old.toml".source = xelib.toTOMLFile "${name}.toml" {
        global = {
          use-profiles = [ "default" ];
        };
        repository = {
          repository =
            if central then "${pCloudPath}/Misc/Backups/rustic" else "${pCloudPath}/Misc/Backups/${name}";
          password-command = if central then "cat /run/secrets/rustic_main" else "op read ${password}";
        };
        backup = {
          host = name;
          glob-files = [
            ./globs/default.glob
            ./globs/${name}.glob
          ];
          snapshots = [
            (
              {
                sources = [ source ];
              }
              // (if as != null then { as-path = as; } else { })
            )
          ];
          hooks = {
            run-before = before;
            run-finally = finally ++ [ "${hookFinallyLogs} ${name}" ];
          };
        }
        // (if noxattrs then { set-xattrs = "no"; } else { });
      };
    };

  mkConfig =
    name: password: source:
    {
      # additional config to be merged in
      additionalConfig ? { },
      # if the backup password should be saved in sops secrets
      hasAccess ? name == hostname,
      # backup from an rclone remote instead
      rclone ? null,
      ...
    }:
    let
      hasRclone = rclone != null;
    in
    {
      xdg.configFile."rustic/${name}.toml".source =
        xelib.toTOMLFile "${name}.toml" {
          global = {
            use-profiles = [ "default" ];
          };
          repository = {
            repository = "rclone:pcloud:/Misc/Backups/Rustic/${name}";
          }
          // (
            # use password-file if sops is active
            if hasAccess then
              { password-file = config.sops.secrets."rusticpw_${name}".path; }
            else
              { password-command = "op read ${password}"; }
          );
          backup = {
            host = name;
            glob-files = [
              ./globs/default.glob
              ./globs/${name}.glob
            ];
            snapshots = [
              (
                {
                  sources = [ source ];
                }
                // (lib.optionalAttrs hasRclone { as-path = "/"; })
              )
            ];
            hooks = {
              run-before = lib.optionals hasRclone [
                # ensure backup directory exists
                "mkdir -p ${source}"
                # unmount if needed
                "mountpoint -q ${source} && (fusermount -u ${source} || umount -l ${source})"
                # mount it
                "rclone mount ${rclone.remote} ${source} ${
                  lib.cli.toCommandLineShellGNU { } (
                    {
                      "daemon" = true;
                      "read-only" = true;
                    }
                    // rclone.args
                  )
                }"
              ];
              run-finally =
                (lib.optionals hasRclone [
                  "fusermount -u ${source} || umount -l ${source}"
                ])
                ++ [ "${hookFinallyLogs} ${name}" ];
            };
          };
        }
        // (lib.optionalAttrs hasRclone { set-xattrs = "no"; })
        // additionalConfig;

      home.shellAliases."rustic-${name}" =
        # if no access then keys will be derived from 1p
        (lib.optionalString (!hasAccess) "eval $(op signin); ") + "rustic -P ${name}";
    }
    // lib.optionalAttrs hasAccess {
      sops.secrets."rusticpw_${name}" = {
        sopsFile = ../../../${config.sops.opSecrets.rustic.path};
        key = name;
      };
      sops.opSecrets.rustic.keys.${name} = password;
    };

  # shell hooks
  hookFinallyLogs = mkHook "finally-logs";
  hookFinallyUnmount = mkHook "finally-unmount";

  backblazeENV = xelib.toENVFile "backblaze.env" {
    RS_B2_APPLICATION_KEY_ID = "op://Private/Backblaze/Application Keys/xela-codes-nas-id";
    RS_B2_APPLICATION_KEY = "op://Private/Backblaze/Application Keys/xela-codes-nas-applicationKey";
  };
  glacierENV = xelib.toENVFile "glacier.env" {
    RS_S3_ACCESS_KEY_ID = "op://Private/Amazon AWS/Application Keys/rustic";
    RS_S3_SECRET_ACCESS_KEY = "op://Private/Amazon AWS/Application Keys/rustic-key";
  };
in
lib.mkMerge [
  {
    home.packages = [ pkgs-unstable.rustic ];

    xdg.configFile = {
      # default config for all hosts
      "rustic/default.toml".source = xelib.toTOMLFile "default.toml" {
        webdav = {
          address = "localhost:18898";
          path-template = "[{hostname}]/{time}";
          time-template = "%Y-%m-%d_%H-%M-%S";
        };
      };
      # backblaze config
      "rustic/backblaze.toml".source = xelib.toTOMLFile "backblaze.toml" {
        global = {
          profile-substitute-env = true;
          use-profiles = [
            "default"
            (builtins.replaceStrings [ ".toml" ] [ "" ]
              "${xelib.toTOMLFile "backblaze_secrets.toml" {
                repository.options = {
                  application_key_id = "$RS_B2_APPLICATION_KEY_ID";
                  application_key = "$RS_B2_APPLICATION_KEY";
                };
              }}"
            )
          ];
        };
        repository = {
          repository = "opendal:b2";
          password-command = "op read op://Private/uysjliggwgwtjvqltlc222cagu/password";
          options = {
            bucket = "xela-codes-nas";
            bucket_id = "7040eaf12da21a4599af0417";
          };
        };
        backup = {
          host = "backblaze";
          glob-files = [
            ./globs/default.glob
          ];
          snapshots = [
            {
              sources = [ "/mnt/pcloud" ];
              as-path = "/";
            }
          ];
          hooks = {
            run-before = [ (mkHook "backblaze-before") ];
            run-finally = [
              "${hookFinallyUnmount} /mnt/pcloud"
              "${hookFinallyLogs} backblaze"
            ];
          };
          set-xattrs = "no";
        };
        copy = {
          targets = [ "glacier" ];
        };
      };
      # s3 glacier config
      "rustic/glacier.toml".source = xelib.toTOMLFile "glacier.toml" {
        global = {
          profile-substitute-env = true;
          use-profiles = [
            "default"
            (builtins.replaceStrings [ ".toml" ] [ "" ]
              "${xelib.toTOMLFile "glacier_secrets.toml" {
                repository.options = {
                  access_key_id = "$RS_S3_ACCESS_KEY_ID";
                  secret_access_key = "$RS_S3_SECRET_ACCESS_KEY";
                };
              }}"
            )
          ];
        };
        repository = {
          repository = "opendal:s3";
          repo-hot = "opendal:s3";
          password-command = "op read op://Private/qwz2w5hvt4jezzxhz4yastqyoe/password";
          options = {
            region = "us-east-2";
            root = "/";
          };
          options-cold = {
            bucket = "xela.codes-nas-cold";
            default_storage_class = "DEEP_ARCHIVE";
          };
          options-hot = {
            bucket = "xela.codes-nas-hot";
            default_storage_class = "STANDARD";
          };
        };
      };

      # temporary new machine
      "rustic/hyzen2.toml".source = xelib.toTOMLFile "hyzen2.toml" {
        global = {
          use-profiles = [ "default" ];
        };
        repository = {
          repository = "${pCloudPath}/Misc/Backups/rustic";
          password-command = "cat /run/secrets/rustic_main";
        };
        backup = {
          host = "hyzenberg";
          glob-files = [
            ./globs/default.glob
          ];
          snapshots = [
            {
              sources = [ "/" ];
            }
          ];
        };
      };
    }
    // mkConfigOld "hyzenberg" false "op://Private/fxxd4a76am6kr6okubzdohp3nm/password" "/" { };

    # alias to run backblaze with env file
    home.shellAliases = {
      rustic-backblaze = ''eval $(op signin); op run --env-file="${backblazeENV}" --env-file="${glacierENV}" -- rustic -P backblaze'';
      rustic-glacier = ''eval $(op signin); op run --env-file="${glacierENV}" -- rustic -P glacier'';
    };
  }

  (mkConfig "flynn" "op://Private/lfnh7z2hy74wewuw2tqdrxfhsq/password" "/" { })
  (mkConfig "hyzenberg" "op://Private/o3c3kzrri5dlyphag2smig3vpa/password" "/" { })
  (mkConfig "ehrman" "op://Private/4bs7irl4o4rkmzv7dp25zufsxu/password" "/" { })

  (mkConfig "ipad" "op://Private/7kaur74rgd5da4kfcabgy3ahb4/password" "/mnt/ipad" {
    rclone = {
      remote = "ipad:/";
      args = {
        "vfs-read-chunk-size" = "128M";
        "vfs-read-chunk-size-limit" = "off";
        "buffer-size" = "128M";
        "transfers" = "16";
        "checkers" = "16";
        "sftp-concurrency" = "16";
      };
    };
  })
]
