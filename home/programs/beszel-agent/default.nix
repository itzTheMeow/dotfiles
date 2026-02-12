{ xelib, ... }:
{
  # write agent env file
  home.file = xelib.mkSecretFile ".local/share/beszel/env" (
    xelib.toENVString {
      KEY = "op://Private/xoznbnccpqcu2pbzonqxih2tba/username";
      TOKEN = "op://Private/xoznbnccpqcu2pbzonqxih2tba/password";
    }
  );
}
