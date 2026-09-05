# AGENTS.md

Guidance for AI agents working in this repository. This is a Nix flake-based
NixOS configuration for personal machines.

## Overview

- Flake: `/home/*/.dotfiles/flake.nix` (or wherever cloned). Pure flake, no flake-utils magic beyond `eachDefaultSystem`.
- Single repo manages: NixOS hosts, home-manager configs, custom packages (from upstream flakes), overlays, Go secret-generation tooling, and GitHub/Forgejo CI.
- Everything is declarative where possible; secrets come from 1Password via SOPS (not committed).

## Directory layout

- `flake.nix` — entry point. Defines inputs, `nixosConfigurations`, `homeConfigurations`, `packages`, and the `format` app.
- `nixos/<host>/` — per-host config. Auto-imports every `.nix` file and every subdirectory in the host dir (via `nixos/default.nix`). Also defines the `features.nix` list for that host.
- `nixos/common.nix` — shared config imported by every host.
- `nixos/_common/` — NixOS modules shared by all hosts (imported automatically; `*.hm.nix` files are excluded since those are home-manager modules).
- `nixos/_types/` — device-type configs (`console`, `desktop`, `external`, `headless`, `kde`). Imported based on `host.type` from the hosts table; nested types are all included (e.g. `["desktop" "kde"]`).
- `nixos/_features/<feature>/` — optional feature modules enabled per-host via `nixos/<host>/features.nix`. Only enabled features get imported. Feature dirs may hold extra files (e.g. `package.nix`, artifacts).
- `nixos/_features/gaming/hells-kitchen` etc. — some features are nested dirs.
- `home/<host>.nix` — home-manager config per host; `home/common/` — shared home-manager modules.
- `home/programs/` — reusable home-manager program configs.
- `xelib/` — repo "library": `hosts.nix` (host table with tailscale IPs, usernames, ports), `globals.nix` (global settings), `default.nix` (helper functions like `dns`, `apps`, `mkSSHConfig`), `opsecrets.nix` (SOPS opSecrets module).
- `modules/` — custom NixOS options: `apps`, `dnszones`, `home-manager`, `nginx`, `persist`, `sops`. Loaded via `umport` (nypkgs) in flake.nix.
- `overlays/` — custom package overlays, applied to nixpkgs.
- `patches/` — source patches for packages.
- `pkgs/` — custom packages (imported as `xelpkgs` in modules).
- `scripts/` — shell scripts used by the config.
- `go/sops-build-secrets/` — Go tool that reads 1Password URIs from the config and generates SOPS-encrypted secret files. Also `go/download-organizer/`.
- `sops/` — generated secret files (per-host), produced by the Go tool. Do not hand-edit; regenerate via the go tool.
- `local/` — machine-specific, non-committed-override configs (`nixos.nix`, `home-manager.nix`). Flags via `git update-index --skip-worktree`. Imported by `nixos/default.nix`/common config.
- `.forgejo/workflows/` and `.github/workflows/` — CI (formatting; building all hosts into a binary cache).

## Key mechanisms

- **Hosts table (`xelib/hosts.nix`)**: single source for per-host data: username, full name, tailscale `ip`, `type` (list of device types), accent color, ports, public-key URI, backup cadence. Access via `xelib.hosts.<hostname>`.
- **`apps` module (`modules/apps.nix`)**: define apps as attrsets (`apps.<name> = { port, domain, ... }`). Auto-wires nginx proxies and DNS zones, and it feeds the homepage. `xelib.apps` aggregates from all hosts.
- **`nginx` module (`modules/nginx.nix`)**: `nginx.proxy.<domain>` creates an nginx vhost (docs: `target`, `local`, `allowedHosts`, `anubis`, `oidcGroups`...). Non-local domains get ACME certs; `.xela`/`.internal` domains are treated as local (tailscale-only, self-signed/step-ca cert).
- **`persist` module (`modules/persist.nix`)**: declarative btrfs persistence/impermanence. `persist.ed.<name>` = subvolume to persist, `persist.sync` = syncthing dirs. Wipe-on-boot supported.
- **Features list**: `nixos/<host>/features.nix` returns a list of feature names; only those get imported from `nixos/_features/`.
- **SOPS secrets (`modules/sops.nix` + `xelib/opsecrets.nix`)**: two patterns —
  - `sops.envFiles.<name> = { KEY = "op://..." }` → a single dotenv secret file (`sops/<host>/<name>.env`), usable as `environmentFile`.
  - `sops.groups.<name>.<field> = "op://..."` (or `{ value = ...; ... }`) → individual secrets, resolves to `sops.groupPaths.<group>.<field>`. Access actual file via `config.sops.groupPaths.<group>.<field>` (placeholder via `groupPlaceholders`).
  - These are declared in modules/hosts; the Go tool reads the evaluated `opSecrets` and writes the SOPS files. After adding a new 1Password-backed secret, run the go tool to regenerate.
- **`xelpkgs`**: custom packages (from `pkgs/`) exposed to modules as `xelpkgs` (a specialArg). Individual packages also come out as flake `packages` via the `*.package.nix` convention (see below).
- **`package.nix` convention**: any directory anywhere under a host dir or `_features/` containing `*.package.nix` gets turned into a flake package. Naming: relative path joined with `-` (e.g. `_features/gaming/` → `gaming-<name>`).
- **`umport`**: loads all files in `modules/` as NixOS modules into every host.
- **specialArgs**: `extras` (in `mkNixosConfiguration`) gives modules `dns`, `home-manager`, `hostname`, `inputs`, `pkgs-unstable`, `self`, `system`, `xelib`, `xelpkgs`, plus `host` (= `xelib.hosts.<hostname>`).

## Conventions

- **Comment markers** (see `README.md`):
  - `#?INIT:` — something that must be run non-declaratively during machine setup; the `#?`-prefixed lines after it are the commands to run.
  - `TODO:pr` — waiting on a PR merge. `TODO:26.11` — waiting on next nixpkgs release (nixpkgs 26.11).
- Modules should follow the repo's `inherit` alphabetized style and use `lib`/`mkOption` for options.
- Prefer reusing the host table (`xelib.hosts`), `apps`, and the modules in `modules/` over re-declaring per-host configuration.
- Secrets: never put plaintext secret values in Nix files. Reference 1Password URIs and let SOPS/opSecrets handle them.

## Commands / workflow

- Build a host: `nixos-rebuild switch --flake .#<hostname>` (or via `nixosConfigurations`).
- Eval/config checks: `nix eval .#nixosConfigurations.<hostname>.config...`.
- Format the whole repo: `nix run .#format` (nixfmt for nix, gofmt for go, prettier for everything else). Also run periodically via Forgejo CI.
- Regenerate SOPS secrets: run the `go/sops-build-secrets` tool (requires 1Password desktop app / `OP_SHARED_LIBRARY`).
- CI: `.github/workflows/` builds every host toplevel on push/schedule and pushes to the binary cache (configured via `nixConfig`; see `nixConfig.extra-substituters`/keys). Forgejo workflow auto-commits formatting changes.

## Things to watch out for

- The flake tree only sees _tracked_ files. New modules (e.g. a new host dir or a new directory under `nixos/`) must be `git add`ed before evaluation will see them.
- `nixConfig.extra-substituters`/`keys` need `--accept-flake-config` to take effect in non-NixOS commands. CI relies on this too.
- Keep `nixConfig` in sync with the NixOS `nix.settings.substituters` on each host (both point to the binary cache).
- Some configs intentionally target the `nixos-unstable`/custom branches per-host (see the `pete` TODO in flake.nix) — don't assume all hosts use the same nixpkgs.
- `.gitignore`: exclude `result` symlinks and qcow2 images.
