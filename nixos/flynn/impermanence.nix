{ host, xelib, ... }:
let
  zCache = "/z/cache";
  subdir = baseDir: subDirs: map (subDir: "${baseDir}/${subDir}") subDirs;
in
{
  environment.persistence."/z/persist" = {
    hideMounts = true;
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
  # sops needs direct access to the key
  sops.age.sshKeyPaths = [
    "/z/persist/etc/ssh/ssh_host_ed25519_key"
  ];

  environment.persistence."/z/home" = {
    hideMounts = true;
    allowTrash = true;
    users.${host.username} = {
      directories = [
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
      files = [
        ".ssh/known_hosts"
        ".zsh_history"
        ".wakatime.cfg"
      ];
    };
  };

  # cache is for caches/stores/trash
  environment.persistence.${zCache} = {
    hideMounts = true;
    allowTrash = true;
    users.${host.username} = {
      directories = [
        ".local/share/Trash"
      ]
      ++ (subdir ".cache" [
        "chromium"
        "mozilla"
        "nix"
        "rustic"
        "typescript"
        "vscode-cpptools"
      ]);
    };
  };
  # set custom store paths for tools
  environment.variables = {
    # bun
    BUN_INSTALL = "${zCache}/bun"; # this isnt documented but its in the bun source code
    # dart
    PUB_CACHE = "${zCache}/dart";
    # go
    GOCACHE = "${zCache}/go/build";
    GOPATH = "${zCache}/go/path";
  };
  # make sure referenced directories exist
  systemd.tmpfiles.rules = map (dir: "d ${zCache}/${dir} 0755 ${host.username} users -") [
    "bun"
    "dart"
    "go"
  ];

  /*
    # hide /z
    system.activationScripts.hidePersistentMounts = ''
      echo -e "z" > /.hidden
    '';

    # weekly background TRIM
    services.fstrim.enable = true;
  */
}
