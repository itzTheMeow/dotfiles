{
  dns,
  lib,
  ...
}:
{
  options.dnszones = {
    list = lib.mkOption {
      type = lib.types.listOf dns.lib.types.zone;
      default = [ ];
      description = "List of DNS zones to create";
    };
  };
}
