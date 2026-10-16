_: {
  programs.btop = {
    enable = true;
    settings = {
      update_ms = 1000;
      proc_aggregate = true;
      proc_sorting = "memory";
      proc_mem_mode = 2;
      proc_tree_auto_collapse = 1;
      temp_scale = "fahrenheit";
      proc_per_core = false;
      use_fstab = true;
      swap_upload_download = true;
      swap_disk = false;
    };
  };
  catppuccin.btop.enable = true;
}
