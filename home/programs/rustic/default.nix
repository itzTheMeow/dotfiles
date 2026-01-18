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
in
{
  xdg.configFile = {
    # default config for all hosts
    "rustic/default.toml".source = xelib.toTOMLFile "default.toml" {
      global = {
        log-file = logFileLocation;
      };
      backup.hooks = {
        # clear log file before backup
        run-before = [
          (mkBash ''echo -n "" > ${logFileLocation}'')
        ];
        run-finally = [ (mkBash hookFinallyLogs) ];
      };
    };
    # backblaze config
    "rustic/backblaze.toml".source = xelib.toTOMLFile "backblaze.toml" {
      global = {
        use-profiles = [ "default" ];
      };
      repository = {
        repository = "opendal:b2";
        password-command = "op read op://Private/uysjliggwgwtjvqltlc222cagu/password";
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
    rustic-backblaze = ''eval $(op signin); op run --env-file="${./backblaze.env}" -- rustic-unstable -P backblaze'';
  };
}
