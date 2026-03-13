{
  dns,
  lib,
  ...
}:
{
  options.dnszones = {
    list = lib.mkOption {
      type = lib.types.attrsOf dns.lib.types.zone;
      default = { };
      description = "List of DNS zones to create";
    };
    dnssecEnabled = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of zones to enable dnssec for";
    };
  };
}
