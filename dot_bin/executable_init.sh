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
  # Brew has to be installed before dependencies.
  brew "Homebrew" ON

  ncdu "NCurses Disk Usage" ON
  ntfy "NTFY CLI [brew]" ON
  nvm "Node Version Manager" ON
  omp "Oh My Posh" ON
  opcli "1Password CLI" ON
  restic "Restic" ON
  speedtest "Speedtest CLI" ON
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
inst_ncdu() {
  # Install NCDU
  echo "Installing ncdu v$NCDU_VERSION..."
  (
    DIR="$(mktemp -d)"
    cd "$DIR"
    wget -O ncdu.tar.gz "https://dev.yorhel.nl/download/ncdu-${NCDU_VERSION}-linux-x86_64.tar.gz"
    tar -xf ncdu.tar.gz
    chmod +x ncdu
    sudo mv ncdu /usr/local/bin
    rm -rf "$DIR"
  )
}
inst_omp() {
  # Install Oh My Posh
  echo "Installing OMP..."
  (
    curl -s https://ohmyposh.dev/install.sh | bash -s
  )
}
inst_restic() {
  # Install Restic
  echo "Installing restic v$RESTIC_VERSION..."
  (
    DIR="$(mktemp -d)"
    cd "$DIR"
    wget -O restic.bz2 "https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_amd64.bz2"
    bunzip2 restic.bz2
    chmod +x restic
    sudo mv restic /usr/local/bin
    rm -rf "$DIR"
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
      sudo apt update && sudo apt install 1password-cli
    echo "Version $(op --version) installed."
  )
}
inst_speedtest() {
  # Install Speedtest CLI
  echo "Installing Speedtest CLI..."
  (
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
    sudo apt-get -y install speedtest
  )
}

# Install tools.
for choice in $CHOICES; do
  if [ "$choice" = "brew" ]; then
    inst_brew
  elif [ "$choice" = "ncdu" ]; then
    inst_ncdu
  elif [ "$choice" = "omp" ]; then
    inst_omp
  elif [ "$choice" = "restic" ]; then
    inst_restic
  elif [ "$choice" = "ntfy" ]; then
    brew install ntfy
  elif [ "$choice" = "nvm" ]; then
    inst_nvm
  elif [ "$choice" = "opcli" ]; then
    inst_onepassword
  elif [ "$choice" = "speedtest" ]; then
    inst_speedtest
  fi
done
