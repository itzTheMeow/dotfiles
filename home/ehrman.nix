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
    sessionVariables = {
      NTFY_TAGS = hostname;
    };

    file =
      { }
      # secrets
      // xelib.mkSecretFile ".ssh/authorized_keys" "op://Private/vywbzem32jihjjvgldmz5tr5mu/public key"
      # opunattended secrets
      // xelib.mkOPUnattendedSecret "op://Private/6z2tlumg4aiznrno7mnryjunsq/password";
  };
}
