{
  hostname,
  xelib,
  ...
}:
{
  imports = [
    ./common
    ./common/headless.nix

    ./programs/beszel-agent
  ];

  home = {
    file =
      { }
      # opunattended secrets
      // xelib.mkOPUnattendedSecret "op://Private/6z2tlumg4aiznrno7mnryjunsq/password";
  };
}
