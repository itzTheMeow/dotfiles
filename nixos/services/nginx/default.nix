{ ... }:
{
  # enable and configure NGINX
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    clientMaxBodySize = "1g";

    # default catch-all host for random requests
    virtualHosts."_" = {
      default = true;
      locations."/" = {
        return = "404 'NOT FOUND'";
        extraConfig = ''
          default_type text/plain;
        '';
      };
    };
  };
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  # add nginx user to acme group so it can read challenge files
  users.users.nginx.extraGroups = [ "acme" ];
}
