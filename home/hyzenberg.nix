{
  host,
  hostname,
  xelib,
  xelpkgs,
  ...
}:
{
  imports = [
    ./common
    ./common/headless.nix
  ];

  home = {
    username = host.username;
    homeDirectory = "/home/${host.username}";

    sessionVariables = {
      NTFY_TAGS = hostname;
    };

    packages = [
      xelpkgs.rustic-unstable
    ];

    file =
      { }
      # secrets
      // xelib.mkSecretFile ".ssh/authorized_keys" "op://Private/eka63wejfdkiypenxptm6xky54/public key";
    # opunattended secrets
    #// xelib.mkOPUnattendedSecret "op://Private/fxxd4a76am6kr6okubzdohp3nm/password";
  };
}
