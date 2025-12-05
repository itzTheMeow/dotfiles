{ ... }:
{
  programs.oh-my-posh = {
    enable = true;
    settings = builtins.fromJSON (builtins.readFile ./theme.omp.json);
  };
}
