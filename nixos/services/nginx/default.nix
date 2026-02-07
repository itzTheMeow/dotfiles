{ ... }:
{
  # enable and configure NGINX
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    clientMaxBodySize = "1g";
  };
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  # add nginx user to acme group so it can read challenge files
  users.users.nginx.extraGroups = [ "acme" ];
}
