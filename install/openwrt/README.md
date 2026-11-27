# v2rayBLISC для OpenWrt

| Поддерживаемая версия | Установка | Сборка |
| --- | --- | --- |
| OpenWrt 24.10.5 x86/64 | `opkg`, подписанный фид, пакет `v2rayblisc` | [IPK и ключ фида](https://github.com/wywywywycloud/v2rayBLISC/releases/tag/openwrt-24.10.5-x86_64-r1) |
| OpenWrt 24.10.x ARMv8, 64-битная прошивка | `opkg`, подписанные фиды для `aarch64_generic`, `aarch64_cortex-a53`, `aarch64_cortex-a72`, `aarch64_cortex-a76` | [IPK и установщик 2026.11.27-r2](https://github.com/wywywywycloud/v2rayBLISC/releases/tag/openwrt-24.10-armv8-2026.11.27-r2) |
| OpenWrt 25.12.5 x86/64 | `apk`, подписанный пакет `v2rayblisc` | [APK и ключ пакета](https://github.com/wywywywycloud/v2rayBLISC/releases/tag/openwrt-25.12.5-x86_64-r1) |

Каждый пакет содержит сервис, веб-интерфейс и соответствующее ядро для указанной архитектуры. Войдите на роутер под root. Проверьте версию и архитектуру командой `ubus call system board`. Пакету и базам GeoIP/GeoSite требуется место в корневой файловой системе. Штатный пакет `v2raya` конфликтует с `v2rayblisc`.

## OpenWrt 24.10.x на ARMv8

Выполните в SSH-сессии на роутере под root. Если процессор отображается как **ARMv8 Processor rev 4**, установщик определит вариант пакета по архитектурам, которые принимает `opkg`. Он подключит подписанный фид своей архитектуры и установит `v2rayblisc`. Пакет автоматически установит из этого же фида расширение `luci-app-v2rayblisc`. В LuCI откройте **Сервисы → v2rayBLISC**. На странице доступны статус, настройки, журнал и кнопка перехода в веб-интерфейс. Системные зависимости, в том числе модуль TPROXY, устанавливаются из репозиториев прошивки.

```sh
wget -O /tmp/install-armv8.sh https://github.com/wywywywycloud/v2rayBLISC/releases/download/openwrt-24.10-armv8-2026.11.27-r2/install-armv8.sh && sh /tmp/install-armv8.sh
```

После первой установки выполните команды из раздела «Запуск и профиль». Если фид уже подключён, для обновления введите `opkg update && opkg upgrade v2rayblisc`. Во всех четырёх IPK используются одинаковые бинарники ARMv8.0 версии `2026.11.27-r2.0f23c288efa3`. [Фиды ARMv8](https://github.com/wywywywycloud/v2rayBLISC/tree/opkg-feed/24.10)

## OpenWrt 24.10.5

Для ARMv8 используйте установщик выше. Ниже приведены команды для исходных фидов 24.10.5 x86/64 и Cudy Cortex-A53.

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

Для Cudy WR3000S v1 установку проверили штатным opkg в файловой системе официальной прошивки 24.10.5. При испытаниях версии 2026.11.18-r2 на тестовом томе с 77,9 МиБ свободного места после установки пакета и всех недостающих зависимостей осталось 27,4 МиБ. Фактический расход на роутере зависит от состава прошивки и сжатия UBIFS. Начиная с 2026.11.18-r2 на ARM64 с ОЗУ до 256 МиБ procd задаёт предел памяти Go и частоту сборки мусора.

Если требуется принудительно переустановить этот же выпуск на работающем прокси, сначала скачайте IPK. Команда переустановки может остановить сервис до окончания сетевой загрузки.

```sh
(
  set -e
  cd /tmp
  opkg download v2rayblisc
  . /etc/openwrt_release
  case "$DISTRIB_ARCH" in
    x86_64) version=2026.11.18-r1; sum=52ad5eb1ba285d28a086a0166cbf6ac68b3b27883c8a83680685982e8cfa373e ;;
    aarch64_cortex-a53) version=2026.11.27-r2; sum=919344dc3336a6764e60a2f06844f1fce1d72e3a215b66482f1ab3c3bdca5a1e ;;
    *) exit 1 ;;
  esac
  pkg=v2rayblisc_${version}_${DISTRIB_ARCH}.ipk
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
