{ ... }:
{
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  systemd.services.docker.after = [ "tailscale-online.service" ];
}
