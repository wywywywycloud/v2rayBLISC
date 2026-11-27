# v2rayBLISC для OpenWrt

| Поддерживаемая версия | Установка | Сборка |
| --- | --- | --- |
| OpenWrt 24.10.x, x86/64 и ARMv8 | `opkg`, подписанные фиды для `x86_64`, `aarch64_generic`, `aarch64_cortex-a53`, `aarch64_cortex-a72`, `aarch64_cortex-a76` | [IPK и установщик 2026.11.27-r3](https://github.com/wywywywycloud/v2rayBLISC/releases/tag/openwrt-24.10-opkg-2026.11.27-r3) |
| OpenWrt 25.12.x, x86/64 и ARMv8 | `apk`, подписанные фиды для `x86_64`, `aarch64_generic`, `aarch64_cortex-a53`, `aarch64_cortex-a72`, `aarch64_cortex-a76` | [Репозитории APK](https://github.com/wywywywycloud/v2rayBLISC/tree/opkg-feed/25.12) |

Каждый пакет содержит сервис, веб-интерфейс и соответствующее ядро для указанной архитектуры. Войдите на роутер под root. Проверьте версию и архитектуру командой `ubus call system board`. Пакету и базам GeoIP/GeoSite требуется место в корневой файловой системе. Штатный пакет `v2raya` конфликтует с `v2rayblisc`.

## OpenWrt 24.10.x

Выполните в SSH-сессии на роутере под root. Если процессор отображается как **ARMv8 Processor rev 4**, установщик определит вариант пакета по архитектурам, которые принимает `opkg`. Он подключит подписанный фид своей архитектуры и установит `v2rayblisc`. Пакет автоматически установит из этого же фида расширение `luci-app-v2rayblisc`. В LuCI откройте **Сервисы → v2rayBLISC**. На странице доступны статус, настройки, журнал и кнопка перехода в веб-интерфейс. Системные зависимости, в том числе модуль TPROXY, устанавливаются из репозиториев прошивки.

```sh
wget -O /tmp/install-opkg.sh https://github.com/wywywywycloud/v2rayBLISC/releases/download/openwrt-24.10-opkg-2026.11.27-r3/install-opkg.sh && sh /tmp/install-opkg.sh
```

После первой установки выполните команды из раздела «Запуск и профиль». Если фид уже подключён, для установки или обновления обоих пакетов введите `opkg update && opkg install v2rayblisc luci-app-v2rayblisc`. Версия сервиса и ядра в этом выпуске — `2026.11.27-r3.5697216320dd`. [Фиды OpenWrt 24.10](https://github.com/wywywywycloud/v2rayBLISC/tree/opkg-feed/24.10)

## OpenWrt 24.10.5

Установщик выше подходит и для 24.10.5. Ранее подключённые фиды 24.10.5 для x86/64 и Cudy Cortex-A53 также получают обновления.

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
    x86_64) version=2026.11.27-r3; sum=4e312f26acf09b8b044543df7a093246dcf2384327cd03a02f75fef48a4ddf09 ;;
    aarch64_cortex-a53) version=2026.11.27-r3; sum=bc94dca71f0b1861e230f5fe6ff50707b6a1d30b524c42a1269d87564edbcbe7 ;;
    *) exit 1 ;;
  esac
  pkg=v2rayblisc_${version}_${DISTRIB_ARCH}.ipk
  echo "$sum  $pkg" | sha256sum -c -
  opkg --force-reinstall install "./$pkg"
)
```

## OpenWrt 25.12.x

В SSH-сессии на роутере выполните команду ниже. Установщик берёт архитектуру пакетов из `DISTRIB_ARCH` в `/etc/openwrt_release`, проверяет SHA-256 публичного ключа, записывает адрес фида в `/etc/apk/repositories.d/v2rayblisc.list` и устанавливает `v2rayblisc` вместе с `luci-app-v2rayblisc`. Модуль ядра TPROXY берётся из штатного фида работающей прошивки.

```sh
wget -O /tmp/install-apk.sh https://raw.githubusercontent.com/wywywywycloud/v2rayBLISC/openwrt-25.12-apk-2026.11.27-r3/install/openwrt/install-apk.sh && sh /tmp/install-apk.sh
```

После первой установки включите службу, как описано ниже. В LuCI откройте **Сервисы → v2rayBLISC**. Для последующих обновлений выполните `apk update && apk upgrade v2rayblisc`.

Для сборки этих фидов с настроенными `OPENWRT_SDK` и `APK_SIGN_KEY` выполните `OPENWRT_ARCH=x86_64 bash install/openwrt/package.sh VERSION dist/25.12 --feed`, затем повторите с `OPENWRT_ARCH=aarch64_generic`. Вторая команда собирает четыре фида с бинарниками ARMv8.0, для сжатия которых нужен UPX. В каждой папке архитектуры публикуются подписанный `packages.adb` и оба APK.

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
