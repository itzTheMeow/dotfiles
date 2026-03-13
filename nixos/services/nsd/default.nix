{
  config,
  hostname,
  lib,
  pkgs,
  self,
  xelib,
  ...
}:
let
  collectedZones = lib.foldl' (acc: host: acc // host.config.dnszones.list) { } (
    lib.attrValues self.nixosConfigurations
  );
  # merged list of zones with dnssec enabled
  dnssecZones = lib.flatten (
    map (host: host.config.dnszones.dnssecEnabled) (lib.attrValues self.nixosConfigurations)
  );
in
{
  environment.systemPackages = [ pkgs.nsd ];
  services.nsd = {
    enable = true;
    keys.nixos-master.keyFile = config.sops.secrets.nsd-nixos-master.path;
    nsid = "ascii_${hostname}";
    zones = lib.mapAttrs (
      name: zone:
      (
        if xelib.dns.Master == hostname then
          let
            childNodes = builtins.removeAttrs xelib.dns.addr [ xelib.dns.Master ];
            childNotifiers = map (ip: "${ip} nixos-master") (lib.attrValues childNodes);
          in
          {
            data = toString zone;
            dnssec = false; # TODO: fix bind somehow - lib.elem name dnssecZones;
            notify = childNotifiers;
            provideXFR = childNotifiers;
          }
        else
          let
            master = "${xelib.dns.addr.${xelib.dns.Master}} nixos-master";
          in
          {
            # non-master nodes get notifications from the master
            allowNotify = [ master ];
            requestXFR = [ master ];
          }
      )
    ) collectedZones;
  };

  # open ports
  networking.firewall.allowedTCPPorts = [ 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];

  # tsig key
  sops.secrets.nsd-nixos-master = {
    sopsFile = ../../../${config.sops.opSecrets.nsd-keys.path};
    key = "nixos-master";
    owner = "nsd";
    group = "nsd";
  };
  sops.opSecrets.nsd-keys.keys.nixos-master = "op://Private/varbqv6lwh75bxatyjh3i2gboe/credential";
}
