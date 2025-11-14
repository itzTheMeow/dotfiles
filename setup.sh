#!/bin/bash
# Setup script for this repo
# curl -sSL https://raw.githubusercontent.com/itzTheMeow/dotfiles-nix/refs/heads/master/setup.sh | bash

set -e

sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon

mkdir .config/nix
echo "experimental-features = nix-command flakes" >~/.config/nix/nix.conf

nix-channel --add https://github.com/nix-community/home-manager/archive/release-25.05.tar.gz home-manager
nix-channel --update

nix-shell '<home-manager>' -A install

. "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"

DOTFILES="$HOME/.dotfiles"

git clone https://github.com/itzTheMeow/dotfiles-nix.git "$DOTFILES"
cd "$DOTFILES"

echo "Setup complete. Run: home-manager switch --flake .#xxx"
