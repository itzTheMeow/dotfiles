{ xelib, ... }:
{
  # write agent env file
  home.file = xelib.mkSecretFile ".local/share/beszel/env" (
    xelib.toENVString {
      KEY = "op://Private/Beszel Hub Key/public key";
      TOKEN = "op://Private/Beszel Hub Universal Token/password";
    }
  );
}
