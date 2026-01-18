{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/virtualisation/qemu-vm.nix"
  ];

  virtualisation = {
    cores = 6;
    memorySize = 8192;
    qemu.options = [
      "-vga virtio"
    ];
    graphics = true;
  };
}
