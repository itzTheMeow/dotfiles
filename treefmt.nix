{ ... }:
{
  projectRootFile = "flake.nix";

  programs.nixfmt.enable = true;
  programs.gofmt.enable = true;
  programs.prettier.enable = true;
  programs.shfmt = {
    enable = true;
    # match the repo's existing shell style: tabs, no `--simplify`
    indent_size = 0;
    simplify = false;
  };
}
