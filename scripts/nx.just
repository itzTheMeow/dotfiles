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
@update input:
    nix flake update --flake . {{ input }}

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

# manually reload kde settings from nix
@update-kde:
    # https://github.com/nix-community/plasma-manager/issues/577#issuecomment-3971533980
    rm /home/$USER/.local/share/plasma-manager/last_run_desktop_script_panels
    sh /home/$USER/.local/share/plasma-manager/scripts/2_desktop_script_panels.sh

# reload home-manager profile
@hm:
    home-manager switch --flake .#{{ hostname }}
