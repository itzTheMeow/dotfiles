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
        "/var/lib/bluetooth"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/var/lib/tailscale"
        "/var/log"
      ];
      files = [
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/machine-id"
      ];
    };

    home = {
      userDirectories = [
        xelib.locationDir
        ".config"
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
        "Desktop"
        "Documents"
        "Downloads"
        "JoplinBackup"
        "Music"
        "Pictures"
        "Videos"
      ];
      userFiles = [
        ".ssh/known_hosts"
        ".zsh_history"
        ".wakatime.cfg"
      ];
    };

    cache = {
      userDirectories = [
        ".local/share/Trash"
      ]
      ++ map (subDir: ".cache/${subDir}") [
        "chromium"
        "mozilla"
        "nix"
        "rustic"
        "typescript"
        "vscode-cpptools"
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
  };

  # make sure referenced directories exist
  systemd.tmpfiles.rules =
    map (dir: "d ${config.persist.ed.cache.path}/${dir} 0755 ${host.username} users -")
      [
        "bun"
        "dart"
        "go"
      ];
}
