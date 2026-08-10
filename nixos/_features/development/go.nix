{
  config,
  host,
  pkgs,
  ...
}:
let
  dir = if (config.persist.ed ? cache) then "${config.persist.ed.cache.path}/go" else "/opt/go_cache";
in
{
  environment.systemPackages = with pkgs; [
    go
    gopls # LSP
    go-tools # assorted go tools
    tygo # generate ts types from go
  ];

  # set data paths to persisted directory
  environment.variables = {
    GOCACHE = "${dir}/build";
    GOPATH = "${dir}/path";
  };
  systemd.tmpfiles.rules = [
    "d ${dir} 0755 ${host.username} users -"
  ];

  programs.vscode.extensions = [
    pkgs.vscode-extensions.golang.go # Go
    pkgs.nix-vscode-extensions.vscode-marketplace.jinliming2.vscode-go-template # Go Template Support
  ];
}
