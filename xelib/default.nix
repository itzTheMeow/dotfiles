pkgs: rec {
  # import globals
  globals = import ./globals.nix;

  # import hosts and ports
  inherit (import ./hosts.nix) hosts services;

  # makes a secret-injectable file with opinject
  mkSecretFile = name: content: {
    "${name}" = {
      text = content;
      force = true;
      opinject = true;
    };
  };
  # creates an opunattended cached secret
  mkOPUnattendedSecret =
    secretRef: mkSecretFile ".cache/opunattended/${builtins.hashString "sha256" secretRef}" secretRef;

  # optionally import a module if it exists
  optionalImport = path: if builtins.pathExists path then [ path ] else [ ];
  # convert string to title case
  toTitleCase =
    str:
    let
      firstChar = builtins.substring 0 1 str;
      rest = builtins.substring 1 (builtins.stringLength str) str;
    in
    (pkgs.lib.strings.toUpper firstChar) + rest;

  # convert an attr set to toml
  toTOMLFile = (pkgs.formats.toml { }).generate;
  # convert an attr set to env file
  toENVFile =
    name: data:
    pkgs.writeText name (
      builtins.concatStringsSep "\n" (map (k: ''${k}="${data.${k}}"'') (builtins.attrNames data))
    );

  # make an ssh config entry
  mkSSHConfig =
    machines:
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
          keyName = pkgs.lib.strings.stringAsChars (
            c: if builtins.match "[a-z0-9]" c != null then c else ""
          ) (pkgs.lib.strings.toLower name);
        in
        {
          inherit host keyName;
          localPubKeyPath = ".ssh/${keyName}.pub";
          pubKeyOpPath = publicKey;
          sshOptions = {
            identityFile = "~/.ssh/${keyName}.pub";
            identitiesOnly = true;
          }
          // extraOptions;

          desktopEntry = {
            type = "Application";
            name = "SSH ${name} (${host})";
            genericName = "Terminal emulator";
            comment = "Fast, feature-rich, GPU based terminal";
            exec = "kitty --session ./sessions/ssh-${keyName}.conf";
            icon = "kitty";
            categories = [
              "System"
              "TerminalEmulator"
            ];
          };
          sessionFile = {
            ".config/kitty/sessions/ssh-${keyName}.conf" = {
              text = ''
                cd ~
                focus
                focus_os_window
                os_window_state maximized
                launch --title "${name} (${host})" ${builtins.toString ../scripts/sshkitten.sh} ${args}
              '';
            };
          };
        };

      processedMachines = map mkMachine machines;
    in
    {
      files = builtins.foldl' (
        acc: machine: acc // (mkSecretFile machine.localPubKeyPath machine.pubKeyOpPath)
      ) { } processedMachines;

      blocks = builtins.foldl' (
        acc: machine: acc // { "${machine.host}" = machine.sshOptions; }
      ) { } processedMachines;

      kittySessions = builtins.foldl' (acc: machine: acc // machine.sessionFile) { } processedMachines;

      desktopEntries = builtins.foldl' (
        acc: machine: acc // { "ssh-${machine.keyName}" = machine.desktopEntry; }
      ) { } processedMachines;
    };

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

  # create an nginx reverse proxy with automatic SSL certificate management
  # domain: the domain name (e.g., "prowlarr.xela")
  # target: the backend URL (e.g., "http://127.0.0.1:9696")
  # options:
  #   - useLocalCA: whether to use local step-ca (default: true for .xela/.internal, false otherwise)
  #   - extraConfig: extra nginx location config
  #   - proxyWebsockets: enable websocket support (default: true)
  mkNginxProxy =
    domain: target:
    {
      useLocalCA ? (builtins.match ".+\\.(xela|internal)$" domain != null),
      extraConfig ? "",
      proxyWebsockets ? true,
    }:
    let
      caHost = hosts.${services.step-ca.host}.ip;
      caPort = services.step-ca.port;
    in
    {
      services.nginx.virtualHosts."${domain}" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = target;
          proxyWebsockets = proxyWebsockets;
          extraConfig = extraConfig;
        };
      };

      # For local CA domains, configure ACME to use step-ca
      security.acme.certs."${domain}" = {
        webroot = "/var/lib/acme/acme-challenge";
      }
      // (
        if useLocalCA then
          {
            server = "https://${caHost}:${toString caPort}/acme/acme/directory";
          }
        else
          { }
      );
    };
}
