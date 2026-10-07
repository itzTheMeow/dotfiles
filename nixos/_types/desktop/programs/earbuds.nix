{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    galaxy-buds-client
    librepods
  ];
}
