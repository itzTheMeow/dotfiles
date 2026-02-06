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
hm)
	# prompt to sign into 1password first
	if command -v op &>/dev/null; then
		eval $(op signin)
	fi
	home-manager switch --flake ~/.dotfiles#$HOSTNAME
	;;
"")
	# prompt to sign into 1password first (only on headless machines)
	# ensure desktop app is not installed
	if command -v op &>/dev/null && ! command -v 1password &>/dev/null; then
		# sign into 1password, extracting the session variable and storing it in memory
		op signin -f | grep "export OP_SESSION_" | sed 's/^export //' | sudo tee /run/1password-session >/dev/null
		# fix file permissions
		sudo chmod 600 /run/1password-session
		# this will be loaded by the systemd unit
		# if the machine isnt headless, then 1password desktop will prompt for authorization
	else
		# if we arent fetching a token, create an empty file so the systemd service will still run
		touch /run/1password-session
	fi
	START_TIME=$(date "+%Y-%m-%d %H:%M:%S")
	# then rebuild the system
	sudo nixos-rebuild switch --flake ~/.dotfiles#$HOSTNAME
	# remove saved session token
	if [ -f /run/1password-session ]; then
		sudo rm -f /run/1password-session
	fi
	# show home-manager logs from this run
	journalctl -u "home-manager-$USER" --since "$START_TIME" --no-pager -o cat | sed -n '/^Starting Home Manager activation$/,/Deactivated successfully.$/p'
	;;
*)
	echo "Usage: nx [os/hm|clean|update|edit|pull|hash|optimize]"
	;;
esac
