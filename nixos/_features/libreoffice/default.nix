{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    libreoffice-qt
    # for spellcheck/hyphenation
    hunspell
    hunspellDicts.en_US-large
    hyphenDicts.en_US
  ];
}
