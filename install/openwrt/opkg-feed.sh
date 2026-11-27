#!/usr/bin/env bash
# Package the signed release payload for the OpenWrt 24.10 opkg feed.
set -euo pipefail
umask 022
: "${IMAGEBUILDER:?Set IMAGEBUILDER to the extracted OpenWrt 24.10.5 ImageBuilder for the target}"
: "${APK_KEYS_DIR:?Set APK_KEYS_DIR to a directory containing the release APK public key}"
: "${USIGN_KEY:?Set USIGN_KEY to the feed signing key (public key in USIGN_KEY.pub)}"
input=$(realpath "${1:?Supply the signed v2rayblisc APK}")
here=$(cd "$(dirname "$0")" && pwd)
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
arch=$(sed -n 's/^  arch: //p' "$stage/metadata")
case "$arch" in
  x86_64|aarch64_generic|aarch64_cortex-a53|aarch64_cortex-a72|aarch64_cortex-a76) ;;
  *) echo "Unsupported OpenWrt architecture: $arch" >&2; exit 1 ;;
esac
version=$(sed -n 's/^  version: //p' "$stage/metadata")
[[ $version =~ ^[0-9][0-9A-Za-z.+~-]*-r[0-9]+$ ]]
"$apk" --keys-dir "$APK_KEYS_DIR" extract --destination "$root" "$input"
test -x "$root/usr/bin/v2raya"
test -x "$root/usr/bin/v2raya_core"
if [[ $arch = aarch64_* ]]; then
    # Leave room on Filogic NAND for both official geodata packages.
    for binary in "$root/usr/bin/v2raya" "$root/usr/bin/v2raya_core"; do
        readelf -h "$binary" | grep -q 'Machine:.*AArch64'
        # The 25.12 feed already contains packed ARM64 binaries.
        if ! upx -t "$binary" >/dev/null 2>&1; then
            upx --fast "$binary"
            upx -t "$binary"
        fi
    done
fi
mkdir "$root/CONTROL"
cat > "$root/CONTROL/control" <<EOF
Package: v2rayblisc
Version: $version
Architecture: $arch
Maintainer: wywywywycloud <100153948+wywywywycloud@users.noreply.github.com>
Section: net
Depends: ca-bundle, ip-full, kmod-nft-tproxy, v2ray-geoip, v2ray-geosite, luci-app-v2rayblisc
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
luci=$stage/luci-app-v2rayblisc
cp -R "$here/luci-app-v2rayblisc" "$luci"
echo "Version: $version" >> "$luci/CONTROL/control"
chmod 755 "$luci/CONTROL/postinst"
cp -p "$luci/CONTROL/postinst" "$luci/CONTROL/postrm"
"$builder/scripts/ipkg-build" "$luci" "$feed"
cd "$feed"
MKHASH="$builder/staging_dir/host/bin/mkhash" "$builder/scripts/ipkg-make-index.sh" . > Packages
gzip -n -c Packages > Packages.gz
usign=$builder/staging_dir/host/bin/usign
"$usign" -S -m Packages -s "$key" -x Packages.sig
"$usign" -V -m Packages -p "$key.pub" -x Packages.sig
install -d "$out"
install -m644 ./*.ipk Packages Packages.gz Packages.sig "$out/"
install -m644 "$key.pub" "$out/v2rayblisc-opkg.pub"
