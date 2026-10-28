set shell := ["bash", "-c"]

hostname := env('HOSTNAME')

# rebuild the current system
@default:
    START_TIME=$(date "+%Y-%m-%d %H:%M:%S"); \
    sudo nixos-rebuild switch --flake .#{{ hostname }}; \
    journalctl -u "home-manager-{{ env('USER') }}" --since "$START_TIME" --no-pager -o cat | \
        sed -n '/^Starting Home Manager activation$/,/Deactivated successfully.$/p'

# rebuild the current system as a new boot menu entry
@boot:
    sudo nixos-rebuild boot --flake .#{{ hostname }}

# show this help menu
@help:
    {{ just_executable() }} --justfile {{ justfile() }} --list

# clean up the nix store
@clean:
    nix-collect-garbage -d
    sudo nix-collect-garbage -d

# optimise the nix store
@optimize:
    nix store optimise

# update the flake lockfile
@update input:
    nix flake update --flake . {{ input }}

# open dotfiles repo in zed
@edit:
    zeditor .

# pull latest changes from git
@pull:
    git pull

# diff the last 2 commits of the configuration
@diff configuration=hostname:
    nix-diff \
        $(nix eval --raw 'git+file://'$(pwd)'?rev='$(git rev-parse HEAD~1)'#nixosConfigurations.{{ configuration }}.config.system.build.toplevel.drvPath') \
        $(nix eval --raw 'git+file://'$(pwd)'?rev='$(git rev-parse HEAD)'#nixosConfigurations.{{ configuration }}.config.system.build.toplevel.drvPath')

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

# check used packages against upstream nixpkgs channels
@outdated *args:
    xela-outdated {{ args }}

# list /z files/dirs not linked by the current impermanence config
@orphaned:
    f=$(mktemp) && \
    nix eval --json '.#nixosConfigurations.{{ hostname }}.config.persist.linkPaths' > "$f" && \
    sudo bash scripts/orphaned.sh "{{ hostname }}" "$f"; \
    r=$?; rm -f "$f"; exit $r

# boot a host's config in a vm (nix store shared read-only over 9p, no disk image build;
# root disk persisted to ~/.local/share/nx/vms/<host>.qcow2)
@vm host='{{ hostname }}' *args:
    vmout=$(nix build --no-link --print-out-paths .#nixosConfigurations.{{ host }}.config.system.build.vm); \
    export NIX_DISK_IMAGE="$HOME/.local/state/nx/vms/{{ host }}.qcow2"; \
    mkdir -p "$(dirname "$NIX_DISK_IMAGE")"; \
    exec "$vmout/bin/run-{{ host }}-vm" {{ args }}
