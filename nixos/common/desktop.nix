# any device with a gui
{ ... }:
{
  services.xserver = {
    enable = true;
    # keyboard map
    xkb = {
      layout = "us";
      variant = "";
    };
  };
}
