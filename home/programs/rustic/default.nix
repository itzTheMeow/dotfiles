{
  pkgs,
  xelib,
  hostname,
  ...
}:
let
  logFileLocation = "/tmp/rustic.log";
  pCloudPath = # pCloud Drive path changes per system
    if pkgs.stdenv.isDarwin then
      "/Users/meow/pCloud Drive"
    else if hostname == "laptop" then
      "/home/pcloud"
    else
      "rclone:pcloud:";

  # bash commands need to be run with a log file env variable
  mkBash = cmd: "bash -c 'LOG_FILE=${logFileLocation} ${cmd}'";
  # creates a hook shell script and points to its executable
  mkHook =
    name: "${pkgs.writeShellScriptBin name (builtins.readFile ./hooks/${name}.sh)}/bin/${name}";
  mkConfig =
    name: central: password: source:
    {
      before ? [ ], # additional run-before hooks to add
      finally ? [ ], # additional run-finally hooks to add
      as ? null, # add `as-path` to this value
      noxattrs ? false, # disable xattrs on the backup
      ...
    }:
    {
      "rustic/${name}.toml".source = xelib.toTOMLFile "${name}.toml" {
        global = {
          use-profiles = [ "default" ];
        };
        repository = {
          repository =
            if central then "${pCloudPath}/Misc/Backups/rustic" else "${pCloudPath}/Misc/Backups/${name}";
          password-command = "opunattended ${password}";
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
            run-finally = finally;
          };
        }
        // (if noxattrs then { set-xattrs = "no"; } else { });
      };
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
{
  xdg.configFile = {
    # default config for all hosts
    "rustic/default.toml".source = xelib.toTOMLFile "default.toml" {
      global = {
        log-file = logFileLocation;
      };
      backup.hooks = {
        run-before = [
          # clear log file before backup
          (mkBash "false > ${logFileLocation}")
        ];
        run-finally = [ (mkBash hookFinallyLogs) ];
      };
      webdav = {
        address = "localhost:18898";
        path-template = "[{hostname}]/[{label}]/{time}";
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
          run-finally = [ "${hookFinallyUnmount} /mnt/pcloud" ];
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
  }
  // mkConfig "meow-pc" true "op://Private/6z2tlumg4aiznrno7mnryjunsq/password" "/" { }
  // mkConfig "hyzenberg" false "op://Private/fxxd4a76am6kr6okubzdohp3nm/password" "/" { }
  // mkConfig "macintosh" false "op://Private/o7hdiy7mwdifj2k7dmvq2qbl6a/password" "/" { }
  // mkConfig "ipad" false "op://Private/7kaur74rgd5da4kfcabgy3ahb4/password" "/mnt/ipad" {
    before = [ (mkHook "ipad-before") ];
    finally = [ "${hookFinallyUnmount} /mnt/ipad" ];
    as = "/";
    noxattrs = true;
  };

  # alias to run backblaze with env file
  home.shellAliases = {
    rustic-backblaze = ''eval $(op signin); op run --env-file="${backblazeENV}" --env-file="${glacierENV}" -- rustic-unstable -P backblaze'';
    rustic-glacier = ''eval $(op signin); op run --env-file="${glacierENV}" -- rustic -P glacier'';
  };
}
