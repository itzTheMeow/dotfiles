{ ... }:
{
  projectRootFile = "flake.nix";

  programs.nixfmt.enable = true;
  programs.gofmt.enable = true;
  programs.prettier.enable = true;
  programs.shfmt.enable = true;
}
