{ xelib, ... }:
{
  services.prowlarr = {
    enable = true;
    settings = {
      app = {
        instancename = "Prowlarr";
        theme = "dark";
      };
      auth.authenticationmethod = "external";
      server = {
        bindaddress = xelib.hosts.hyzenberg;
        port = xelib.ports.prowlarr;
        urlbase = "/prowlarr";
      };
    };
  };
}
