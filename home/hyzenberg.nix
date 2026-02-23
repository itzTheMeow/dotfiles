{
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
    packages = [
      xelpkgs.rustic-unstable
    ];

    file =
      { }
      # opunattended secrets
      // xelib.mkOPUnattendedSecret "op://Private/6z2tlumg4aiznrno7mnryjunsq/password";
  };
}
