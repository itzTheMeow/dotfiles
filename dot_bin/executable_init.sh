#!/bin/bash

###################
#     init.sh     #
#  by Meow  2025  #
###################
# Script to install tools on a new linux machine.

set -e
cd ~

PROMPT=(whiptail --separate-output --checklist "Choose packages to install" 20 78 10)
OPTIONS=(
	brew "Homebrew" ON
	deno "Deno" ON
	ntfy "NTFY CLI" ON
	nvm "Node Version Manager" ON
	omp "Oh My Posh" ON
	opcli "1Password CLI" ON
)

CHOICES=$("${PROMPT[@]}" "${OPTIONS[@]}" 2>&1 >/dev/tty)

if [ -z "$CHOICES" ]; then
	echo "No extras selected!"
fi

# Update/Install Packages
sudo apt-get update
sudo apt-get upgrade
sudo apt-get install -y bzip2 unzip wget
sudo apt-get autoremove -y

NCDU_VERSION="${NCDU_VERSION:-2.8}"
RESTIC_VERSION="${RESTIC_VERSION:-0.18.0}"

inst_brew() {
	# Install Homebrew
	echo "Installing Homebrew..."
	(
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	)
	# Has to be run outside of shell context.
	eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
}
inst_deno() {
	# Install Deno
	echo "Installing Deno..."
	(
		curl -fsSL https://deno.land/install.sh | sh
	)
}
inst_omp() {
	# Install Oh My Posh
	echo "Installing OMP..."
	(
		curl -s https://ohmyposh.dev/install.sh | bash -s
	)
}
inst_ntfy() {
	# Install ntfy CLI
	echo "Installing ntfy CLI"
	(
		sudo mkdir -p /etc/apt/keyrings
		curl -fsSL https://archive.heckel.io/apt/pubkey.txt | sudo gpg --dearmor -o /etc/apt/keyrings/archive.heckel.io.gpg
		sudo apt install apt-transport-https
		sudo sh -c "echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/archive.heckel.io.gpg] https://archive.heckel.io/apt debian main' \
      > /etc/apt/sources.list.d/archive.heckel.io.list"
		sudo apt update
		sudo apt -y install ntfy
	)
}
inst_nvm() {
	# Install NVM
	echo "Installing nvm..."
	(
		curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
		echo "Don't forget to install a version of node: nvm install [...]"
	)
}
inst_onepassword() {
	# Install 1Password CLI
	echo "Installing 1Password CLI..."
	(
		curl -sS https://downloads.1password.com/linux/keys/1password.asc |
			sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg &&
			echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" |
			sudo tee /etc/apt/sources.list.d/1password.list &&
			sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/ &&
			curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol |
			sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol &&
			sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22 &&
			curl -sS https://downloads.1password.com/linux/keys/1password.asc |
			sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg &&
			sudo apt update && sudo apt-get -y install 1password-cli
		echo "Version $(op --version) installed."
	)
}

# Install tools.
for choice in $CHOICES; do
	if [ "$choice" = "brew" ]; then
		inst_brew
	elif [ "$choice" = "deno" ]; then
		inst_deno
	elif [ "$choice" = "omp" ]; then
		inst_omp
	elif [ "$choice" = "ntfy" ]; then
		inst_ntfy
	elif [ "$choice" = "nvm" ]; then
		inst_nvm
	elif [ "$choice" = "opcli" ]; then
		inst_onepassword
	fi
done
