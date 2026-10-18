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
  runDir = "/run/ipad4-gateway";
  profilesDir = "${runDir}/profiles";
  vpnContainer = "ipad4-gateway-vpn";
  tailscaleContainer = "ipad4-gateway-tailscale";
  secretName = "ipad4-gateway";
  tailscaleImage = "tailscale/tailscale:v1.98.4";

  # derived values
  publicIp = xelib.dns.addr.ehrman;
  serverFqdn = app.domain;
  baseDomain = config.services.headscale.settings.dns.base_domain;
  serverCertCn = "ipad4-gateway.${baseDomain}";
  caCn = "xela iPad 4 Gateway CA";

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

  # libreswan compiles out DH2/modp1024 by default, but iOS 6 only negotiates
  # DH2 (confirmed from live connect logs), so a USE_DH2 rebuild is required
  libreswan = pkgs.libreswan.overrideAttrs (old: {
    makeFlags = old.makeFlags ++ [ "USE_DH2=true" ];
  });

  # dnsmasq tries to resolve its --user name, which needs a passwd entry; the
  # minimal image has none
  etcPasswd = pkgs.writeTextDir "etc/passwd" "root:x:0:0:root:/root:/bin/sh\n";

  # Why Cisco IPsec (IKEv1 XAUTH) and not IKEv2 or L2TP:
  # - the target iPad runs iOS 6-10; IKEv2 only exists from iOS 8 and would not
  #   serve iOS 6, and modern strongSwan has no IKEv1 at all, so this is a
  #   libreswan-based replacement
  # - L2TP was rejected because iOS's L2TP client cannot do split tunneling
  #   (no route push at all; "Send All Traffic" is all-or-nothing), while the
  #   Cisco client installs server-pushed split networks (CISCO_SPLIT_INCLUDE)
  # - PPTP was removed from iOS 10, so it can't serve both generations
  #
  # Two conns serve the same tunnel: PSK+XAUTH for iOS 6 (whose client has a
  # UDP-fragmentation bug that breaks cert-based handshakes), and certificate
  # machine auth for iOS 10 (VPN On-Demand is certificate-only per Apple).
  # Secrets (PSK line, xauth passwd file) are appended at runtime from sops env.
  #
  # Contingencies / watch-outs:
  # - iOS 6 only negotiates DH2/modp1024 (confirmed from live connect logs), so
  #   libreswan is rebuilt with USE_DH2=true above; the modp1024 proposals in
  #   ike= depend on that rebuild. DES-CBC offers from iOS 6 are simply not
  #   matched (DES is gone from libreswan entirely); AES/3DES over DH2 win.
  # - both conns match right=%any; pluto picks by the SA's auth method. If a
  #   client lands on the wrong conn, check `ipsec status`/the pluto log.
  # - iOS does not rekey IKEv1 reliably, hence rekey=no and equal SA lifetimes:
  #   the tunnel is dropped after 8h and the client reconnects via DPD.
  ipsecConf = pkgs.writeText "ipad4-ipsec.conf" ''
    # ikev1-policy: libreswan 5 drops IKEv1 by default; these conns are IKEv1
    config setup
      ikev1-policy=accept

    conn ipad4-psk
      keyexchange=ikev1
      authby=secret
      left=%defaultroute
      leftsubnet=${tailnetPrefix}
      right=%any
      rightaddresspool=${vpnPoolIp}
      leftxauthserver=yes
      rightxauthclient=yes
      leftmodecfgserver=yes
      rightmodecfgclient=yes
      modecfgpull=yes
      xauthby=file
      cisco-unity=yes
      cisco-split=yes
      # IKEv1 modecfg only pushes one search domain; iOS gets both from the
      # profile's DNS dict
      modecfgdomains=xela.internal
      modecfgdns=${gatewayDns}
      fragmentation=yes
      pfs=no
      rekey=no
      ikelifetime=8h
      keylife=8h
      # dpdaction was removed in libreswan 5: a dead peer always clears the SA
      dpddelay=30
      dpdtimeout=120
      ike=aes256-sha2-modp2048,aes256-sha1-modp2048,aes128-sha1-modp2048,aes128-sha1-modp1536,3des-sha1-modp1536,aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024
      esp=aes256-sha1,aes128-sha1,3des-sha1
      auto=add

    # xauthby=alwaysok is only acceptable with real machine auth (the cert):
    # iOS always runs the XAUTH round even for cert connections, and there is
    # no second secret to check here
    conn ipad4-cert
      keyexchange=ikev1
      authby=rsasig
      leftcert=ipad4-gateway
      leftsendcert=always
      left=%defaultroute
      leftsubnet=${tailnetPrefix}
      right=%any
      rightaddresspool=${vpnPoolIp}
      leftxauthserver=yes
      rightxauthclient=yes
      leftmodecfgserver=yes
      rightmodecfgclient=yes
      modecfgpull=yes
      xauthby=alwaysok
      cisco-unity=yes
      cisco-split=yes
      modecfgdomains=xela.internal
      modecfgdns=${gatewayDns}
      fragmentation=yes
      pfs=no
      rekey=no
      ikelifetime=8h
      keylife=8h
      dpddelay=30
      dpdtimeout=120
      ike=aes256-sha2-modp2048,aes256-sha1-modp2048,aes128-sha1-modp2048,aes128-sha1-modp1536,3des-sha1-modp1536,aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024
      esp=aes256-sha1,aes128-sha1,3des-sha1
      auto=add
  '';

  profileIos6 = pkgs.replaceVars ./profile.mobileconfig.in {
    SERVER_ADDRESS = publicIp;
    BASE_DOMAIN = baseDomain;
    DNS_SERVER = gatewayDns;
  };

  profileIos10 = pkgs.replaceVars ./profile-ios10.mobileconfig.in {
    SERVER_ADDRESS = publicIp;
    BASE_DOMAIN = baseDomain;
    DNS_SERVER = gatewayDns;
  };

  entrypoint = pkgs.writeShellScript "ipad4-gateway-entrypoint" ''
    set -euo pipefail

    export PATH=${
      lib.makeBinPath [
        libreswan
        pkgs.bash
        pkgs.coreutils
        pkgs.dnsmasq
        pkgs.gnugrep
        pkgs.gnused
        pkgs.iproute2
        pkgs.iptables
        pkgs.openssl
      ]
    }:$PATH

    CONFIG=/config
    export IPSEC_CONF=$CONFIG/ipsec.conf
    export IPSEC_CONFDDIR=$CONFIG/ipsec.d
    export IPSEC_NSSDIR=$CONFIG/nss
    export IPSEC_RUNDIR=/run/pluto

    mkdir -p /var/run /tmp "$IPSEC_RUNDIR" "$IPSEC_NSSDIR" \
      "$IPSEC_CONFDDIR"/private "$IPSEC_CONFDDIR"/certs
    # pluto's xauth file helper defaults to /etc/ipsec.d/passwd; --ipsecdir
    # below covers pluto itself, the symlink covers any compiled-in default
    ln -sfn "$IPSEC_CONFDDIR" /etc/ipsec.d

    if [ ! -f "$IPSEC_CONFDDIR"/private/ca.key.pem ]; then
      echo "generating CA, server and client certificates..."
      ipsec initnss
      openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 \
        -out "$IPSEC_CONFDDIR"/private/ca.key.pem
      openssl req -x509 -new -sha256 -days 3650 \
        -key "$IPSEC_CONFDDIR"/private/ca.key.pem \
        -subj "/CN=${caCn}" \
        -addext "basicConstraints=critical,CA:TRUE" \
        -addext "keyUsage=critical,keyCertSign,cRLSign" \
        -out "$IPSEC_CONFDDIR"/certs/ca.crt
      openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
        -out "$IPSEC_CONFDDIR"/private/server.key.pem
      openssl req -new -key "$IPSEC_CONFDDIR"/private/server.key.pem \
        -subj "/CN=${serverCertCn}" -out /tmp/server.csr
      printf '%s\n%s\n%s\n%s\n' \
        "basicConstraints=CA:FALSE" \
        "keyUsage=digitalSignature,keyEncipherment" \
        "extendedKeyUsage=serverAuth" \
        "subjectAltName=IP:${publicIp},DNS:${serverFqdn}" > /tmp/server.ext
      openssl x509 -req -sha256 -days 3650 -in /tmp/server.csr \
        -CA "$IPSEC_CONFDDIR"/certs/ca.crt \
        -CAkey "$IPSEC_CONFDDIR"/private/ca.key.pem \
        -CAcreateserial -extfile /tmp/server.ext \
        -out "$IPSEC_CONFDDIR"/certs/server.crt
      openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
        -out "$IPSEC_CONFDDIR"/private/client.key.pem
      openssl req -new -key "$IPSEC_CONFDDIR"/private/client.key.pem \
        -subj "/CN=ipad4" -out /tmp/client.csr
      printf '%s\n%s\n%s\n' \
        "basicConstraints=CA:FALSE" \
        "keyUsage=digitalSignature,keyEncipherment" \
        "extendedKeyUsage=clientAuth" > /tmp/client.ext
      openssl x509 -req -sha256 -days 3650 -in /tmp/client.csr \
        -CA "$IPSEC_CONFDDIR"/certs/ca.crt \
        -CAkey "$IPSEC_CONFDDIR"/private/ca.key.pem \
        -CAcreateserial -extfile /tmp/client.ext \
        -out "$IPSEC_CONFDDIR"/certs/client.crt
      # the server p12 is only a transport into the NSS db, so its password is
      # a throwaway; the client p12 stays passwordless for the iOS identity
      # payload (if an old iOS ever refuses the modern AES p12 format, regenerate
      # both with -legacy)
      openssl pkcs12 -export -name ipad4-gateway \
        -inkey "$IPSEC_CONFDDIR"/private/server.key.pem \
        -in "$IPSEC_CONFDDIR"/certs/server.crt \
        -certfile "$IPSEC_CONFDDIR"/certs/ca.crt \
        -passout pass:ipad4srvp12 -out /tmp/server.p12
      openssl pkcs12 -export -name ipad4 \
        -inkey "$IPSEC_CONFDDIR"/private/client.key.pem \
        -in "$IPSEC_CONFDDIR"/certs/client.crt \
        -certfile "$IPSEC_CONFDDIR"/certs/ca.crt \
        -passout pass: -out "$IPSEC_CONFDDIR"/private/ipad4-client.p12
      chmod 600 "$IPSEC_CONFDDIR"/private/*
      ipsec pk12util -i /tmp/server.p12 -W ipad4srvp12
      ipsec certutil -M -n "${caCn}" -t "CT,,"
    fi

    cp ${ipsecConf} "$IPSEC_CONF"
    printf ': PSK "%s"\n' "$IPSEC_PSK" > "$CONFIG"/ipsec.secrets
    printf '%s:%s:%s\n' \
      "$XAUTH_USERNAME" "$(openssl passwd -6 "$XAUTH_PASSWORD")" ipad4-psk \
      > "$IPSEC_CONFDDIR"/passwd

    iptables -t nat -C POSTROUTING -o tailscale0 -s ${vpnPoolIp} -j MASQUERADE 2>/dev/null \
      || iptables -t nat -A POSTROUTING -o tailscale0 -s ${vpnPoolIp} -j MASQUERADE
    iptables -t nat -C PREROUTING -i tailscale0 -p tcp -j DNAT --to-destination ${vpnPoolIp} 2>/dev/null \
      || iptables -t nat -A PREROUTING -i tailscale0 -p tcp -j DNAT --to-destination ${vpnPoolIp}
    iptables -C FORWARD -j ACCEPT 2>/dev/null || iptables -A FORWARD -j ACCEPT
    iptables -t mangle -C FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null \
      || iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

    # local DNS for tunnel clients: serves tailnet records generated above and
    # forwards everything else upstream; bind-dynamic because listen-address
    # (the ipad4 tailnet IP) only exists once the tailscale sidecar has joined
    cp ${dnsmasqConf} "$CONFIG"/dnsmasq.conf
    dnsmasq --conf-file="$CONFIG"/dnsmasq.conf --user=root --bind-dynamic

    CA_B64=$(base64 -w0 "$IPSEC_CONFDDIR"/certs/ca.crt)
    PSK_B64=$(printf '%s' "$IPSEC_PSK" | base64 -w0)
    P12_B64=$(base64 -w0 "$IPSEC_CONFDDIR"/private/ipad4-client.p12)
    esc() {
      printf '%s' "$1" \
        | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' \
              -e 's/[\\|]/\\&/g'
    }
    mkdir -p /public
    cp ${profileIos6} /public/ipad4-ios6.mobileconfig
    sed -i \
      -e "s|{{PSK_B64}}|$PSK_B64|g" \
      -e "s|{{XAUTH_USERNAME}}|$(esc "$XAUTH_USERNAME")|g" \
      -e "s|{{XAUTH_PASSWORD}}|$(esc "$XAUTH_PASSWORD")|g" \
      /public/ipad4-ios6.mobileconfig
    cp ${profileIos10} /public/ipad4-ios10.mobileconfig
    sed -i \
      -e "s|{{PSK_B64}}|$PSK_B64|g" \
      -e "s|{{XAUTH_USERNAME}}|$(esc "$XAUTH_USERNAME")|g" \
      -e "s|{{XAUTH_PASSWORD}}|$(esc "$XAUTH_PASSWORD")|g" \
      -e "s|{{CA_B64}}|$CA_B64|g" \
      -e "s|{{P12_B64}}|$P12_B64|g" \
      /public/ipad4-ios10.mobileconfig
    chmod 644 /public/ipad4-ios6.mobileconfig /public/ipad4-ios10.mobileconfig

    "${libreswan}/libexec/ipsec/pluto" --nofork \
      --config "$IPSEC_CONF" \
      --secretsfile "$CONFIG"/ipsec.secrets \
      --ipsecdir "$IPSEC_CONFDDIR" \
      --nssdir "$IPSEC_NSSDIR" \
      --rundir "$IPSEC_RUNDIR" \
      --logfile /dev/stderr &
    PLUTO_PID=$!
    for i in $(seq 1 30); do
      if [ -S "$IPSEC_RUNDIR"/pluto.ctl ]; then
        break
      fi
      sleep 1
    done
    for i in $(seq 1 10); do
      # bare addconn is a no-op in libreswan 5; --autoall loads the auto= conns
      if ${libreswan}/libexec/ipsec/addconn \
        --ctlsocket "$IPSEC_RUNDIR"/pluto.ctl \
        --config "$IPSEC_CONF" \
        --autoall; then
        break
      fi
      sleep 1
    done
    wait "$PLUTO_PID"
  '';

  vpnImage = pkgs.dockerTools.buildImage {
    name = "ipad4-gateway-vpn";
    tag = "latest";
    copyToRoot = pkgs.buildEnv {
      name = "ipad4-gateway-root";
      paths = [
        libreswan
        pkgs.bash
        pkgs.coreutils
        pkgs.dnsmasq
        pkgs.iproute2
        pkgs.iptables
        pkgs.openssl
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
    ${vpnContainer} = {
      image = "ipad4-gateway-vpn:latest";
      imageFile = vpnImage;
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
      environment.XAUTH_USERNAME = "ipad4";
      environmentFiles = [ config.sops.secrets.${secretName}.path ];
      volumes = [
        "${stateDir}:/config"
        "${profilesDir}:/public"
      ];
    };

    ${tailscaleContainer} = {
      image = "${tailscaleImage}";
      autoStart = true;
      dependsOn = [ vpnContainer ];
      capabilities = {
        NET_ADMIN = true;
        NET_RAW = true;
      };
      privileged = true;
      networks = [ "container:${vpnContainer}" ];
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
    "d ${profilesDir} 0700 root root - -"
    "d ${runDir} 0700 root root - -"
    #?INIT: paste a headscale pre-auth key here before first boot
    #? echo 'TS_AUTHKEY=<key>' > ${runDir}/ipad4.env
    "f+ ${runDir}/ipad4.env 0600 root root - TS_AUTHKEY="
  ];

  # both secrets live in the existing 1Password item: "password" (already
  # provisioned) is the XAUTH password, "psk" (added when converting to
  # IKEv1) is the IPsec pre-shared key
  sops.envFiles.${secretName} = {
    XAUTH_PASSWORD = "op://Private/gcphielng2sczc67xizuw3wlcm/password";
    IPSEC_PSK = "op://Private/gcphielng2sczc67xizuw3wlcm/psk";
  };

  networking.firewall.allowedUDPPorts = [
    500
    4500
  ];
}
