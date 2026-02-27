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
container)
	sudo nixos-container root-login "$2"
	;;
hm)
	home-manager switch --flake ~/.dotfiles#$HOSTNAME
	;;
"")
	START_TIME=$(date "+%Y-%m-%d %H:%M:%S")
	# then rebuild the system
	sudo nixos-rebuild switch --flake ~/.dotfiles#$HOSTNAME
	# show home-manager logs from this run
	journalctl -u "home-manager-$USER" --since "$START_TIME" --no-pager -o cat | sed -n '/^Starting Home Manager activation$/,/Deactivated successfully.$/p'
	;;
*)
	echo "Usage: nx [os/hm|clean|update|edit|pull|hash|optimize|container]"
	;;
esac
