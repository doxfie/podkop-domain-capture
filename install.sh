#!/bin/ash

# Установщик Podkop Domain Capture для OpenWrt / BusyBox ash.
# Скачивает основной скрипт в /root и сразу запускает его.

SCRIPT_URL="${SCRIPT_URL:-https://raw.githubusercontent.com/doxfie/podkop-domain-capture/main/podkop-domain-capture.sh}"
TARGET="${TARGET:-/root/podkop-domain-capture.sh}"

echo "Podkop Domain Capture installer"
echo "Скачиваю скрипт:"
echo "$SCRIPT_URL"
echo

if ! command -v wget >/dev/null 2>&1; then
	echo "Ошибка: wget не найден."
	echo "Установите wget или скачайте podkop-domain-capture.sh вручную."
	exit 1
fi

if ! wget -O "$TARGET" "$SCRIPT_URL"; then
	echo "Ошибка: не удалось скачать скрипт."
	exit 1
fi

if ! chmod +x "$TARGET"; then
	echo "Ошибка: не удалось сделать скрипт исполняемым: $TARGET"
	exit 1
fi

echo
echo "Скрипт установлен: $TARGET"
echo "Запускаю..."
echo

exec "$TARGET"
