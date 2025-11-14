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
	nvm "Node Version Manager" ON
	omp "Oh My Posh" ON
	opcli "1Password CLI" ON
)

CHOICES=$("${PROMPT[@]}" "${OPTIONS[@]}" 2>&1 >/dev/tty)

if [ -z "$CHOICES" ]; then
	echo "No extras selected!"
fi

inst_brew() {
	# Install Homebrew
	echo "Installing Homebrew..."
	(
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	)
	# Has to be run outside of shell context.
	eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
}
inst_omp() {
	# Install Oh My Posh
	echo "Installing OMP..."
	(
		curl -s https://ohmyposh.dev/install.sh | bash -s
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
	elif [ "$choice" = "omp" ]; then
		inst_omp
	elif [ "$choice" = "nvm" ]; then
		inst_nvm
	elif [ "$choice" = "opcli" ]; then
		inst_onepassword
	fi
done
