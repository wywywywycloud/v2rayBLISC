#!/bin/sh
# Install the signed ARMv8 feed on OpenWrt 24.10.x.
set -eu
. /etc/openwrt_release
case "$DISTRIB_RELEASE" in
    24.10.*) ;;
    *) echo "Требуется OpenWrt 24.10.x, обнаружена версия $DISTRIB_RELEASE." >&2; exit 1 ;;
esac

arch=$(opkg print-architecture | awk '
    $1 == "arch" && $2 ~ /^aarch64_(generic|cortex-a53|cortex-a72|cortex-a76)$/ && $3+0 > priority {
        arch=$2; priority=$3+0
    }
    END {print arch}')
if [ -z "$arch" ]; then
    echo "Этой прошивке требуется другая архитектура пакетов:" >&2
    opkg print-architecture >&2
    exit 1
fi

feed="https://raw.githubusercontent.com/wywywywycloud/v2rayBLISC/opkg-feed/24.10/$arch"
key=$(mktemp /tmp/v2rayblisc-key.XXXXXX)
trap 'rm -f "$key"' EXIT
wget -O "$key" "$feed/v2rayblisc-opkg.pub"
echo "6541d42634568fbc438fe0b4dc1578c02ff80d4961b10b4058f988ba452dd160  $key" | sha256sum -c -
opkg-key add "$key"
echo "src/gz v2rayblisc $feed" > /etc/opkg/v2rayblisc.conf
opkg update
opkg install v2rayblisc
