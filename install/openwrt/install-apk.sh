#!/bin/sh
# Install the signed v2rayBLISC repository for OpenWrt 25.12.x.
set -eu
. /etc/openwrt_release
case "$DISTRIB_RELEASE" in
  25.12.*) ;;
  *) echo "Требуется OpenWrt 25.12.x. Установлена версия $DISTRIB_RELEASE." >&2; exit 1 ;;
esac
# apk --print-arch reports "aarch64" even on target-specific OpenWrt builds.
arch=$DISTRIB_ARCH
case "$arch" in
  x86_64|aarch64_generic|aarch64_cortex-a53|aarch64_cortex-a72|aarch64_cortex-a76) ;;
  *) echo "В фиде нет сборки для $arch." >&2; exit 1 ;;
esac
feed=https://raw.githubusercontent.com/wywywywycloud/v2rayBLISC/opkg-feed/25.12
key=$(mktemp /tmp/v2rayblisc-key.XXXXXX)
trap 'rm -f "$key"' EXIT
wget -O "$key" "$feed/blisc.pem.pub"
echo "5add20097e2f769ba46b97eeee65ad400feb9a3ec34eeeb630504729a519499c  $key" | sha256sum -c -
mkdir -p /etc/apk/keys /etc/apk/repositories.d
cp "$key" /etc/apk/keys/blisc.pem.pub
printf '%s\n' "$feed/$arch/packages.adb" > /etc/apk/repositories.d/v2rayblisc.list
apk update
apk add v2rayblisc
apk upgrade v2rayblisc
