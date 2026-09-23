{
  config,
  lib,
  pkgs,
  xelib,
  ...
}:
let
  # config references
  app = config.apps.headscale;

  # hardcoded tailnet prefix (matches headscale default; not parameterised because
  # config.services.headscale.settings.ip_prefixes is freeform YAML)
  tailnetPrefix = "100.64.0.0/10";
  vpnPoolIp = "10.60.0.1";

  # paths / names
  stateDir = "/var/lib/ipad4-gateway";
  # world-traversable dir for the generated profile; kept out of stateDir so
  # nginx can read it without exposing the private keys/tailscale state
  publicDir = "/var/lib/ipad4-gateway-public";
  runDir = "/run/ipad4-gateway";
  strongswanContainer = "ipad4-gateway-strongswan";
  tailscaleContainer = "ipad4-gateway-tailscale";
  eapSecret = "ipad4-gateway";
  tailscaleImage = "tailscale/tailscale:v1.98.4";

  # derived values
  publicIp = xelib.dns.addr.ehrman;
  serverFqdn = app.domain;
  serverId = publicIp;
  baseDomain = config.services.headscale.settings.dns.base_domain;

  # DNS server handed to the iPad: the ipad4 node's own tailnet address, which
  # always exists inside the gateway netns (tailscale0). MagicDNS
  # (100.100.100.100) can't be used: it only answers via the local tailscaled
  # resolver, whose upstreams are empty inside this container (it can't watch
  # /etc/resolv.conf), so every query ends in SERVFAIL.
  gatewayDns = xelib.hosts.ipad4.ip;

  # local resolver for tunnel clients: answers tailnet names from generated
  # records and forwards everything else to public resolvers
  dnsRecords =
    # *.xela / *.xela.internal app records from headscale extra_records
    lib.filter (r: builtins.match "(.+\.)?xela(\.internal)?" r.name != null) (
      config.services.headscale.settings.dns.extra_records or [ ]
    )
    # + <host>.xela.internal peer records from the hosts table (those with an IP)
    ++ lib.concatLists (
      lib.mapAttrsToList (
        name: host:
        lib.optional (host ? ip) {
          name = "${name}.${baseDomain}";
          type = "A";
          value = host.ip;
        }
      ) xelib.hosts
    );

  dnsmasqConf = pkgs.writeText "ipad4-dnsmasq.conf" (
    lib.concatStringsSep "\n" (
      [
        "no-resolv"
        "no-hosts"
        # no interface= restriction on purpose: an SO_BINDTODEVICE socket only
        # accepts packets arriving on tailscale0, but the iPad's queries arrive
        # via XFRM decapsulation (iif=eth0), so they'd be rejected
        "listen-address=${gatewayDns}"
        "server=1.1.1.1"
        "server=9.9.9.9"
        "cache-size=1000"
      ]
      ++ map (r: "host-record=${r.name},${r.value}") (lib.filter (r: r.type == "A") dnsRecords)
    )
  );

  strongswan = pkgs.strongswan;

  # dnsmasq tries to resolve its --user name, which needs a passwd entry; the
  # minimal image has none
  etcPasswd = pkgs.writeTextDir "etc/passwd" "root:x:0:0:root:/root:/bin/sh\n";

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
        proposals = aes256-sha256-modp2048, aes256-sha256-ecp256, aes128-sha256-modp2048, aes128-sha1-modp1024, 3des-sha1-modp1024
        send_cert = always
        children {
          ipad4 {
            local_ts = ${tailnetPrefix}
            remote_ts = dynamic
            esp_proposals = aes256-sha256-modp2048, aes256-sha256-ecp256, aes128-sha256-modp2048, aes128-sha1, 3des-sha1
            start_action = none
            dpd_action = clear
          }
        }
      }
    }
    pools {
      ipad4 {
        addrs = ${vpnPoolIp}/32
        dns = ${gatewayDns}
      }
    }
  '';

  profileTemplate = pkgs.replaceVars ./profile.mobileconfig.in {
    SERVER_ADDRESS = publicIp;
    SERVER_ID = serverId;
    BASE_DOMAIN = baseDomain;
    DNS_SERVER = gatewayDns;
  };

  entrypoint = pkgs.writeShellScript "ipad4-gateway-entrypoint" ''
    set -euo pipefail

    export PATH=${
      lib.makeBinPath [
        strongswan
        pkgs.bash
        pkgs.coreutils
        pkgs.dnsmasq
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

    # charon's compiled defaults put its pidfile and vici/stroke sockets under
    # /var/run, which doesn't exist in the minimal image
    mkdir -p /var/run
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
        --dn "CN=ipad4-gateway.${baseDomain}" \
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

    # local DNS for tunnel clients: serves tailnet records generated above and
    # forwards everything else upstream
    cp ${dnsmasqConf} "$CONFIG"/dnsmasq.conf
    dnsmasq --conf-file="$CONFIG"/dnsmasq.conf --user=root

    CA_B64=$(base64 -w0 "$SSDIR"/x509ca/ca.crt)
    mkdir -p /public
    cp ${profileTemplate} /public/ipad4.mobileconfig
    sed -i "s/{{EAP_USERNAME}}/$EAP_USERNAME/g; s/{{CA_B64}}/$CA_B64/g" \
      /public/ipad4.mobileconfig
    chmod 644 /public/ipad4.mobileconfig

    "${strongswan}/libexec/ipsec/charon" &
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
        pkgs.dnsmasq
        pkgs.iproute2
        pkgs.iptables
        pkgs.gnused
        pkgs.gnugrep
        etcPasswd
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
      volumes = [
        "${stateDir}:/config"
        "${publicDir}:/public"
      ];
    };

    ${tailscaleContainer} = {
      image = "${tailscaleImage}";
      autoStart = true;
      dependsOn = [ strongswanContainer ];
      capabilities = {
        NET_ADMIN = true;
        NET_RAW = true;
      };
      privileged = true;
      networks = [ "container:${strongswanContainer}" ];
      environment = {
        TS_EXTRA_ARGS = "--login-server=${app.url} --accept-dns=true";
        TS_STATE_DIR = "/var/lib/tailscale";
        TS_HOSTNAME = "ipad4";
        # containerboot defaults to userspace networking, which has no
        # tailscale0 kernel interface to forward the VPN traffic into
        TS_USERSPACE = "false";
        TS_DEBUG_MTU = "1420";
      };
      environmentFiles = [ "${runDir}/ipad4.env" ];
      volumes = [ "${stateDir}/tailscale:/var/lib/tailscale" ];
    };
  };

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0700 root root - -"
    "d ${publicDir} 0755 root root - -"
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
      alias = "${publicDir}/ipad4.mobileconfig";
      extraConfig = "default_type application/x-apple-aspen-config;";
    };
  };
}
