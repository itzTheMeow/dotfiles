{
  hostname,
  lib,
  xelib,
  ...
}:
{
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    # enable ipv6 support
    daemon.settings = {
      ipv6 = true;
      ip6tables = true;
      fixed-cidr-v6 = "${lib.removeSuffix "1" xelib.dns.addr6.${hostname}}/64";
    };
  };
  # make oci-containers use docker
  virtualisation.oci-containers.backend = "docker";

  systemd.services.docker.after = [ "tailscale-online.service" ];
}
