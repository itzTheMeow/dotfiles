# this is pretty much entirely vibed because i cba to do this NAT shit myself
{
  config,
  lib,
  pkgs,
  xelib,
  ...
}:
let
  publicIp = xelib.dns.addr.ehrman;
  serverFqdn = "pond.whenducksfly.com";
  serverId = publicIp;
  vpnPoolIp = "10.60.0.1";

  stateDir = "/var/lib/ipad4-gateway";
  runDir = "/run/ipad4-gateway";
  strongswanContainer = "ipad4-gateway-strongswan";
  tailscaleContainer = "ipad4-gateway-tailscale";
  eapSecret = "ipad4-gateway";

  strongswan = pkgs.strongswan;

  # swanctl.conf list values are comma-separated, not bracketed
  swanctlStatic = pkgs.writeText "ipad4-swanctl.conf" ''
    connections {
      ipad4 {
        version = 2
        local_addrs = %any
        remote_addrs = %any
        encap = yes
        local {
          auth = pubkey
          id = ${serverId}
          certs = ipad4-server.crt
        }
        remote {
          auth = eap-mschapv2
          eap_id = %any
        }
        pools = ipad4
        proposals = aes256-sha256-modp2048, aes256-sha256-ecp256, aes128-sha256-modp2048
        send_cert = always
        children {
          ipad4 {
            local_ts = 100.64.0.0/10
            remote_ts = dynamic
            esp_proposals = aes256-sha256-modp2048, aes256-sha256-ecp256, aes128-sha256-modp2048
            start_action = none
            dpd_action = clear
          }
        }
      }
    }
    pools {
      ipad4 {
        addrs = ${vpnPoolIp}/32
        dns = 100.100.100.100
      }
    }
  '';

  entrypoint = pkgs.writeShellScript "ipad4-gateway-entrypoint" ''
    set -euo pipefail

    export PATH=${
      lib.makeBinPath [
        strongswan
        pkgs.bash
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gnused
        pkgs.iproute2
        pkgs.iptables
      ]
    }:$PATH

    CONFIG=/config
    SSDIR=$CONFIG/swanctl
    export SWANCTL_DIR=$SSDIR
    export STRONGSWAN_CONF=$CONFIG/strongswan.conf

    mkdir -p "$SSDIR"/x509 "$SSDIR"/x509ca "$SSDIR"/x509crl "$SSDIR"/x509ocsp \
      "$SSDIR"/x509aa "$SSDIR"/x509ac "$SSDIR"/pubkey "$SSDIR"/private \
      "$SSDIR"/rsa "$SSDIR"/ecdsa "$SSDIR"/pkcs8 "$SSDIR"/pkcs12

    # an empty config makes charon load its full default plugin set
    : > "$STRONGSWAN_CONF"

    if [ ! -f "$SSDIR"/private/ipad4-server.key.pem ]; then
      echo "generating CA and server certificate..."
      pki --gen --type rsa --size 3072 --outform pem > "$SSDIR"/private/ca.key.pem
      pki --self --ca --lifetime 3650 --in "$SSDIR"/private/ca.key.pem \
        --dn "CN=xela iPad 4 Gateway CA" --outform pem > "$SSDIR"/x509ca/ca.crt
      pki --gen --type rsa --size 3072 --outform pem > "$SSDIR"/private/ipad4-server.key.pem
      pki --pub --in "$SSDIR"/private/ipad4-server.key.pem --outform pem > "$CONFIG"/server.pub.pem
      pki --issue --lifetime 3650 --cacert "$SSDIR"/x509ca/ca.crt --cakey "$SSDIR"/private/ca.key.pem \
        --in "$CONFIG"/server.pub.pem --type pub \
        --dn "CN=ipad4-gateway.xela.internal" \
        --san "${publicIp}" --san "${serverFqdn}" \
        --flag serverAuth --outform pem > "$SSDIR"/x509/ipad4-server.crt
      chmod 600 "$SSDIR"/private/*.pem
    fi

    cp ${swanctlStatic} "$SSDIR"/swanctl.conf
    cat >> "$SSDIR"/swanctl.conf <<EOF

    secrets {
      eap-$EAP_USERNAME {
        secret = "$EAP_PASSWORD"
      }
    }
    EOF

    iptables -t nat -C POSTROUTING -o tailscale0 -s ${vpnPoolIp} -j MASQUERADE 2>/dev/null \
      || iptables -t nat -A POSTROUTING -o tailscale0 -s ${vpnPoolIp} -j MASQUERADE
    iptables -t nat -C PREROUTING -i tailscale0 -p tcp -j DNAT --to-destination ${vpnPoolIp} 2>/dev/null \
      || iptables -t nat -A PREROUTING -i tailscale0 -p tcp -j DNAT --to-destination ${vpnPoolIp}
    iptables -C FORWARD -j ACCEPT 2>/dev/null || iptables -A FORWARD -j ACCEPT
    iptables -t mangle -C FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null \
      || iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

    CA_B64=$(base64 -w0 "$SSDIR"/x509ca/ca.crt)
    cat > "$CONFIG"/ipad4.mobileconfig <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>PayloadContent</key>
      <array>
        <dict>
          <key>PayloadType</key><string>com.apple.vpn.managed</string>
          <key>PayloadIdentifier</key><string>codes.xela.ipad4.vpn</string>
          <key>PayloadUUID</key><string>a1b2c3d4-0001-4000-8000-000000000001</string>
          <key>PayloadDisplayName</key><string>iPad 4 Tailnet VPN</string>
          <key>PayloadDescription</key><string>IKEv2 split tunnel to the xela tailnet</string>
          <key>PayloadVersion</key><integer>1</integer>
          <key>UserDefinedName</key><string>Tailnet (iPad 4)</string>
          <key>VPNType</key><string>IKEv2</string>
          <key>DNS</key>
          <dict>
            <key>ServerAddresses</key><array><string>100.100.100.100</string></array>
            <key>SearchDomains</key><array><string>xela.internal</string></array>
          </dict>
          <key>IKEv2</key>
          <dict>
            <key>RemoteAddress</key><string>${publicIp}</string>
            <key>RemoteIdentifier</key><string>${serverId}</string>
            <key>LocalIdentifier</key><string>ipad4</string>
            <key>AuthenticationMethod</key><string>None</string>
            <key>ExtendedAuthEnabled</key><integer>1</integer>
            <key>AuthName</key><string>$EAP_USERNAME</string>
            <key>ServerCertificateIssuerCommonName</key><string>xela iPad 4 Gateway CA</string>
            <key>ServerCertificateCommonName</key><string>ipad4-gateway.xela.internal</string>
            <key>DeadPeerDetectionRate</key><string>Medium</string>
          </dict>
        </dict>
        <dict>
          <key>PayloadType</key><string>com.apple.security.root</string>
          <key>PayloadIdentifier</key><string>codes.xela.ipad4.ca</string>
          <key>PayloadUUID</key><string>a1b2c3d4-0002-4000-8000-000000000002</string>
          <key>PayloadDisplayName</key><string>xela iPad 4 Gateway CA</string>
          <key>PayloadVersion</key><integer>1</integer>
          <key>PayloadCertificateFileName</key><string>ipad4-ca.crt</string>
          <key>PayloadContent</key><data>$CA_B64</data>
        </dict>
      </array>
      <key>PayloadType</key><string>Configuration</string>
      <key>PayloadIdentifier</key><string>codes.xela.ipad4</string>
      <key>PayloadUUID</key><string>a1b2c3d4-0000-4000-8000-000000000000</string>
      <key>PayloadDisplayName</key><string>iPad 4 Tailnet</string>
      <key>PayloadVersion</key><integer>1</integer>
    </dict>
    </plist>
    EOF

    charon &
    CHARON_PID=$!
    for i in $(seq 1 30); do
      if [ -S /var/run/charon.vici ]; then
        break
      fi
      sleep 1
    done
    for i in $(seq 1 10); do
      if swanctl --load-all --noprompt; then
        break
      fi
      sleep 1
    done
    wait "$CHARON_PID"
  '';

  strongswanImage = pkgs.dockerTools.buildImage {
    name = "ipad4-gateway-strongswan";
    tag = "latest";
    copyToRoot = pkgs.buildEnv {
      name = "ipad4-gateway-root";
      paths = [
        strongswan
        pkgs.bash
        pkgs.coreutils
        pkgs.iproute2
        pkgs.iptables
        pkgs.gnused
        pkgs.gnugrep
      ];
      pathsToLink = [
        "/bin"
        "/sbin"
        "/etc"
        "/lib"
        "/libexec"
        "/share"
      ];
    };
    config.Entrypoint = [ "${entrypoint}" ];
  };
in
{
  virtualisation.oci-containers.containers = {
    ${strongswanContainer} = {
      image = "ipad4-gateway-strongswan:latest";
      imageFile = strongswanImage;
      autoStart = true;
      capabilities.NET_ADMIN = true;
      extraOptions = [
        "--sysctl=net.ipv4.ip_forward=1"
        "--sysctl=net.ipv4.conf.all.rp_filter=0"
      ];
      ports = [
        "500:500/udp"
        "4500:4500/udp"
      ];
      environment.EAP_USERNAME = "ipad4";
      environmentFiles = [ config.sops.secrets.${eapSecret}.path ];
      volumes = [ "${stateDir}:/config" ];
    };

    ${tailscaleContainer} = {
      image = "tailscale/tailscale:v1.98.4";
      autoStart = true;
      dependsOn = [ strongswanContainer ];
      capabilities = {
        NET_ADMIN = true;
        NET_RAW = true;
      };
      privileged = true;
      networks = [ "container:${strongswanContainer}" ];
      environment = {
        TS_EXTRA_ARGS = "--login-server=${xelib.apps.headscale.url} --accept-dns=true";
        TS_STATE_DIR = "/var/lib/tailscale";
        TS_HOSTNAME = "ipad4";
      };
      environmentFiles = [ "${runDir}/ipad4.env" ];
      volumes = [ "${stateDir}/tailscale:/var/lib/tailscale" ];
    };
  };

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0700 root root - -"
    "d ${runDir} 0700 root root - -"
    #?INIT: paste a headscale pre-auth key here before first boot
    #? echo 'TS_AUTHKEY=<key>' > ${runDir}/ipad4.env
    "f+ ${runDir}/ipad4.env 0600 root root - TS_AUTHKEY="
  ];

  sops.envFiles.${eapSecret} = {
    EAP_PASSWORD = "op://Private/gcphielng2sczc67xizuw3wlcm/password";
  };

  networking.firewall.allowedUDPPorts = [
    500
    4500
  ];

  nginx.proxy.${serverFqdn}.extraConfig = _: {
    locations."= /ipad4.mobileconfig" = {
      alias = "${stateDir}/ipad4.mobileconfig";
      extraConfig = "default_type application/x-apple-aspen-config;";
    };
  };
}
