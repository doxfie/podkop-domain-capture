#!/bin/ash

# Утилита для отлова DNS-доменов из dnsmasq logs для дальнейшего добавления в Podkop.
# Совместимо с OpenWrt BusyBox ash. Не использует bash-specific синтаксис.

LOG_FILE="/tmp/podkop-domain-capture.log"
PREV_FILE="/tmp/podkop-domain-capture.logqueries.prev"
LEASES_FILE="/tmp/dhcp.leases"

# Отключаем pathname expansion, чтобы домены/строки логов не раскрывались как glob.
set -f

ensure_interactive_input() {
	if [ -t 0 ]; then
		return 0
	fi

	if [ -c /dev/tty ]; then
		exec < /dev/tty
		if [ -t 0 ]; then
			return 0
		fi
	fi

	echo "Интерактивный ввод недоступен."
	echo "Не запускайте меню через pipe вида: wget -O - ... | sh"
	echo "Запустите скрипт напрямую:"
	echo "/root/podkop-domain-capture.sh"
	exit 1
}

show_menu() {
	echo
	echo "=== Podkop Domain Capture ==="
	echo "1) Показать DHCP leases"
	echo "2) Ловить домены от одного IP"
	echo "3) Ловить домены от двух IP"
	echo "4) Ловить домены от всех клиентов"
	echo "5) Показать уникальные домены из последнего лога"
	echo "6) Показать уникальные домены по конкретному IP из последнего лога"
	echo "7) Выключить dnsmasq logqueries и очистить временные логи"
	echo "0) Выход"
	echo
}

pause_enter() {
	echo
	printf "Нажмите Enter, чтобы продолжить..."
	IFS= read -r DUMMY || return 0
}

show_leases() {
	echo
	echo "DHCP leases:"

	if [ ! -s "$LEASES_FILE" ]; then
		echo "Файл $LEASES_FILE не найден или пуст."
		return
	fi

	# На OpenWrt /tmp/dhcp.leases имеет формат:
	# expires_epoch mac ip hostname client_id
	cat "$LEASES_FILE" | awk '
	function remaining(expire, left, d, h, m, s) {
		if (expire == 0) {
			return "never"
		}
		if (now == 0) {
			return "expires=" expire
		}
		left = expire - now
		if (left <= 0) {
			return "expired"
		}
		d = int(left / 86400)
		h = int((left % 86400) / 3600)
		m = int((left % 3600) / 60)
		s = left % 60
		if (d > 0) {
			return d "d " h "h " m "m"
		}
		if (h > 0) {
			return h "h " m "m"
		}
		if (m > 0) {
			return m "m " s "s"
		}
		return s "s"
	}
	BEGIN {
		now = systime()
		printf "%-15s %-17s %-24s %s\n", "IP", "MAC", "HOSTNAME", "REMAINING"
		printf "%-15s %-17s %-24s %s\n", "---------------", "-----------------", "------------------------", "---------"
	}
	{
		host = $4
		if (host == "" || host == "*") {
			host = "-"
		}
		printf "%-15s %-17s %-24s %s\n", $3, $2, host, remaining($1)
	}'
}

enable_logs() {
	echo
	echo "Сохраняю текущее значение dhcp.@dnsmasq[0].logqueries..."

	CURRENT_LOGQUERIES="$(uci -q get 'dhcp.@dnsmasq[0].logqueries' 2>/dev/null)"
	if [ -z "$CURRENT_LOGQUERIES" ]; then
		CURRENT_LOGQUERIES="unset"
	fi

	printf "%s\n" "$CURRENT_LOGQUERIES" > "$PREV_FILE" 2>/dev/null
	echo "Предыдущее значение: $CURRENT_LOGQUERIES"

	echo "Включаю dnsmasq logqueries..."
	if ! uci set 'dhcp.@dnsmasq[0].logqueries=1'; then
		echo "Ошибка: не удалось выполнить uci set."
		return 1
	fi
	if ! uci commit dhcp; then
		echo "Ошибка: не удалось выполнить uci commit dhcp."
		return 1
	fi
	if ! /etc/init.d/dnsmasq restart; then
		echo "Ошибка: не удалось перезапустить dnsmasq."
		return 1
	fi

	echo "dnsmasq logqueries включен."
	return 0
}

disable_logs() {
	echo
	echo "Выключаю dnsmasq logqueries..."

	if ! uci set 'dhcp.@dnsmasq[0].logqueries=0'; then
		echo "Ошибка: не удалось выполнить uci set."
		return 1
	fi
	if ! uci commit dhcp; then
		echo "Ошибка: не удалось выполнить uci commit dhcp."
		return 1
	fi
	if ! /etc/init.d/dnsmasq restart; then
		echo "Ошибка: не удалось перезапустить dnsmasq."
		return 1
	fi

	echo "dnsmasq logqueries выключен."
	return 0
}

parse_query_line() {
	CAP_LINE="$1"
	CAP_TIME=""
	CAP_DOMAIN=""
	CAP_CLIENT=""
	WANT_DOMAIN="0"
	WANT_CLIENT="0"

	for WORD in $CAP_LINE; do
		if [ "$WANT_DOMAIN" = "1" ]; then
			CAP_DOMAIN="$WORD"
			WANT_DOMAIN="0"
			continue
		fi

		if [ "$WANT_CLIENT" = "1" ]; then
			CAP_CLIENT="$WORD"
			WANT_CLIENT="0"
			continue
		fi

		case "$WORD" in
			[0-9][0-9]:[0-9][0-9]:[0-9][0-9])
				if [ -z "$CAP_TIME" ]; then
					CAP_TIME="$WORD"
				fi
				;;
			query\[*\])
				WANT_DOMAIN="1"
				;;
			from)
				WANT_CLIENT="1"
				;;
		esac
	done

	if [ -z "$CAP_DOMAIN" ] || [ -z "$CAP_CLIENT" ]; then
		return 1
	fi

	if [ -z "$CAP_TIME" ]; then
		CAP_TIME="$(awk 'BEGIN { print strftime("%H:%M:%S") }' 2>/dev/null)"
		if [ -z "$CAP_TIME" ]; then
			CAP_TIME="00:00:00"
		fi
	fi

	return 0
}

ask_show_unique() {
	echo
	printf "Вывести уникальные домены из сохраненного лога? [y/N]: "
	if ! IFS= read -r ANSWER; then
		echo
		return 0
	fi

	case "$ANSWER" in
		y|Y|yes|YES|д|Д|да|Да|ДА)
			show_unique
			;;
		*)
			echo "Ок, можно посмотреть позже через пункт меню 5 или 6."
			;;
	esac
}

capture_stream() {
	MODE="$1"
	IP1="$2"
	IP2="$3"

	if ! : > "$LOG_FILE"; then
		echo "Ошибка: не удалось создать файл $LOG_FILE."
		return 1
	fi

	echo
	echo "Отлов запущен. Нажмите Ctrl+C, чтобы остановить."
	echo "Лог сохраняется в: $LOG_FILE"
	echo
	echo "TIME     CLIENT_IP       DOMAIN"
	echo "-------- --------------- ------------------------------"

	trap 'echo; echo "Останавливаю live-отлов..."' INT

	logread -f -e dnsmasq | while IFS= read -r LINE; do
		if ! parse_query_line "$LINE"; then
			continue
		fi

		case "$MODE" in
			one)
				if [ "$CAP_CLIENT" != "$IP1" ]; then
					continue
				fi
				;;
			two)
				if [ "$CAP_CLIENT" != "$IP1" ] && [ "$CAP_CLIENT" != "$IP2" ]; then
					continue
				fi
				;;
			all)
				;;
		esac

		printf "%s %s %s\n" "$CAP_TIME" "$CAP_CLIENT" "$CAP_DOMAIN"
		printf "%s %s %s\n" "$CAP_TIME" "$CAP_CLIENT" "$CAP_DOMAIN" >> "$LOG_FILE"
	done

	trap - INT

	echo
	echo "Отлов остановлен."
	echo "Лог сохранен: $LOG_FILE"
	ask_show_unique
	return 0
}

capture_one() {
	echo
	printf "Введите IP клиента: "
	if ! IFS= read -r IP; then
		echo
		echo "Ввод недоступен."
		return 1
	fi

	if [ -z "$IP" ]; then
		echo "IP не указан."
		return 1
	fi

	enable_logs || return 1
	capture_stream "one" "$IP" ""
}

capture_two() {
	echo
	printf "Введите IP первого клиента: "
	if ! IFS= read -r IP_FIRST; then
		echo
		echo "Ввод недоступен."
		return 1
	fi

	printf "Введите IP второго клиента: "
	if ! IFS= read -r IP_SECOND; then
		echo
		echo "Ввод недоступен."
		return 1
	fi

	if [ -z "$IP_FIRST" ] || [ -z "$IP_SECOND" ]; then
		echo "Один из IP не указан."
		return 1
	fi

	enable_logs || return 1
	capture_stream "two" "$IP_FIRST" "$IP_SECOND"
}

capture_all() {
	enable_logs || return 1
	capture_stream "all" "" ""
}

show_unique() {
	echo

	if [ ! -s "$LOG_FILE" ]; then
		echo "Лог $LOG_FILE не найден или пуст."
		return 1
	fi

	echo "Уникальные домены из последнего лога:"
	awk '{print $3}' /tmp/podkop-domain-capture.log | sort -u
	return 0
}

show_unique_by_ip() {
	echo

	if [ ! -s "$LOG_FILE" ]; then
		echo "Лог $LOG_FILE не найден или пуст."
		return 1
	fi

	printf "Введите IP клиента: "
	if ! IFS= read -r IP; then
		echo
		echo "Ввод недоступен."
		return 1
	fi

	if [ -z "$IP" ]; then
		echo "IP не указан."
		return 1
	fi

	echo "Уникальные домены из последнего лога для $IP:"
	awk -v ip="$IP" '$2==ip{print $3}' /tmp/podkop-domain-capture.log | sort -u
	return 0
}

cleanup() {
	echo
	echo "Отключаю логирование и очищаю временные логи..."

	disable_logs

	rm -f "$LOG_FILE"
	rm -f "$PREV_FILE"

	# Для удаления временных файлов по glob временно включаем pathname expansion.
	set +f
	rm -f /tmp/*domains*.log
	rm -f /tmp/*dns*.log
	set -f

	echo "Очищаю RAM-log..."
	if /etc/init.d/log restart; then
		echo "Очистка завершена."
	else
		echo "Предупреждение: не удалось перезапустить log."
	fi
}

ensure_interactive_input

while :; do
	show_menu
	printf "Выберите пункт: "
	if ! IFS= read -r CHOICE; then
		echo
		echo "Ввод недоступен или stdin закрыт."
		echo "Если запускали через wget pipe, обновите install.sh или запустите напрямую:"
		echo "/root/podkop-domain-capture.sh"
		exit 1
	fi

	case "$CHOICE" in
		1)
			show_leases
			pause_enter
			;;
		2)
			capture_one
			pause_enter
			;;
		3)
			capture_two
			pause_enter
			;;
		4)
			capture_all
			pause_enter
			;;
		5)
			show_unique
			pause_enter
			;;
		6)
			show_unique_by_ip
			pause_enter
			;;
		7)
			cleanup
			pause_enter
			;;
		0)
			echo "Выход."
			exit 0
			;;
		*)
			echo "Неизвестный пункт: $CHOICE"
			pause_enter
			;;
	esac
done
