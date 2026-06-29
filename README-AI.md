 Назначение
wg-mgr.sh — это универсальный скрипт для управления WireGuard/AmneziaWG VPN сервером. Он автоматизирует полный цикл работы: подготовку конфигурации, установку сервера, управление клиентами и настройку файервола.

🏗️ Архитектура системы
text
wg-mgr.sh
├── prepare     → Создает конфигурационный файл vars4install.conf
├── install     → Устанавливает WireGuard, настраивает firewall
├── client      → Управление клиентами (add/del/list/count)
├── uninstall   → Удаление (TODO - не реализовано)
│
├── Конфигурационные файлы:
│   ├── vars4install.conf    → Параметры для установки
│   ├── params.conf          → Основные параметры сервера
│   ├── hand_params.conf     → Дополнительные параметры для firewall
│   └── last-args.conf       → Сохраненные аргументы командной строки
│
└── Шаблоны:
    ├── template-server.tmpl → Шаблон конфигурации на сервере
    └── template-client.tmpl → Шаблон конфигурации для клиента
📂 Конфигурационные файлы
1. vars4install.conf — параметры для установки
Создается командой prepare. Содержит переменные с префиксом INST_*.

Переменная	Описание	Пример
INST_SERVER_PUB_NIC	Публичный сетевой интерфейс	ens3
INST_SERVER_PUB_IP	Публичный IP сервера	192.168.15.41
INST_SERVER_WG_NIC	Имя WireGuard интерфейса	wg0
INST_SERVER_WG_IPV4	IPv4 сервера в VPN	10.66.66.1/24
INST_SERVER_WG_IPV6	IPv6 сервера в VPN	fc00:66:66:66::1/64
INST_SERVER_PORT	Порт WireGuard	60888
INST_SERVER_PRIV_KEY	Приватный ключ сервера	(генерируется)
INST_SERVER_PUB_KEY	Публичный ключ сервера	(генерируется)
INST_CLIENT_DNS	DNS для клиентов	1.1.1.1,1.0.0.1
INST_ALLOWED_IPS	Разрешенные IP для клиентов	0.0.0.0/0,::/0
2. params.conf — основные параметры сервера
Создается командой install. Используется для управления клиентами.

Переменная	Описание	Пример
SERVER_PUB_NIC	Публичный интерфейс	ens3
SERVER_PUB_IP	Публичный IP	192.168.15.41
SERVER_WG_NIC	WireGuard интерфейс	wg13
SERVER_WG_IPV4	IPv4 сервера	172.25.25.254
SERVER_WG_IPV4_MASK	Маска подсети	24
SERVER_WG_IPV6	IPv6 сервера	(опционально)
SERVER_WG_IPV6_MASK	Маска IPv6	(опционально)
SERVER_PORT	Порт WireGuard	62141
SERVER_PRIV_KEY	Приватный ключ	(скрыт)
SERVER_PUB_KEY	Публичный ключ	(скрыт)
CLIENT_DNS	DNS для клиентов	1.1.1.1
ALLOWED_IPS	Разрешенные IP	0.0.0.0/0,::/0
3. hand_params.conf — параметры для firewall
Создается командой install. Используется в apply_rules.sh.

Переменная	Описание	Пример
SSH_PORT	Порт SSH	22
WG_PROTO	Протокол VPN	udp
WG_NET	VPN сеть	172.25.25.0/24
PROVIDER_GW_MAC	MAC шлюза провайдера	08:05:e2:fa:07:f0
PROVIDER_GW_IP	IP шлюза (опционально)	45.95.233.1
NFT_COUNTER	Включить счетчики	counter
NFT_NAT_NET	Сети для NAT	192.168.15.0/24
NFT_LIST_TRUST_WAN	Доверенные WAN	cl.vpn.mrovo.ru
NFT_LIST_TRUST_VPN	Доверенные VPN	192.168.15.0/24
NFT_LIST_VPN	Клиенты с доступом в LAN	(список IP)
NFT_LIST_VPN_ONLY	Клиенты только с LAN	(список IP)
NFT_LIST_INET_DROP	Клиенты без интернета	(список IP)
🚀 Команды
prepare — подготовка конфигурации
bash
wg-mgr.sh prepare [options]
Автоматически создает файл vars4install.conf с параметрами для установки.

Опции:

Опция	Описание	Пример
-c, --config <filename>	Имя файла конфигурации	-c myconfig.conf
-i, --wg-nic <IFACE>	Имя WireGuard интерфейса	-i wg0
--ip4 <address/mask>	IPv4 сервера	--ip4 10.66.66.1/24
--ip6 <address/mask>	IPv6 сервера	--ip6 fc00::1/64
--dns <list>	DNS серверы	--dns 8.8.8.8,1.1.1.1
-e, --allowed-ips <list>	Разрешенные IP	-e 0.0.0.0/0,::/0
Примеры:

bash
# Создать конфиг с настройками по умолчанию
wg-mgr.sh prepare

# Создать конфиг с пользовательскими параметрами
wg-mgr.sh prepare -c vps.conf -i wg0 --ip4 10.18.18.1/24 --dns 8.8.8.8

# Создать конфиг с IPv6
wg-mgr.sh prepare -i wg1 --ip4 10.77.77.1/24 --ip6 fd00:77:77::1/64
install — установка WireGuard
bash
wg-mgr.sh install [options]
Устанавливает WireGuard, настраивает системные параметры, создает конфигурацию и применяет правила файервола.

Опции:

Опция	Описание	Пример
-c, --config <filename>	Файл с параметрами установки	-c vars4install.conf
-i, --wg-nic <IFACE>	Имя WireGuard интерфейса	-i wg0
--ip4 <address/mask>	IPv4 сервера	--ip4 10.66.66.1/24
--ip6 <address/mask>	IPv6 сервера	--ip6 fc00::1/64
--dns <list>	DNS серверы	--dns 8.8.8.8
-e, --allowed-ips <list>	Разрешенные IP	-e 0.0.0.0/0
-p, --params <filename>	Файл параметров	-p params.conf
-d, --hand-params <filename>	Дополнительный конфиг	-d hand_params.conf
-r, --rules-iptables <filename>	Шаблон правил firewall	-r ./iptables/rules.sh
-w, --wg-path <path>	Путь к WireGuard	-w /etc/wireguard
-o, --out-path <path>	Путь для клиентов	-o /etc/wireguard/clients
-u, --update-args	Обновить last-args.conf	-u
--dry-run	Пробный запуск	--dry-run
--debug	Отладочный вывод	--debug
-x, --allow-lxc	Установка в LXC	-x
Примеры:

bash
# Установка с подготовленным конфигом
wg-mgr.sh install -c vars4install.conf

# Установка с пользовательскими параметрами
wg-mgr.sh install -i wg0 --ip4 10.18.18.1/24 --dns 8.8.8.8

# Установка в LXC контейнере
wg-mgr.sh install --allow-lxc

# Пробный запуск с отладкой
wg-mgr.sh install -c my.conf --dry-run --debug
client — управление клиентами
bash
wg-mgr.sh client [options]
Управляет клиентами WireGuard: добавляет, удаляет, показывает список.

Опции:

Опция	Описание	Пример
-a, --action <action>	Действие: add, del, list, count	-a add
-n, --name <name>	Имя клиента	-n client1
-i, --wg-nic <IFACE>	Имя интерфейса	-i wg0
--ip4 <address/mask>	IPv4 клиента	--ip4 10.18.18.2/24
--ip6 <address/mask>	IPv6 клиента	--ip6 fd00::2/64
-e, --allowed-ips <list>	Разрешенные IP для клиента	-e 10.18.18.2/32
--dns <list>	DNS для клиента	--dns 8.8.8.8
-k, --keepalive <sec>	PersistentKeepalive	-k 25
-p, --params <filename>	Файл параметров	-p params.conf
-d, --hand-params <filename>	Дополнительный конфиг	-d hand_params.conf
-w, --wg-path <path>	Путь к WireGuard	-w /etc/wireguard
-o, --out-path <path>	Путь для клиентов	-o ./clients
--all	Показать всех клиентов	--all
--dry-run	Пробный запуск	--dry-run
--debug	Отладочный вывод	--debug
Действия (-a, --action):

Значение	Описание
add, a, new	Добавить нового клиента
del, d, delete	Удалить клиента
list, l	Показать список клиентов
count, c	Показать количество активных клиентов
Примеры:

bash
# Добавить клиента
wg-mgr.sh client -a add -n laptop -i wg0 --ip4 10.18.18.2/24

# Добавить клиента с IPv6 и кастомным DNS
wg-mgr.sh client -a add -n mobile -i wg0 --ip4 10.18.18.3/24 --ip6 fd00::3/64 --dns 8.8.8.8

# Добавить клиента с PersistentKeepalive (для клиентов за NAT)
wg-mgr.sh client -a add -n nat-client -i wg0 --ip4 10.18.18.4/24 -k 25

# Список клиентов
wg-mgr.sh client -a list -i wg0

# Список всех клиентов (включая неуправляемые)
wg-mgr.sh client -a list -i wg0 --all

# Удалить клиента
wg-mgr.sh client -a del -n laptop -i wg0

# Количество активных клиентов
wg-mgr.sh client -a count -i wg0
uninstall — удаление (TODO)
bash
wg-mgr.sh uninstall
Внимание: Команда пока не реализована (отмечена как TODO). В будущем будет удалять WireGuard и все связанные файлы.

📂 Шаблоны конфигураций
template-server.tmpl
Шаблон для добавления клиента в конфигурацию сервера:

text
### Client $name $ip_desc ###
[Peer]
PublicKey = $WG_PUBLIC_KEY_CLIENT
PresharedKey = $WG_PSK_KEY_CLIENT
AllowedIPs = $WG_IP_CLIENT/32
### END Client $name $ip_desc ###
template-client.tmpl
Шаблон для создания клиентской конфигурации:

text
[Interface]
PrivateKey = $WG_PRIVATE_KEY_CLIENT
Address = $WG_IP_CLIENT/$WG_MASK_NET_CLIENT
DNS = $WG_DNS

[Peer]
PublicKey = $WG_PUBLIC_KEY_SERVER
PresharedKey = $WG_PSK_KEY_CLIENT
Endpoint = $WG_ENDPOINT
AllowedIPs = $WG_ALLOWED_IPS
🛡️ Файрвол: apply_rules.sh
Скрипт apply_rules.sh автоматически создается из шаблона (./iptables/default-iptables.rules или ./nft.rules.sh) и подключается к WireGuard через PostUp/PostDown.

Шаблон nft.rules.sh — это основа для генерации apply_rules.sh:

Содержит все правила nftables

Использует переменные из params.conf и hand_params.conf

Адаптируется под наличие данных (условное создание ARP правил)

Интеграция:

bash
# В файле /etc/wireguard/wg13.conf
PostUp = /etc/wireguard/apply_rules.sh add
PostDown = /etc/wireguard/apply_rules.sh del
🔧 Переменные окружения
Скрипт поддерживает передачу значений через переменные окружения (в конфигурационных файлах):

Переменная	Назначение
NFT_COUNTER	Включает счетчики в nftables (значение counter)
📊 Пример полного цикла работы
1. Подготовка конфигурации
bash
# Создать конфиг с параметрами по умолчанию
./wg-mgr.sh prepare

# Или с кастомными параметрами
./wg-mgr.sh prepare -c vps.conf -i wg0 --ip4 10.66.66.1/24 --dns 8.8.8.8
2. Установка сервера
bash
# Установить с подготовленным конфигом
./wg-mgr.sh install -c vps.conf

# Или с параметрами из командной строки
./wg-mgr.sh install -i wg0 --ip4 10.66.66.1/24 --dns 8.8.8.8
3. Добавление клиентов
bash
# Добавить клиента для ноутбука
./wg-mgr.sh client -a add -n laptop -i wg0 --ip4 10.66.66.2/24

# Добавить клиента для телефона
./wg-mgr.sh client -a add -n phone -i wg0 --ip4 10.66.66.3/24

# Добавить клиента с PersistentKeepalive
./wg-mgr.sh client -a add -n mobile -i wg0 --ip4 10.66.66.4/24 -k 25
4. Просмотр клиентов
bash
# Просмотр всех клиентов
./wg-mgr.sh client -a list -i wg0

# Количество активных клиентов
./wg-mgr.sh client -a count -i wg0
5. Удаление клиента
bash
./wg-mgr.sh client -a del -n laptop -i wg0
🐛 Отладка
Включение отладочного режима
bash
# Добавьте --debug к любой команде
./wg-mgr.sh install --debug
./wg-mgr.sh client -a add -n test -i wg0 --ip4 10.66.66.10/24 --debug
Пробный запуск (dry-run)
bash
# Показать, что будет выполнено, без реальных изменений
./wg-mgr.sh install --dry-run
./wg-mgr.sh client -a add -n test -i wg0 --ip4 10.66.66.10/24 --dry-run
Просмотр логов
bash
# Логи WireGuard
journalctl -u wg-quick@wg0 -f

# Логи nftables (отбрасываемые пакеты)
journalctl -kf | grep "DROPPED"

# Просмотр правил nftables
nft list ruleset
⚠️ Важные замечания
Требуются права root — все операции выполняются от root

Поддерживаемые ОС — Debian 10+, Ubuntu 18.04+, Alpine Linux

Виртуализация — OpenVZ не поддерживается, LXC — только с флагом --allow-lxc

IPv6 — поддержка частичная (опция --use-ipv6 не полностью реализована)

nftables — используется через шаблон nft.rules.sh, интеграция ручная

uninstall — пока не реализован

📝 Примеры пользовательских настроек
Настройка доступа клиентов к локальной сети
В hand_params.conf:

bash
### Список адресов, которым разрешен доступ к LAN'ам
NFT_LIST_VPN="192.168.15.100, 192.168.15.101"

### Список адресов, которым разрешен доступ только к LAN'ам (без интернета)
NFT_LIST_VPN_ONLY="192.168.15.200"

### Список адресов, которым запрещен доступ к INET'у
NFT_LIST_INET_DROP="192.168.15.129"
Настройка DNS для локальной сети
bash
### DNS сервер локальной сети
NFT_DNS_LOCALNET="192.168.15.3"

### DNS домены поиска для локальной сети
NFT_SEARCH_DOMAIN_LOCALNET="home.lan klinika.lan"
🎯 Заключение
wg-mgr.sh — это мощный инструмент для управления WireGuard/AmneziaWG серверами, который:

✅ Автоматизирует установку и настройку

✅ Упрощает управление клиентами

✅ Интегрируется с nftables через шаблоны

✅ Поддерживает гибкую настройку через конфигурационные файлы

✅ Работает на Debian, Ubuntu и Alpine Linux

Этот ответ сгенерирован AI, только для справки.
Установка только Wireguard. Для амнезии использовать только для подготовки конфигурационных файлов, запускать с ключом --dry-run
Понял! Вы используете wg-mgr.sh для установки только WireGuard, а для AmneziaWG — только для подготовки конфигурационных файлов с ключом --dry-run. Это разумный подход, так как AmneziaWG имеет свои особенности установки.

Давайте обновим документацию с учетом этого:

📚 Документация: wg-mgr.sh
📌 Назначение
wg-mgr.sh — это универсальный скрипт для управления WireGuard VPN сервером.

Важно:

Для WireGuard — полная установка и управление

Для AmneziaWG — только подготовка конфигурационных файлов (запуск с --dry-run)

🏗️ Архитектура системы
text
wg-mgr.sh
├── prepare     → Создает конфигурационные файлы для установки
├── install     → Устанавливает WireGuard (НЕ AmneziaWG!)
├── client      → Управление клиентами WireGuard
├── uninstall   → Удаление (TODO)
│
├── Конфигурационные файлы:
│   ├── vars4install.conf    → Параметры для установки
│   ├── params.conf          → Основные параметры сервера
│   ├── hand_params.conf     → Дополнительные параметры для firewall
│   └── last-args.conf       → Сохраненные аргументы
│
└── Шаблоны:
    ├── template-server.tmpl → Шаблон конфигурации на сервере
    └── template-client.tmpl → Шаблон конфигурации для клиента
📂 Конфигурационные файлы
1. vars4install.conf — параметры для установки
Создается командой prepare. Содержит переменные с префиксом INST_*.

Переменная	Описание	Пример
INST_SERVER_PUB_NIC	Публичный сетевой интерфейс	ens3
INST_SERVER_PUB_IP	Публичный IP сервера	192.168.15.41
INST_SERVER_WG_NIC	Имя WireGuard интерфейса	wg0
INST_SERVER_WG_IPV4	IPv4 сервера в VPN	10.66.66.1/24
INST_SERVER_WG_IPV6	IPv6 сервера в VPN	fc00:66:66:66::1/64
INST_SERVER_PORT	Порт WireGuard	60888
INST_SERVER_PRIV_KEY	Приватный ключ сервера	(генерируется)
INST_SERVER_PUB_KEY	Публичный ключ сервера	(генерируется)
INST_CLIENT_DNS	DNS для клиентов	1.1.1.1,1.0.0.1
INST_ALLOWED_IPS	Разрешенные IP для клиентов	0.0.0.0/0,::/0
2. params.conf — основные параметры сервера
Создается командой install. Используется для управления клиентами.

Переменная	Описание	Пример
SERVER_PUB_NIC	Публичный интерфейс	ens3
SERVER_PUB_IP	Публичный IP	192.168.15.41
SERVER_WG_NIC	WireGuard интерфейс	wg13
SERVER_WG_IPV4	IPv4 сервера	172.25.25.254
SERVER_WG_IPV4_MASK	Маска подсети	24
SERVER_WG_IPV6	IPv6 сервера	(опционально)
SERVER_WG_IPV6_MASK	Маска IPv6	(опционально)
SERVER_PORT	Порт WireGuard	62141
SERVER_PRIV_KEY	Приватный ключ	(скрыт)
SERVER_PUB_KEY	Публичный ключ	(скрыт)
CLIENT_DNS	DNS для клиентов	1.1.1.1
ALLOWED_IPS	Разрешенные IP	0.0.0.0/0,::/0
3. hand_params.conf — параметры для firewall
Создается командой install. Используется в apply_rules.sh.

Переменная	Описание	Пример
SSH_PORT	Порт SSH	22
WG_PROTO	Протокол VPN	udp
WG_NET	VPN сеть	172.25.25.0/24
PROVIDER_GW_MAC	MAC шлюза провайдера	08:05:e2:fa:07:f0
PROVIDER_GW_IP	IP шлюза (опционально)	45.95.233.1
NFT_COUNTER	Включить счетчики	counter
NFT_NAT_NET	Сети для NAT	192.168.15.0/24
NFT_LIST_TRUST_WAN	Доверенные WAN	cl.vpn.mrovo.ru
NFT_LIST_TRUST_VPN	Доверенные VPN	192.168.15.0/24
NFT_LIST_VPN	Клиенты с доступом в LAN	(список IP)
NFT_LIST_VPN_ONLY	Клиенты только с LAN	(список IP)
NFT_LIST_INET_DROP	Клиенты без интернета	(список IP)
🚀 Команды
prepare — подготовка конфигурации
bash
wg-mgr.sh prepare [options]
Автоматически создает файл vars4install.conf с параметрами для установки.

Опции:

Опция	Описание	Пример
-c, --config <filename>	Имя файла конфигурации	-c myconfig.conf
-i, --wg-nic <IFACE>	Имя интерфейса	-i wg0
--ip4 <address/mask>	IPv4 сервера	--ip4 10.66.66.1/24
--ip6 <address/mask>	IPv6 сервера	--ip6 fc00::1/64
--dns <list>	DNS серверы	--dns 8.8.8.8,1.1.1.1
-e, --allowed-ips <list>	Разрешенные IP	-e 0.0.0.0/0,::/0
Примеры:

bash
# Создать конфиг с настройками по умолчанию
wg-mgr.sh prepare

# Создать конфиг для AmneziaWG (только подготовка!)
wg-mgr.sh prepare -c awg.conf -i awg0 --ip4 10.9.8.1/24

# Создать конфиг с пользовательскими параметрами
wg-mgr.sh prepare -c vps.conf -i wg0 --ip4 10.18.18.1/24 --dns 8.8.8.8

# Создать конфиг с IPv6
wg-mgr.sh prepare -i wg1 --ip4 10.77.77.1/24 --ip6 fd00:77:77::1/64
install — установка WireGuard (НЕ AmneziaWG!)
bash
wg-mgr.sh install [options]
Важно: Эта команда устанавливает только WireGuard. Для AmneziaWG используйте prepare с --dry-run для подготовки конфигураций.

Устанавливает WireGuard, настраивает системные параметры, создает конфигурацию и применяет правила файервола.

Опции:

Опция	Описание	Пример
-c, --config <filename>	Файл с параметрами установки	-c vars4install.conf
-i, --wg-nic <IFACE>	Имя интерфейса	-i wg0
--ip4 <address/mask>	IPv4 сервера	--ip4 10.66.66.1/24
--ip6 <address/mask>	IPv6 сервера	--ip6 fc00::1/64
--dns <list>	DNS серверы	--dns 8.8.8.8
-e, --allowed-ips <list>	Разрешенные IP	-e 0.0.0.0/0
-p, --params <filename>	Файл параметров	-p params.conf
-d, --hand-params <filename>	Дополнительный конфиг	-d hand_params.conf
-r, --rules-iptables <filename>	Шаблон правил firewall	-r ./iptables/rules.sh
-w, --wg-path <path>	Путь к WireGuard	-w /etc/wireguard
-o, --out-path <path>	Путь для клиентов	-o /etc/wireguard/clients
-u, --update-args	Обновить last-args.conf	-u
--dry-run	Пробный запуск	--dry-run
--debug	Отладочный вывод	--debug
-x, --allow-lxc	Установка в LXC	-x
Примеры:

bash
# Установка WireGuard с подготовленным конфигом
wg-mgr.sh install -c vars4install.conf

# Установка WireGuard с пользовательскими параметрами
wg-mgr.sh install -i wg0 --ip4 10.18.18.1/24 --dns 8.8.8.8

# Установка в LXC контейнере
wg-mgr.sh install --allow-lxc

# Пробный запуск с отладкой
wg-mgr.sh install -c my.conf --dry-run --debug
client — управление клиентами
bash
wg-mgr.sh client [options]
Управляет клиентами WireGuard: добавляет, удаляет, показывает список.

Опции:

Опция	Описание	Пример
-a, --action <action>	Действие: add, del, list, count	-a add
-n, --name <name>	Имя клиента	-n client1
-i, --wg-nic <IFACE>	Имя интерфейса	-i wg0
--ip4 <address/mask>	IPv4 клиента	--ip4 10.18.18.2/24
--ip6 <address/mask>	IPv6 клиента	--ip6 fd00::2/64
-e, --allowed-ips <list>	Разрешенные IP для клиента	-e 10.18.18.2/32
--dns <list>	DNS для клиента	--dns 8.8.8.8
-k, --keepalive <sec>	PersistentKeepalive	-k 25
-p, --params <filename>	Файл параметров	-p params.conf
-d, --hand-params <filename>	Дополнительный конфиг	-d hand_params.conf
-w, --wg-path <path>	Путь к WireGuard	-w /etc/wireguard
-o, --out-path <path>	Путь для клиентов	-o ./clients
--all	Показать всех клиентов	--all
--dry-run	Пробный запуск	--dry-run
--debug	Отладочный вывод	--debug
Действия (-a, --action):

Значение	Описание
add, a, new	Добавить нового клиента
del, d, delete	Удалить клиента
list, l	Показать список клиентов
count, c	Показать количество активных клиентов
Примеры:

bash
# Добавить клиента
wg-mgr.sh client -a add -n laptop -i wg0 --ip4 10.18.18.2/24

# Добавить клиента с IPv6 и кастомным DNS
wg-mgr.sh client -a add -n mobile -i wg0 --ip4 10.18.18.3/24 --ip6 fd00::3/64 --dns 8.8.8.8

# Добавить клиента с PersistentKeepalive (для клиентов за NAT)
wg-mgr.sh client -a add -n nat-client -i wg0 --ip4 10.18.18.4/24 -k 25

# Список клиентов
wg-mgr.sh client -a list -i wg0

# Список всех клиентов (включая неуправляемые)
wg-mgr.sh client -a list -i wg0 --all

# Удалить клиента
wg-mgr.sh client -a del -n laptop -i wg0

# Количество активных клиентов
wg-mgr.sh client -a count -i wg0
uninstall — удаление (TODO)
bash
wg-mgr.sh uninstall
Внимание: Команда пока не реализована (отмечена как TODO).

🔧 Использование для AmneziaWG
Подготовка конфигурационных файлов
Для AmneziaWG скрипт используется только для подготовки конфигурационных файлов с ключом --dry-run:

bash
# 1. Подготовить конфиг для AmneziaWG
wg-mgr.sh prepare -c awg.conf -i awg0 --ip4 10.9.8.1/24

# 2. Просмотреть, что будет создано при установке (без реальных изменений)
wg-mgr.sh install -c awg.conf --dry-run --debug

# 3. Получить готовые конфигурационные файлы
#    - vars4install.conf / awg.conf
#    - params.conf (будет создан при install --dry-run)
#    - hand_params.conf (будет создан при install --dry-run)
#    - apply_rules.sh (шаблон для nftables)

# 4. Использовать полученные файлы для ручной установки AmneziaWG
Что создается при --dry-run:

params.conf — основные параметры сервера

hand_params.conf — параметры для nftables

apply_rules.sh — скрипт настройки nftables (из шаблона)

last-args.conf — сохраненные аргументы

Пример:

bash
# Подготовка конфига для AmneziaWG
wg-mgr.sh prepare -c awg.conf -i awg0 --ip4 10.9.8.1/24

# Генерация всех файлов без установки
wg-mgr.sh install -c awg.conf --dry-run --debug

# Результат:
# /etc/wireguard/awg0.conf          # Конфигурация AmneziaWG (только параметры)
# /etc/wireguard/params.conf        # Основные параметры
# /etc/wireguard/hand_params.conf   # Параметры для nftables
# /etc/wireguard/apply_rules.sh     # Скрипт nftables
# /etc/wireguard/.clients/          # Каталог для клиентов
📂 Шаблоны конфигураций
template-server.tmpl
Шаблон для добавления клиента в конфигурацию сервера:

text
### Client $name $ip_desc ###
[Peer]
PublicKey = $WG_PUBLIC_KEY_CLIENT
PresharedKey = $WG_PSK_KEY_CLIENT
AllowedIPs = $WG_IP_CLIENT/32
### END Client $name $ip_desc ###
template-client.tmpl
Шаблон для создания клиентской конфигурации:

text
[Interface]
PrivateKey = $WG_PRIVATE_KEY_CLIENT
Address = $WG_IP_CLIENT/$WG_MASK_NET_CLIENT
DNS = $WG_DNS

[Peer]
PublicKey = $WG_PUBLIC_KEY_SERVER
PresharedKey = $WG_PSK_KEY_CLIENT
Endpoint = $WG_ENDPOINT
AllowedIPs = $WG_ALLOWED_IPS
🛡️ Файрвол: apply_rules.sh
Скрипт apply_rules.sh автоматически создается из шаблона nft.rules.sh и подключается к WireGuard через PostUp/PostDown.

Шаблон nft.rules.sh:

Содержит все правила nftables

Использует переменные из params.conf и hand_params.conf

Адаптируется под наличие данных (условное создание ARP правил)

Интеграция:

bash
# В файле /etc/wireguard/wg13.conf
PostUp = /etc/wireguard/apply_rules.sh add
PostDown = /etc/wireguard/apply_rules.sh del
🔧 Переменные окружения
Переменная	Назначение
NFT_COUNTER	Включает счетчики в nftables (значение counter)
📊 Пример полного цикла для WireGuard
1. Подготовка конфигурации
bash
# Создать конфиг с параметрами по умолчанию
./wg-mgr.sh prepare

# Или с кастомными параметрами
./wg-mgr.sh prepare -c vps.conf -i wg0 --ip4 10.66.66.1/24 --dns 8.8.8.8
2. Установка WireGuard
bash
# Установить с подготовленным конфигом
./wg-mgr.sh install -c vps.conf

# Или с параметрами из командной строки
./wg-mgr.sh install -i wg0 --ip4 10.66.66.1/24 --dns 8.8.8.8
3. Добавление клиентов
bash
# Добавить клиента для ноутбука
./wg-mgr.sh client -a add -n laptop -i wg0 --ip4 10.66.66.2/24

# Добавить клиента для телефона
./wg-mgr.sh client -a add -n phone -i wg0 --ip4 10.66.66.3/24

# Добавить клиента с PersistentKeepalive
./wg-mgr.sh client -a add -n mobile -i wg0 --ip4 10.66.66.4/24 -k 25
4. Просмотр клиентов
bash
# Просмотр всех клиентов
./wg-mgr.sh client -a list -i wg0

# Количество активных клиентов
./wg-mgr.sh client -a count -i wg0
5. Удаление клиента
bash
./wg-mgr.sh client -a del -n laptop -i wg0
📊 Пример использования для AmneziaWG
bash
# 1. Подготовка конфигурации
./wg-mgr.sh prepare -c awg.conf -i awg0 --ip4 10.9.8.1/24 --dns 1.1.1.1

# 2. Генерация всех файлов (без установки)
./wg-mgr.sh install -c awg.conf --dry-run --debug

# 3. Проверка созданных файлов
ls -la /etc/wireguard/
# awg0.conf  params.conf  hand_params.conf  apply_rules.sh  .clients/

# 4. Ручная установка AmneziaWG с использованием:
#    - awg0.conf → конфигурация сервера
#    - params.conf → параметры для apply_rules.sh
#    - hand_params.conf → параметры для apply_rules.sh
#    - apply_rules.sh → скрипт nftables

# 5. Добавление клиентов (тоже с --dry-run для получения конфигов)
./wg-mgr.sh client -a add -n client1 -i awg0 --ip4 10.9.8.2/24 --dry-run

# 6. Готовые конфиги клиента в /etc/wireguard/.clients/
🐛 Отладка
Включение отладочного режима
bash
# Добавьте --debug к любой команде
./wg-mgr.sh install --debug
./wg-mgr.sh client -a add -n test -i wg0 --ip4 10.66.66.10/24 --debug
Пробный запуск (dry-run)
bash
# Показать, что будет выполнено, без реальных изменений
./wg-mgr.sh install --dry-run
./wg-mgr.sh client -a add -n test -i wg0 --ip4 10.66.66.10/24 --dry-run
Просмотр логов
bash
# Логи WireGuard
journalctl -u wg-quick@wg0 -f

# Логи nftables (отбрасываемые пакеты)
journalctl -kf | grep "DROPPED"

# Просмотр правил nftables
nft list ruleset
⚠️ Важные замечания
Требуются права root — все операции выполняются от root

Поддерживаемые ОС — Debian 10+, Ubuntu 18.04+, Alpine Linux

Виртуализация — OpenVZ не поддерживается, LXC — только с флагом --allow-lxc

IPv6 — поддержка частичная (опция --use-ipv6 не полностью реализована)

nftables — используется через шаблон nft.rules.sh

uninstall — пока не реализован

AmneziaWG — скрипт используется только для подготовки конфигураций с --dry-run
