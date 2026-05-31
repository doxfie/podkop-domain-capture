# Podkop Domain Capture

Удобная CLI-утилита для OpenWrt, которая ловит DNS-домены из `dnsmasq` logs и помогает собрать список доменов для дальнейшего добавления в Podkop.

Скрипт работает через SSH, не ставит пакеты, не трогает настройки Podkop, не меняет firewall и не использует `tcpdump`.

## Быстрый запуск

Подключитесь к роутеру по SSH и выполните:

```sh
wget -O - https://raw.githubusercontent.com/doxfie/podkop-domain-capture/main/install.sh | sh
```

Команда скачает скрипт в `/root/podkop-domain-capture.sh`, сделает его исполняемым и сразу запустит.

## Альтернативный запуск без install.sh

```sh
wget -O /root/podkop-domain-capture.sh https://raw.githubusercontent.com/doxfie/podkop-domain-capture/main/podkop-domain-capture.sh
chmod +x /root/podkop-domain-capture.sh
/root/podkop-domain-capture.sh
```

После установки повторный запуск:

```sh
/root/podkop-domain-capture.sh
```

## Возможности

- показать DHCP leases из `/tmp/dhcp.leases`;
- ловить домены от одного IP;
- ловить домены от двух IP;
- ловить домены от всех клиентов;
- показывать уникальные домены из последнего лога;
- показывать уникальные домены по конкретному IP;
- выключать `dnsmasq logqueries` и очищать временные логи.

## Где сохраняется лог

Live-отлов сохраняет строки в:

```sh
/tmp/podkop-domain-capture.log
```

Формат строк:

```text
HH:MM:SS CLIENT_IP DOMAIN
```

Пример:

```text
16:10:16 192.168.1.132 api.example.com
```

## Как это работает

Перед отловом скрипт включает логирование запросов dnsmasq:

```sh
uci set dhcp.@dnsmasq[0].logqueries='1'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

Затем читает live-лог:

```sh
logread -f -e dnsmasq
```

Парсятся только строки вида `query[...]`, например:

```text
daemon.info dnsmasq[1]: 711 192.168.1.132/51968 query[HTTPS] prodregistryv2.org from 192.168.1.132
```

## Меню

```text
1) Показать DHCP leases
2) Ловить домены от одного IP
3) Ловить домены от двух IP
4) Ловить домены от всех клиентов
5) Показать уникальные домены из последнего лога
6) Показать уникальные домены по конкретному IP из последнего лога
7) Выключить dnsmasq logqueries и очистить временные логи
0) Выход
```

## Требования

- OpenWrt;
- `/bin/ash`;
- BusyBox tools;
- `awk`, `sort`, `grep`, `sed`;
- `wget` для быстрой установки с GitHub.

## Безопасность

Скрипт намеренно ограничен:

- не меняет настройки Podkop;
- не меняет firewall;
- не устанавливает пакеты;
- не использует `tcpdump`;
- не пишет в `/etc`, кроме изменения `dhcp.@dnsmasq[0].logqueries` через `uci`.

Для остановки live-отлова нажмите `Ctrl+C`. После остановки скрипт покажет путь к сохраненному логу и предложит вывести уникальные домены.

## Очистка

Пункт меню `7`:

- выключает `dnsmasq logqueries`;
- удаляет `/tmp/podkop-domain-capture.log`;
- удаляет временные `/tmp/*domains*.log` и `/tmp/*dns*.log`;
- перезапускает RAM-log через `/etc/init.d/log restart`.
