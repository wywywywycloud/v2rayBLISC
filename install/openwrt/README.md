# v2rayBLISC для OpenWrt

| Поддерживаемая версия | Установка | Сборка |
| --- | --- | --- |
| OpenWrt 24.10.5 x86/64 | `opkg`, подписанный фид, пакет `v2rayblisc` | [IPK и ключ фида](https://github.com/wywywywycloud/v2rayBLISC/releases/tag/openwrt-24.10.5-x86_64-r1) |
| OpenWrt 24.10.5 aarch64_cortex-a53 (Cudy WR3000S v1) | `opkg`, подписанный ARM-фид | [IPK и ключ фида](https://github.com/wywywywycloud/v2rayBLISC/releases/tag/openwrt-24.10.5-cortex-a53-r2) |
| OpenWrt 25.12.5 x86/64 | `apk`, подписанный пакет `v2rayblisc` | [APK и ключ пакета](https://github.com/wywywywycloud/v2rayBLISC/releases/tag/openwrt-25.12.5-x86_64-r1) |

Каждый пакет содержит сервис, веб-интерфейс и соответствующее ядро для указанной архитектуры. Войдите на роутер под root. Проверьте версию и архитектуру командой `ubus call system board`. Пакету и базам GeoIP/GeoSite требуется место в корневой файловой системе. Штатный пакет `v2raya` конфликтует с `v2rayblisc`.

## OpenWrt 24.10.5

Подключите фид владельца `wywywywycloud`. Команды проверяют ключ, добавляют его в хранилище opkg и устанавливают пакет с зависимостями из штатных репозиториев.

```sh
(
  set -e
  . /etc/openwrt_release
  case "$DISTRIB_RELEASE/$DISTRIB_ARCH" in
    24.10.5/x86_64|24.10.5/aarch64_cortex-a53) ;;
    *) echo "Нет пакета для $DISTRIB_RELEASE/$DISTRIB_ARCH"; exit 1 ;;
  esac
  feed="https://raw.githubusercontent.com/wywywywycloud/v2rayBLISC/opkg-feed/24.10.5/$DISTRIB_ARCH"
  wget -O /tmp/v2rayblisc-opkg.pub "$feed/v2rayblisc-opkg.pub"
  echo '6541d42634568fbc438fe0b4dc1578c02ff80d4961b10b4058f988ba452dd160  /tmp/v2rayblisc-opkg.pub' | sha256sum -c -
  opkg-key add /tmp/v2rayblisc-opkg.pub
  echo "src/gz v2rayblisc $feed" > /etc/opkg/v2rayblisc.conf
  opkg update
  opkg install v2rayblisc
)
```

Для Cudy WR3000S v1 установку проверили штатным opkg в файловой системе официальной прошивки 24.10.5. На тестовом томе с 77,9 МиБ свободного места после установки пакета и всех недостающих зависимостей осталось 27,4 МиБ. Фактический расход на роутере зависит от состава прошивки и сжатия UBIFS. Для ARM64 с ОЗУ до 256 МиБ используйте r2. Служба procd задаёт предел памяти Go и частоту сборки мусора, чтобы применение правил и HTTP-пробы укладывались в доступную память.

Если требуется принудительно переустановить этот же выпуск на работающем прокси, сначала скачайте IPK. Команда переустановки может остановить сервис до окончания сетевой загрузки.

```sh
(
  set -e
  cd /tmp
  opkg download v2rayblisc
  . /etc/openwrt_release
  case "$DISTRIB_ARCH" in
    x86_64) revision=1; sum=52ad5eb1ba285d28a086a0166cbf6ac68b3b27883c8a83680685982e8cfa373e ;;
    aarch64_cortex-a53) revision=2; sum=0c7a516ff749310fda70dc8823cfb521dbff7b16dd7cecf25ace2339f632d783 ;;
    *) exit 1 ;;
  esac
  pkg=v2rayblisc_2026.11.18-r${revision}_${DISTRIB_ARCH}.ipk
  echo "$sum  $pkg" | sha256sum -c -
  opkg --force-reinstall install "./$pkg"
)
```

## OpenWrt 25.12.5

```sh
(
  set -e
  cd /tmp
  release=https://github.com/wywywywycloud/v2rayBLISC/releases/download/openwrt-25.12.5-x86_64-r1
  apk update
  apk add curl
  curl -fL --retry 2 -o blisc.pem.pub "$release/blisc.pem.pub"
  echo '5add20097e2f769ba46b97eeee65ad400feb9a3ec34eeeb630504729a519499c  blisc.pem.pub' | sha256sum -c -
  curl -fL --retry 2 -o v2rayblisc-2026.11.18-r1.apk "$release/v2rayblisc-2026.11.18-r1.apk"
  cp blisc.pem.pub /etc/apk/keys/blisc.pem.pub
  apk verify ./v2rayblisc-2026.11.18-r1.apk
  apk add ./v2rayblisc-2026.11.18-r1.apk
)
```

## Запуск и профиль

```sh
uci set v2raya.config.enabled=1
uci commit v2raya
/etc/init.d/v2raya enable
/etc/init.d/v2raya start
```

Откройте порт 2017 на LAN-адресе роутера, создайте учётную запись и импортируйте свою подписку. Сохранённые параметры TPROXY, RoutingA «Россия», автонаполнения группы, `leastping` и HTTP-проб доступны в [проверенном профиле](https://github.com/wywywywycloud/v2rayBLISC/releases/download/openwrt-25.12.5-x86_64-r1/profile.json). При переносе подставьте DNS своего WAN вместо адреса QEMU `10.0.2.3`. [Инструкция по применению профиля](https://github.com/wywywywycloud/v2rayBLISC/releases/download/openwrt-25.12.5-x86_64-r1/OpenWrt-25.12.5.txt)

## Сборка фида opkg

Чтобы выпустить тот же набор файлов для 24.10.5, сначала соберите подписанный пакет скриптом `package.sh` из этого каталога или возьмите опубликованный APK. В Linux используйте `apk` из SDK 25.12.5 и официальный ImageBuilder 24.10.5 для целевой платформы. Для Cortex-A53 используйте ImageBuilder mediatek/filogic и соберите промежуточный APK с `OPENWRT_ARCH=aarch64_cortex-a53`. Передайте этот APK скрипту `opkg-feed.sh`. Для упаковки ARM нужны также UPX и readelf. На стенде использовался UPX 5.2.1. Запустите упаковку под root или через fakeroot, чтобы владельцем файлов в архиве был root.

```sh
export IMAGEBUILDER=/path/to/openwrt-imagebuilder-24.10.5-x86-64.Linux-x86_64
export APK=/path/to/sdk-25.12.5/staging_dir/host/bin/apk
export APK_KEYS_DIR=/path/to/trusted-apk-public-keys
export USIGN_KEY=/private/path/to/opkg-key
# Для нового фида создать ключ один раз и сохранить для следующих публикаций.
(umask 077 && test ! -e "$USIGN_KEY" && test ! -e "$USIGN_KEY.pub" && "$IMAGEBUILDER/staging_dir/host/bin/usign" -G -s "$USIGN_KEY" -p "$USIGN_KEY.pub")
bash install/openwrt/opkg-feed.sh /path/to/v2rayblisc-2026.11.18-r1.apk ./feed
```

В каталог публикации попадут IPK, индекс opkg, подпись и публичный ключ фида.
