# Throwaway Debian VM for running AI coding-agent test harnesses in a disposable
# guest. Only the host workspace folder (shared over 9p) survives a session; the
# guest's home directory and anything installed in it are discarded with the
# per-session disk overlay.
{
  config,
  host,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.services.ai-test-vm;

  vm = import ./vm.nix {
    inherit pkgs;
    username = host.username;
    cores = cfg.cores;
    diskSize = cfg.diskSize;
    memorySize = cfg.memorySize;
    sshPort = cfg.sshPort;
    workspaceDir = cfg.workspaceDir;
  };
in
{
  options.services.ai-test-vm = {
    enable = mkEnableOption "the throwaway Debian VM for AI coding-agent test harnesses";

    workspaceDir = mkOption {
      type = types.str;
      default = "/home/${host.username}/ai-workspace";
      description = "Host folder shared into the guest as its workspace. This is the only thing that survives a session.";
    };

    memorySize = mkOption {
      type = types.ints.positive;
      default = 4096;
      description = "Guest RAM in MiB.";
    };

    cores = mkOption {
      type = types.ints.positive;
      default = 4;
      description = "Guest vCPUs.";
    };

    diskSize = mkOption {
      type = types.str;
      default = "16G";
      description = "Guest disk size. The base image is grown to this once, sessions are overlays on top of it.";
    };

    sshPort = mkOption {
      type = types.port;
      default = 2222;
      description = "Host port the guest's sshd is forwarded to, on 127.0.0.1 only.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ vm.script ];

    # the folder the 9p share exposes has to exist before qemu is started
    systemd.tmpfiles.rules = [ "d ${cfg.workspaceDir} 0755 ${host.username} users - -" ];

    # application menu entry that boots a session in a terminal
    home-manager.importUser = [
      (_hm: {
        xdg.desktopEntries.ai-test-vm = {
          name = "AI Test VM";
          comment = "Boot a throwaway Debian VM for AI coding-agent tests";
          exec = "${pkgs.kitty}/bin/kitty --title ai-test-vm ${vm.script}/bin/ai-test-vm run";
          icon = "virtual-machine";
          type = "Application";
          categories = [
            "Development"
            "System"
          ];
        };
      })
    ];
  };
}
