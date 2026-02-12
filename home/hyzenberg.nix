{
  hostname,
  xelib,
  xelpkgs,
  ...
}:
{
  imports = [
    ./common
    ./common/headless.nix

    ./programs/beszel-agent
  ];

  home = {
    sessionVariables = {
      NTFY_TAGS = hostname;
    };

    packages = [
      xelpkgs.rustic-unstable
    ];

    file =
      { }
      # secrets
      // xelib.mkSecretFile ".ssh/authorized_keys" "op://Private/eka63wejfdkiypenxptm6xky54/public key"
      # opunattended secrets
      // xelib.mkOPUnattendedSecret "op://Private/6z2tlumg4aiznrno7mnryjunsq/password";
  };
}
