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
  restic "Restic" ON
)

CHOICES=$("${PROMPT[@]}" "${OPTIONS[@]}" 2>&1 >/dev/tty)

if [ -z "$CHOICES" ]; then
  echo "No extras selected!"
fi

# Update Packages
sudo apt-get update
sudo apt upgrade
sudo apt install wget

NCDU_VERSION="${NCDU_VERSION:-2.8}"
RESTIC_VERSION="${RESTIC_VERSION:-0.18.0}"

inst_brew() {
  # Install Homebrew
  echo "Installing Homebrew..."
  (
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  )
}
inst_ncdu() {
  # Install NCDU
  echo "Installing ncdu v$NCDU_VERSION..."
  (
    DIR="$(mktemp -d)"
    cd "$DIR"
    wget -O ncdu.tar.gz "https://dev.yorhel.nl/download/ncdu-${NCDU_VERSION}-linux-x86_64.tar.gz"
    tar -xf ncdu.tar.gz
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
    if ! command -v bunzip2 &>/dev/null; then
      echo "Couldn't find bzip2, installing..."
      sudo apt-get install -y bzip2 >/dev/null
    fi
    DIR="$(mktemp -d)"
    cd "$DIR"
    wget -O restic.bz2 "https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_linux_amd64.bz2"
    bunzip2 restic.bz2 # Decompress the .bz2 file
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
  fi
done
