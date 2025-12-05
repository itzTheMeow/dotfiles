{ ... }:
{
  programs.btop = {
    enable = true;
    settings = {
      update_ms = 1000;
      proc_sorting = "memory";
      temp_scale = "fahrenheit";
      proc_per_core = false;
      use_fstab = true;
      swap_disk = false;
    };
  };
  catppuccin.btop.enable = true;
}
