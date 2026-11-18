#!/usr/bin/env bash
# Creates a signed OpenWrt x86_64 APK from the current checkout.
set -euo pipefail
: "${OPENWRT_SDK:?Point OPENWRT_SDK at the extracted 25.12.5 x86/64 SDK}"
: "${APK_SIGN_KEY:?Point APK_SIGN_KEY at an RSA private key outside the source tree}"
version=${1:?Supply an APK version such as 2026.11.18-r1}
out=$(realpath -m "${2:-dist}")
src=$(cd "$(dirname "$0")/../.." && pwd)
cd "$src"
revision=$(git rev-parse --short=12 HEAD)
test "$(uname -m)" = x86_64
export GOOS=linux GOARCH=amd64
bash ./build.sh "$version.$revision"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
root=$stage/root
install -Dm755 v2raya "$root/usr/bin/v2raya"
install -Dm755 v2raya_core "$root/usr/bin/v2raya_core"
install -Dm755 install/openwrt/v2raya.init "$root/etc/init.d/v2raya"
install -Dm644 install/openwrt/v2raya.config "$root/etc/config/v2raya"
install -Dm644 LICENSE "$root/usr/share/licenses/v2rayblisc/LICENSE"
install -Dm644 core/LICENSE "$root/usr/share/licenses/v2rayblisc/LICENSE.core"
mkdir -p "$root/usr/share/v2raya" "$out"
for dat in geoip geosite; do ln -s "../v2ray/$dat.dat" "$root/usr/share/v2raya/$dat.dat"; done
cat > "$stage/installed" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
/etc/init.d/v2raya enable
[ "$(uci -q get v2raya.config.enabled)" != 1 ] || /etc/init.d/v2raya restart
EOF
cat > "$stage/remove" <<'EOF'
#!/bin/sh
[ -n "$IPKG_INSTROOT" ] && exit 0
/etc/init.d/v2raya stop
/etc/init.d/v2raya disable
EOF
apk=$OPENWRT_SDK/staging_dir/host/bin/apk
"$apk" mkpkg --info name:v2rayblisc --info "version:$version" --info arch:x86_64 \
  --info 'description:v2rayA service, web interface and matching Xray-based core' \
  --info 'license:AGPL-3.0-only AND MPL-2.0' --info 'url:https://github.com/wywywywycloud/v2rayBLISC' \
  --info 'depends:!v2raya ca-bundle ip-full kmod-nft-tproxy v2ray-geoip v2ray-geosite' \
  --files "$root" --script "post-install:$stage/installed" --script "post-upgrade:$stage/installed" \
  --script "pre-deinstall:$stage/remove" --sign-key "$APK_SIGN_KEY" --output "$out/v2rayblisc-$version.apk"

