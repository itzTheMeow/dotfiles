# block outbound IPs to known viruses/scams
{ lib, ... }:
let
  blockedIPs = [
    "23.27.20.187" # scam payload
  ];
in
{
  networking.firewall = {
    extraCommands = lib.concatStringsSep "\n" (
      map (ip: "iptables -A OUTPUT -d ${ip} -j DROP") blockedIPs
    );
    extraStopCommands = lib.concatStringsSep "\n" (
      map (ip: "iptables -D OUTPUT -d ${ip} -j DROP || true") blockedIPs
    );
  };
}
