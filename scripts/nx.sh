#!/usr/bin/env bash
# Utility script for nix management.

case "$1" in
clean)
	nix-collect-garbage -d
	;;
optimize)
	nix store optimise
	;;
update)
	nix flake update --flake ~/.dotfiles
	;;
edit)
	code ~/.dotfiles
	;;
pull)
	cd ~/.dotfiles
	git pull
	;;
hash)
	nix hash convert --hash-algo sha256 "$(nix-prefetch-url "$2")"
	;;
"")
	# prompt to sign into 1password first
	eval $(op signin)
	if [ -f /etc/NIXOS ]; then
		sudo nixos-rebuild switch --flake ~/.dotfiles#$HOSTNAME
	else
		home-manager switch --flake ~/.dotfiles#$HOSTNAME
	fi
	;;
*)
	echo "Usage: nx [clean|update|edit|pull|hash|optimize]"
	;;
esac
