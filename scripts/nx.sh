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
os)
	# capture start time for journal filtering
	START_TIME=$(date "+%Y-%m-%d %H:%M:%S")
	# actually rebuild config
	sudo nixos-rebuild switch --flake ~/.dotfiles#$HOSTNAME
	# show home-manager logs from this run
	journalctl -u "home-manager-$USER" --since "$START_TIME" --no-pager -o cat | sed -n '/^Starting Home Manager activation$/,/^Deactivated successfully.$/p'
	;;
hm)
	# prompt to sign into 1password first
	if command -v op &>/dev/null; then
		eval $(op signin)
	fi
	home-manager switch --flake ~/.dotfiles#$HOSTNAME
	;;
"")
	# prompt to sign into 1password first
	if command -v op &>/dev/null; then
		eval $(op signin)
	fi
	# for nixos, rebuild the system
	if [ -f /etc/NIXOS ]; then
		sudo nixos-rebuild switch --flake ~/.dotfiles#$HOSTNAME
	fi
	# then run home manager
	home-manager switch --flake ~/.dotfiles#$HOSTNAME
	;;
*)
	echo "Usage: nx [os/hm|clean|update|edit|pull|hash|optimize]"
	;;
esac
