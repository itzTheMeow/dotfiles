{
  hostname,
  xelib,
  ...
}:
{
  imports = [
    ./common
    ./common/headless.nix
  ];

  home = {
    file =
      { }
      # opunattended secrets
      // xelib.mkOPUnattendedSecret "op://Private/6z2tlumg4aiznrno7mnryjunsq/password";
  };
}
