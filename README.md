# Podkop Domain Capture

![OpenWrt](https://img.shields.io/badge/OpenWrt-BusyBox%20ash-00B5E2)
![Dependencies](https://img.shields.io/badge/dependencies-0-brightgreen)
![Version](https://img.shields.io/badge/version-0.2.3--beta-blue)

Короткая SSH-утилита для OpenWrt: ловит DNS-домены из `dnsmasq` logs и помогает собрать список доменов для добавления в Podkop.

Скрипт не ставит пакеты, не меняет firewall, не трогает настройки Podkop и не использует `tcpdump`.

---

## 🚀 Быстрый запуск

Подключитесь к роутеру по SSH и выполните:

```sh
wget -O /usr/bin/pdc https://raw.githubusercontent.com/doxfie/podkop-domain-capture/main/podkop-domain-capture.sh && chmod +x /usr/bin/pdc && pdc
```

Повторный запуск:

```sh
pdc
```

---

## ✨ Возможности

- выбрать одного, нескольких или всех клиентов из `/tmp/dhcp.leases`;
- собрать live-лог DNS-запросов;
- вывести уникальные домены из последнего сбора;
- вывести домены по выбранному IP клиента;
- сбросить временные логи и выключить `dnsmasq logqueries`, если он остался включен.

---

## 🧭 Меню

```text
---------------------------------------------------------
Podkop Domain Capture [0.2.3-beta]
Сбор DNS-доменов из dnsmasq logs для Podkop
---------------------------------------------------------

Действия
 > Собрать домены
   Показать домены из последнего лога
   Показать домены по клиенту из последнего лога
   Сбросить временные логи
   Выход
```

Клавиши:

- `↑` / `↓` - выбрать пункт;
- `Space` / `Enter` - отметить клиента;
- `Enter` - открыть пункт или подтвердить действие;
- `q` - назад или выход;
- `Ctrl+C` - остановить live-сбор.

---

## 🧹 Перед сбором

Для чистого результата откройте проверяемый сайт в инкогнито/приватном окне и сбросьте DNS-кеш на устройстве, с которого открываете сайт.

Команды выполняются на ПК/телефоне клиента, а не в SSH-терминале роутера:

```sh
# Windows CMD/PowerShell
ipconfig /flushdns

# macOS Terminal
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

# Linux terminal
sudo resolvectl flush-caches
```

На iOS/Android обычно достаточно включить и выключить авиарежим или перезапустить Wi-Fi.

---

## 📝 Логи

Live-сбор сохраняется в:

```sh
/tmp/podkop-domain-capture.log
```

Формат строк:

```text
HH:MM:SS CLIENT_IP DOMAIN
```

`dnsmasq logqueries` включается только на время сбора и автоматически выключается после остановки через `Ctrl+C`.

Пункт `Сбросить временные логи` удаляет последний live-лог и служебные файлы pdc в `/tmp`, перезапускает RAM-log роутера.

---

## ⚙️ Требования

- OpenWrt;
- `/bin/ash`;
- BusyBox tools;
- BusyBox `ash` с поддержкой `read -s -n 1`;
- `awk`, `sort`, `grep`, `sed`;
- `wget`.
