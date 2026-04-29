{
  dns,
  lib,
  self,
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

    collectedZones = lib.mkOption {
      type = lib.types.attrsOf dns.lib.types.zone;
      readOnly = true;
      description = "Collected/merged DNS zones from across hosts";
    };
  };

  config.dnszones.collectedZones =
    let
      # 1. Get the raw definitions from every host.
      # .definitions gives us the data BEFORE it's processed into the zone type.
      allDefinitions = lib.concatMap (host: host.options.dnszones.list.definitions) (
        lib.attrValues self.nixosConfigurations
      );
    in
    # 2. Merge all those raw definitions into one master set.
    # Because we are merging the *definitions*, Nix will handle the
    # merging of subdomains and records perfectly using the type logic.
    lib.mkMerge allDefinitions;
}
