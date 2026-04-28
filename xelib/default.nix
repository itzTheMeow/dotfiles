{
  hostname,
  pkgs,
  self,
  ...
}@inputs:
let
  inherit (pkgs) lib;
in
rec {
  # import globals
  globals = import ./globals.nix inputs;

  # import hosts and ports
  inherit (import ./hosts.nix) hosts trustedHosts;

  # location of the dotfiles repo
  location = "/home/${hosts.${hostname}.username}/.dotfiles";

  # aggregate apps from all config hosts
  apps = lib.foldAttrs lib.recursiveUpdate { } (
    map (host: self.nixosConfigurations.${host}.config.apps) (
      builtins.attrNames self.nixosConfigurations
    )
  );

  # main domain used for almost everything
  domain = "xela.codes";
  myDiscordID = "532045776122150913";

  mail = {
    domain = "mail.xela.codes";
  };

  dns = rec {
    _ns1 = "ns1.xela.codes";
    _ns2 = "ns2.xela.codes";
    Master = "ehrman"; # main ns1

    # IPs
    addr = {
      ehrman = "152.53.53.232"; # NS1
      hyzenberg = "152.53.171.231"; # NS2
    };

    # util functions
    fqdn = d: "${d}.";
    pointHost =
      hn: with inputs.dns.lib.combinators; {
        A = [ (a addr.${hn}) ];
        #TODO: AAAA = [];
      };

    # shorthand for github pages apex DNS
    githubPages = with inputs.dns.lib.combinators; {
      A = [
        (a "185.199.108.153")
        (a "185.199.109.153")
        (a "185.199.110.153")
        (a "185.199.111.153")
      ];
      AAAA = [
        (aaaa "2606:50c0:8000::153")
        (aaaa "2606:50c0:8001::153")
        (aaaa "2606:50c0:8002::153")
        (aaaa "2606:50c0:8003::153")
      ];
    };

    # utils for mailcow domains
    mailcow =
      {
        dkimKey,
        spfAllowed ? [
          "a"
          "mx"
        ],
      }:
      with inputs.dns.lib.combinators;
      {
        DKIM = [
          {
            selector = "dkim";
            p = dkimKey;
            k = "rsa";
            t = [ "s" ];
            s = [ "email" ];
          }
        ];
        DMARC = [ { p = "reject"; } ];
        MX = [ (mx.mx 10 (fqdn mail.domain)) ];
        SRV = [
          {
            service = "autodiscover";
            proto = "tcp";
            port = 443;
            target = fqdn mail.domain;
          }
        ];
        TXT = [ (spf.strict spfAllowed) ];
        subdomains.autoconfig.CNAME = [ (cname (fqdn mail.domain)) ];
        subdomains.autodiscover.CNAME = [ (cname (fqdn mail.domain)) ];
      };

    # prebuilt zone config
    SOA = {
      nameServer = fqdn _ns1;
      serial = self.lastModified; # auto-updating
      adminEmail = "dns@xela.codes";
    };
    NS = [
      (fqdn _ns1)
      (fqdn _ns2)
    ];
    TTL = 60 * 60; # 1hr
  };

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

  # convert an attr set to yaml string
  toYAMLString = data: builtins.readFile (toYAMLFile "file.yaml" data).outPath;
  # convert an attr set to env string
  toENVString =
    data: builtins.concatStringsSep "\n" (map (k: ''${k}="${data.${k}}"'') (builtins.attrNames data));
  # convert an attr set to `key: value` string
  toKVColonString =
    data:
    lib.generators.toKeyValue {
      mkKeyValue = lib.generators.mkKeyValueDefault { } ": ";
      listsAsDuplicateKeys = true;
    } data;

  # convert an attr set to yaml
  toYAMLFile = (pkgs.formats.yaml { }).generate;
  # convert an attr set to toml
  toTOMLFile = (pkgs.formats.toml { }).generate;
  # convert an attr set to env file
  toENVFile = name: data: pkgs.writeText name (toENVString data);
  # convert an attr set to `key: value` string
  toKVColonFile = name: data: pkgs.writeText name (toKVColonString data);

  injectCursorsFHS =
    pkg: # add the cursors to the FHS env
    (pkg.override {
      extraEnv = {
        XCURSOR_THEME = "${globals.cursors.name}";
        XCURSOR_SIZE = globals.cursors.size;
        XCURSOR_PATH = "/usr/share/icons:/run/current-system/sw/share/icons";
      };
    }).overrideAttrs
      (oldAttrs: {
        extraInstallCommands = (oldAttrs.extraInstallCommands or "") + ''
          mkdir -p $out/share/icons
          ln -snf ${globals.cursors.package}/share/icons/* $out/share/icons/
        '';
      });

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
            sopsFile = config.sops.opSecrets.ssh_pubkeys.fullPath;
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
}
