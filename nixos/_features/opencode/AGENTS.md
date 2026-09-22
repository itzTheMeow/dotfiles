# NixOS Global Rules

This agent is running on NixOS. The system uses flake-based configuration.

## NixOS/Flake Preferences

- **When discussing "nix" (package managers, tools, system configuration):** Prefer **flake-based** solutions (e.g., `nix develop`, `nix flake install`, `nix flake show`) over channel-based commands (e.g., `nix-channel`, `nix-env`)

- **System configuration:** All system configuration is stored in `~/.dotfiles` and managed via Nix flakes. This is a declarative, version-controlled system that gets deployed with `nixos-rebuild switch`

- **Package management:** Nixpkgs packages are accessed through flake inputs rather than relying on pre-built channels

## Development Workflow

- Check flake.lock for dependency versions after updates
- Prefer pure Nix expressions over shell scripts when possible
- Use `nix shell` for development environments

The nix store is at `/nix/store`. Use `nix eval` for configuration checks and `nix fmt` to format Nix code.
