#!/usr/bin/env bash
# Package the signed release payload for OpenWrt 24.10.5 x86/64.
set -euo pipefail
umask 022
: "${IMAGEBUILDER:?Set IMAGEBUILDER to the extracted OpenWrt 24.10.5 x86/64 ImageBuilder}"
: "${APK_KEYS_DIR:?Set APK_KEYS_DIR to a directory containing the release APK public key}"
: "${USIGN_KEY:?Set USIGN_KEY to the feed signing key (public key in USIGN_KEY.pub)}"
input=$(realpath "${1:?Supply the signed v2rayblisc APK}")
out=$(realpath -m "${2:-dist}")
builder=$(realpath "$IMAGEBUILDER")
key=$(realpath "$USIGN_KEY")
apk=${APK:-apk}
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
root=$stage/root
feed=$stage/feed
install -d -m755 "$root" "$feed"
"$apk" --keys-dir "$APK_KEYS_DIR" verify "$input"
"$apk" adbdump "$input" > "$stage/metadata"
grep -qx '  name: v2rayblisc' "$stage/metadata"
grep -qx '  arch: x86_64' "$stage/metadata"
version=$(sed -n 's/^  version: //p' "$stage/metadata")
[[ $version =~ ^[0-9][0-9A-Za-z.+~-]*-r[0-9]+$ ]]
"$apk" --keys-dir "$APK_KEYS_DIR" extract --destination "$root" "$input"
test -x "$root/usr/bin/v2raya"
test -x "$root/usr/bin/v2raya_core"
mkdir "$root/CONTROL"
cat > "$root/CONTROL/control" <<EOF
Package: v2rayblisc
Version: $version
Architecture: x86_64
Maintainer: wywywywycloud <100153948+wywywywycloud@users.noreply.github.com>
Section: net
Depends: ca-bundle, ip-full, kmod-nft-tproxy, v2ray-geoip, v2ray-geosite
Conflicts: v2raya
License: AGPL-3.0-only AND MPL-2.0
Source: https://github.com/wywywywycloud/v2rayBLISC
Installed-Size: 0
Description: v2rayA service, web interface and matching Xray-based core
EOF
echo /etc/config/v2raya > "$root/CONTROL/conffiles"
for hook in postinst prerm; do
    printf '#!/bin/sh\n[ -f "${IPKG_INSTROOT}/lib/functions.sh" ] || exit 0\n. "${IPKG_INSTROOT}/lib/functions.sh"\ndefault_%s "$0" "$@"\n' "$hook" > "$root/CONTROL/$hook"
    chmod 755 "$root/CONTROL/$hook"
done
"$builder/scripts/ipkg-build" "$root" "$feed"
cd "$feed"
MKHASH="$builder/staging_dir/host/bin/mkhash" "$builder/scripts/ipkg-make-index.sh" . > Packages
gzip -n -c Packages > Packages.gz
usign=$builder/staging_dir/host/bin/usign
"$usign" -S -m Packages -s "$key" -x Packages.sig
"$usign" -V -m Packages -p "$key.pub" -x Packages.sig
install -d "$out"
install -m644 ./*.ipk Packages Packages.gz Packages.sig "$out/"
install -m644 "$key.pub" "$out/v2rayblisc-opkg.pub"
