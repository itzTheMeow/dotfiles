#!/usr/bin/env bash
# Nightly check that the published DANE-TA (TLSA) pin for a mail domain still
# matches a certificate actually served on localhost:443. Alerts via ntfy on
# mismatch so an intermediate rotation (e.g. Let's Encrypt) can't break mail
# silently.
set -uo pipefail

domain="${1:?usage: check-dane <domain>}"

fail() {
	echo "DANE PIN MISMATCH for ${domain}: $*" >&2
	ntfy publish -t "DANE PIN MISMATCH: ${domain}" "$*" || true
	exit 1
}

# published record: "usage selector matching HASH" (dig may wrap the long hash)
read -r usage _ _ h1 h2 h3 <<<"$(timeout 5 dig +short "TLSA" "_25._tcp.${domain}" 2>/dev/null | head -n1)"
hash="${h1}${h2}${h3}"
[ -n "${hash:-}" ] || fail "no TLSA record at _25._tcp.${domain}"
[ "${usage}" = "2" ] || fail "TLSA usage changed to ${usage} (expected 2/dane-ta)"

# fetch the served chain and split it into individual certs
tmp="$(mktemp -d)" || exit 1
trap 'rm -rf "$tmp"' EXIT

timeout 15 openssl s_client -connect 127.0.0.1:443 -servername "${domain}" -showcerts </dev/null 2>/dev/null |
	awk -v dir="$tmp" '
    /BEGIN CERTIFICATE/ { n++; in_cert = 1 }
    in_cert { print > (dir "/cert-" n ".pem") }
    /END CERTIFICATE/ { in_cert = 0 }
  '

certs=("$tmp"/cert-*.pem)
[ -e "${certs[0]}" ] || fail "could not fetch certificate chain"
[ "${#certs[@]}" -gt 1 ] || fail "chain has only the leaf, no intermediate to pin"

# DANE-TA (usage 2) pin must match a cert in the chain past the leaf
match=0
i=0
for cert in "${certs[@]}"; do
	i=$((i + 1))
	[ "$i" -eq 1 ] && continue
	spki="$(openssl x509 -in "${cert}" -pubkey -noout 2>/dev/null | openssl pkey -pubin -outform DER 2>/dev/null | openssl dgst -sha256 2>/dev/null | awk -F'=' '{print $NF}' | tr -dc '[:alnum:]')"
	if [ -n "${spki}" ] && [ "${spki,,}" = "${hash,,}" ]; then
		match=1
		break
	fi
done

[ "$match" -eq 1 ] || fail "pinned SPKI ${hash} not found in served chain"
exit 0
