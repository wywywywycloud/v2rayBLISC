#!/usr/bin/env bash
# Creates a signed OpenWrt APK from the current checkout.
set -euo pipefail
: "${OPENWRT_SDK:?Point OPENWRT_SDK at the extracted OpenWrt SDK containing apk-tools}"
: "${APK_SIGN_KEY:?Point APK_SIGN_KEY at an RSA private key outside the source tree}"
version=${1:?Supply an APK version such as 2026.11.18-r1}
out=$(realpath -m "${2:-dist}")
mode=${3:-standalone}
case "$mode" in standalone|--feed) ;; *) echo "Unknown packaging mode: $mode" >&2; exit 1 ;; esac
src=$(cd "$(dirname "$0")/../.." && pwd)
cd "$src"
revision=$(git rev-parse --short=12 HEAD)
arch=${OPENWRT_ARCH:-x86_64}
name="v2rayblisc-$version.apk"
case "$arch" in
  x86_64) export GOARCH=amd64 ;;
  aarch64_generic|aarch64_cortex-a53|aarch64_cortex-a72|aarch64_cortex-a76)
    export GOARCH=arm64 GOARM64=v8.0
    name="v2rayblisc-$version-$arch.apk" ;;
  *) echo "Unsupported OpenWrt architecture: $arch" >&2; exit 1 ;;
esac
export GOOS=linux
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
depends='!v2raya ca-bundle ip-full kmod-nft-tproxy v2ray-geoip v2ray-geosite'
targets=("$arch")
if [[ $mode == --feed ]]; then
  depends+=' luci-app-v2rayblisc'
  if [[ $GOARCH == arm64 ]]; then
    # All four OpenWrt targets run the same ARMv8.0 binaries.
    targets=(aarch64_generic aarch64_cortex-a53 aarch64_cortex-a72 aarch64_cortex-a76)
    upx --fast "$root/usr/bin/v2raya" "$root/usr/bin/v2raya_core"
    upx -t "$root/usr/bin/v2raya" "$root/usr/bin/v2raya_core"
  fi
  luci=install/openwrt/luci-app-v2rayblisc
  mkdir "$stage/luci"
  cp -R "$luci/usr" "$luci/www" "$stage/luci/"
  luci_pkg="luci-app-v2rayblisc-$version.apk"
  "$apk" mkpkg --info name:luci-app-v2rayblisc --info "version:$version" --info arch:noarch \
    --info 'description:LuCI settings, status and log for v2rayBLISC' --info license:Apache-2.0 \
    --info depends:luci-base --files "$stage/luci" --script "post-install:$luci/CONTROL/postinst" \
    --script "post-upgrade:$luci/CONTROL/postinst" --script "post-deinstall:$luci/CONTROL/postinst" \
    --sign-key "$APK_SIGN_KEY" --output "$stage/$luci_pkg"
  install -m644 "$APK_SIGN_KEY.pub" "$out/blisc.pem.pub"
fi
for target in "${targets[@]}"; do
  dest=$out
  if [[ $mode == --feed ]]; then
    dest=$out/$target
    mkdir -p "$dest"
    name="v2rayblisc-$version.apk"
    install -m644 "$stage/$luci_pkg" "$dest/$luci_pkg"
  fi
  "$apk" mkpkg --info name:v2rayblisc --info "version:$version" --info "arch:$target" \
  --info 'description:v2rayA service, web interface and matching Xray-based core' \
  --info 'license:AGPL-3.0-only AND MPL-2.0' --info 'url:https://github.com/wywywywycloud/v2rayBLISC' \
  --info "depends:$depends" \
  --files "$root" --script "post-install:$stage/installed" --script "post-upgrade:$stage/installed" \
  --script "pre-deinstall:$stage/remove" --sign-key "$APK_SIGN_KEY" --output "$dest/$name"
  if [[ $mode == --feed ]]; then
    "$apk" mkndx --sign-key "$APK_SIGN_KEY" --output "$dest/packages.adb" "$dest/$name" "$dest/$luci_pkg"
  fi
done

