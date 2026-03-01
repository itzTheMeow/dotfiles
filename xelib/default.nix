pkgs:
let
  lib = pkgs.lib;
in
rec {
  # import globals
  globals = import ./globals.nix;

  # import hosts and ports
  inherit (import ./hosts.nix) hosts services trustedHosts;

  # optionally import a module if it exists
  optionalImport = path: if builtins.pathExists path then [ path ] else [ ];
  # convert string to title case
  toTitleCase =
    str:
    let
      firstChar = builtins.substring 0 1 str;
      rest = builtins.substring 1 (builtins.stringLength str) str;
    in
    (lib.strings.toUpper firstChar) + rest;

  # check if a domain is local (.xela or .internal)
  isLocalDomain = domain: builtins.match ".+\\.(xela|internal)$" domain != null;
  # map a list of services to a list of the hosts they run on
  mkServiceHosts = serviceNames: lib.lists.unique (map (name: services.${name}.host) serviceNames);

  # convert an attr set to yaml string
  toYAMLString = data: builtins.readFile (toYAMLFile "file.yaml" data).outPath;
  # convert an attr set to env string
  toENVString =
    data: builtins.concatStringsSep "\n" (map (k: ''${k}="${data.${k}}"'') (builtins.attrNames data));

  # convert an attr set to yaml
  toYAMLFile = (pkgs.formats.yaml { }).generate;
  # convert an attr set to toml
  toTOMLFile = (pkgs.formats.toml { }).generate;
  # convert an attr set to env file
  toENVFile = name: data: pkgs.writeText name (toENVString data);

  # make an ssh config entry
  mkSSHConfig =
    config: machines:
    let
      mkMachine =
        {
          host,
          publicKey,
          name ? host,
          args ? host,
          extraOptions ? { },
        }:
        let
          keyName = lib.strings.stringAsChars (c: if builtins.match "[a-z0-9]" c != null then c else "") (
            lib.strings.toLower name
          );
        in
        {
          # public key with SOPS
          sops.secrets."ssh_pub_${keyName}" = {
            sopsFile = ../${config.sops.opSecrets.ssh_pubkeys.path};
            key = keyName;
          };
          sops.opSecrets.ssh_pubkeys.keys.${keyName} = publicKey;
          # ssh match block
          programs.ssh.matchBlocks."${host}" = {
            identityFile = config.sops.secrets."ssh_pub_${keyName}".path;
            identitiesOnly = true;
          }
          // extraOptions;
          # desktop file
          xdg.desktopEntries."ssh-${keyName}" = {
            type = "Application";
            name = "SSH ${name} (${host})";
            genericName = "Terminal emulator";
            comment = "Fast, feature-rich, GPU based terminal";
            exec = "kitty --session ${pkgs.writeText "ssh-${keyName}.conf" ''
              cd ~
              focus
              focus_os_window
              os_window_state maximized
              launch --title "${name} (${host})" ${../scripts/sshkitten.sh} ${args}
            ''}";
            icon = "kitty";
            categories = [
              "System"
              "TerminalEmulator"
            ];
          };
        };
    in
    # merge all options together to return them
    lib.mkMerge (map mkMachine machines);

  # make a remoteview desktop file for dolphin
  mkRemoteView = name: address: {
    ".local/share/remoteview/${name}.desktop" = {
      text = ''
        [Desktop Entry]
        Charset=
        Icon=folder-remote
        Name=${name}
        Type=Link
        URL=${address}
      '';
    };
  };

  # create an rclone mount systemd service
  mkRcloneMount =
    {
      config,
      name,
      remote,
      mountPoint,
      description ? "Rclone mount for ${name}",
      extraArgs ? [
        "--allow-other"
      ],
    }:
    {
      "rclone-mount-${name}" = {
        description = description;
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        requires = [ "network-online.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${mountPoint}";
          ExecStart = "${pkgs.rclone}/bin/rclone mount \"${remote}\" \"${mountPoint}\" --config=${config} ${builtins.concatStringsSep " " extraArgs}";
          ExecStop = "/run/current-system/sw/bin/umount -l ${mountPoint}";
          Restart = "on-failure";
          RestartSec = "10s";
          Environment = [ "PATH=/run/wrappers/bin" ];
        };
      };
    };

  # create a custom domain with nginx
  mkNginxProxy =
    domain: target:
    {
      # if domain is .xela or .internal, then automatically use the local ca
      useLocalCA ? (isLocalDomain domain),
      extraConfig ? { },
      proxyWebsockets ? true,
      allowedHosts ? [ ],
    }:
    let
      acmeServerIP = hosts.${services.step-ca.host}.ip;
    in
    {
      services.nginx.virtualHosts."${domain}" = lib.mkMerge [
        {
          forceSSL = true;
          useACMEHost = domain;
          locations."/" = {
            proxyPass = target;
            inherit proxyWebsockets;
          }
          // (
            if useLocalCA then
              {
                extraConfig = ''
                  # local domains dont have a body size limit
                  client_max_body_size 0;

                  # allow trusted tailscale hosts
                  ${lib.concatMapStringsSep "\n" (h: "allow ${hosts.${h}.ip};") (
                    lib.lists.unique (allowedHosts ++ trustedHosts)
                  )}

                  # allow local ips
                  allow 127.0.0.1;
                  allow ::1;

                  # block all other traffic
                  deny all;
                '';
              }
            else
              { }
          );
        }
        extraConfig
      ];

      # create cert for this domain
      security.acme.certs."${domain}" =
        { }
        // (
          # use the custom ACME server
          if useLocalCA then
            {
              server = "https://${acmeServerIP}:${toString services.step-ca.port}/acme/acme/directory";
            }
          else
            { }
        );
    };
}
