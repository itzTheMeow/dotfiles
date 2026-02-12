{ xelib, ... }:
{
  # write agent env file
  home.file = xelib.mkSecretFile ".local/share/beszel/env" (
    builtins.readFile xelib.toENVFile {
      KEY = "op://Private/xoznbnccpqcu2pbzonqxih2tba/username";
      TOKEN = "op://Private/xoznbnccpqcu2pbzonqxih2tba/password";
    }
  );
}
