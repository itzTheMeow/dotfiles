set shell := ["bash", "-c"]

hostname := env('HOSTNAME')

# rebuild the current system
@default:
    START_TIME=$(date "+%Y-%m-%d %H:%M:%S"); \
    sudo nixos-rebuild switch --flake .#{{ hostname }}; \
    journalctl -u "home-manager-{{ env('USER') }}" --since "$START_TIME" --no-pager -o cat | \
        sed -n '/^Starting Home Manager activation$/,/Deactivated successfully.$/p'

# show this help menu
@help:
    {{ just_executable() }} --justfile {{ justfile() }} --list

# clean up the nix store
@clean:
    nix-collect-garbage -d

# optimise the nix store
@optimize:
    nix store optimise

# update the flake lockfile
@update:
    nix flake update --flake .

# open dotfiles repo in vscode
@edit:
    code .

# pull latest changes from git
@pull:
    git pull

# sha256 hash a URL for nix
@hash url:
    nix hash convert --hash-algo sha256 "$(nix-prefetch-url {{ url }})"

# root login to a NixOS container
@container name:
    sudo nixos-container root-login {{ name }}

# reload home-manager profile
@hm:
    home-manager switch --flake .#{{ hostname }}
