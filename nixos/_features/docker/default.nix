{ ... }:
{
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    # enable ipv6 support
    daemon.settings = {
      ipv6 = true;
      ip6tables = true;
      # local subnet so we dont clobber the network
      fixed-cidr-v6 = "fd00:ffff::/80";
    };
  };
  # make oci-containers use docker
  virtualisation.oci-containers.backend = "docker";

  systemd.services.docker.after = [ "tailscale-online.service" ];
}
