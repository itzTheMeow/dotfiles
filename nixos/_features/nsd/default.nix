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
  isMaster = xelib.dns.Master == hostname;

  # merged list of zones with dnssec enabled
  dnssecZones = lib.flatten (
    map (host: host.config.dnszones.dnssecEnabled) (lib.attrValues self.nixosConfigurations)
  );
in
{
  # replace the module with our patched one
  disabledModules = [ "services/networking/nsd.nix" ];
  imports = [ ./patched.nix ];

  environment.systemPackages = [ pkgs.nsd ];
  services.nsd = {
    enable = true;
    # listen on both ipv4 and ipv6
    interfaces = [
      "0.0.0.0"
      "::0"
    ];
    keys.nixos-master.keyFile = config.sops.secrets.nsd-nixos-master.path;
    nsid = "ascii_${hostname}";
    #remoteControl.enable = true;
    zones = lib.mapAttrs (
      name: zone:
      (
        if isMaster then
          let
            childNodes = builtins.removeAttrs xelib.dns.addr [ xelib.dns.Master ];
            childNotifiers = map (ip: "${ip} nixos-master") (lib.attrValues childNodes);
          in
          {
            data = toString zone;
            dnssec = lib.elem name dnssecZones;
            notify = childNotifiers;
            provideXFR = childNotifiers;
          }
        else
          let
            master = "${xelib.dns.addr.${xelib.dns.Master}} nixos-master";
          in
          {
            # non-master nodes get notifications from the master
            data = toString zone;
            allowNotify = [ master ];
            requestXFR = [ master ];
          }
      )
    ) config.dnszones.collectedZones;
  };

  # open ports
  networking.firewall.allowedTCPPorts = [ 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];

  # set up nameservers
  dnszones.list.${xelib.domain}.subdomains =
    with xelib.dns;
    lib.mkIf isMaster {
      ns1 = pointHost "ehrman";
      ns2 = pointHost "hyzenberg";
    };

  # tsig key
  sops.secrets.nsd-nixos-master = {
    sopsFile = config.sops.opSecrets.nsd-keys.fullPath;
    key = "nixos-master";
    owner = "nsd";
    group = "nsd";
  };
  sops.opSecrets.nsd-keys.keys.nixos-master = "op://Private/varbqv6lwh75bxatyjh3i2gboe/credential";
}
