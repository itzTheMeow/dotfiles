{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    cargo
  ];
}
