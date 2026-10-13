# dotfiles-nix

A lot of stuff was inspired from [AlexNabokikh's Nix Config](https://github.com/AlexNabokikh/nix-config).

### Comment Meaning

- `?INIT:` - Something that must be run non-declaratively when the machine is set up.
- `TODO:pr` - Waiting on a PR to merge.
- `TODO:26.11` - Waiting on next nixpkgs release.

### Machine setup

- `#?INIT:` place the nvstly deploy key (only until the first switch deploys
  it via sops; see `_common/git.nix`; item already lives in 1Password as
  `op://NVSTly/yrzxyhogbfzbaasgginj4j6ria/private key`, public half registered
  as a read-only deploy key on nvstly/dotfiles):
  - `#? op read "op://NVSTly/yrzxyhogbfzbaasgginj4j6ria/private key" > ~/.ssh/nvstly_deploy && chmod 600 ~/.ssh/nvstly_deploy`
  - `#? printf 'Host nvstly-dotfiles\n  HostName github.com\n  User git\n  HostKeyAlias github.com\n  IdentityFile ~/.ssh/nvstly_deploy\n  IdentitiesOnly yes\n  StrictHostKeyChecking accept-new\n' >> ~/.ssh/config`
  - `#? run: go run ./go/sops-build-secrets` (regenerates `sops/` for the new key)
