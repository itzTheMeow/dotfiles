#!/bin/bash
# Setup script for this repo
# curl -sSL https://raw.githubusercontent.com/itzTheMeow/dotfiles-nix/refs/heads/master/setup.sh | bash

set -e

echo "Installing nix..."
sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon

echo "Enabling flakes..."
mkdir .config/nix
echo "experimental-features = nix-command flakes" >~/.config/nix/nix.conf

echo "Cloning dotfiles..."
DOTFILES="$HOME/.dotfiles"
git clone https://github.com/itzTheMeow/dotfiles-nix.git "$DOTFILES"
cd "$DOTFILES"

echo "Setup complete, entering home-manager shell. Run:
home-manager switch --flake ~/.dotfiles#xxx"
source /etc/profile.d/nix.sh
nix shell nixpkgs#home-manager
