📚 Документация: wg-mgr.sh
📌 Назначение
wg-mgr.sh — это мощный и гибкий скрипт для автоматизации развертывания и управления VPN-серверами на базе WireGuard и AmneziaWG.

Для WireGuard: Полная поддержка: установка, настройка, управление клиентами и файрволом (nftables).

Для AmneziaWG: Подготовка всех необходимых конфигурационных файлов и правил файрвола (--dry-run). Установка AmneziaWG выполняется отдельно.

🏗️ Архитектура системы
text
wg-mgr.sh
├── Команды:
│   ├── prepare     → Создает базовый конфигурационный файл (vars4install.conf)
│   ├── install     → Устанавливает WireGuard и настраивает сервер
│   ├── client      → Управление клиентами (add, del, list, count)
│   └── uninstall   → Удаление (в разработке)
│
├── Конфигурационные файлы:
│   ├── vars4install.conf    → Параметры для установки
│   ├── params.conf          → Основные параметры сервера (создается при install)
│   ├── hand_params.conf     → Дополнительные параметры для файрвола (создается при install)
│   └── last-args.conf       → Сохраненные аргументы командной строки
│
└── Шаблоны и скрипты:
    ├── template-server.tmpl → Шаблон для добавления клиента на сервер
    ├── template-client.tmpl → Шаблон для создания конфигурации клиента
    └── apply_rules.sh       → Скрипт для настройки nftables (генерируется из nft.rules.sh)
📂 Конфигурационные файлы
1. vars4install.conf — Параметры для установки
Создается командой prepare. Используется командой install. Содержит переменные с префиксом INST_*.

Переменная	Описание	Пример
INST_SERVER_PUB_NIC	Публичный сетевой интерфейс	ens3
INST_SERVER_PUB_IP	Публичный IP-адрес сервера	192.168.15.41
INST_SERVER_WG_NIC	Имя WireGuard/AmneziaWG интерфейса	awg0
INST_SERVER_WG_IPV4	IPv4-адрес сервера в VPN	10.9.8.1/24
INST_SERVER_WG_IPV6	IPv6-адрес сервера в VPN	fc00:66:66:66::1/64
INST_SERVER_PORT	Порт для подключений	45732
INST_SERVER_PRIV_KEY	Приватный ключ сервера	(генерируется)
INST_SERVER_PUB_KEY	Публичный ключ сервера	(генерируется)
INST_CLIENT_DNS	DNS-серверы для клиентов	1.1.1.1,1.0.0.1
INST_ALLOWED_IPS	Разрешенные IP-сети для клиентов	0.0.0.0/0,::/0
2. params.conf — Основные параметры сервера
Создается командой install. Используется для управления клиентами и файрволом.

Переменная	Описание	Пример
SERVER_PUB_NIC	Публичный интерфейс	ens3
SERVER_PUB_IP	Публичный IP-адрес	45.95.233.101
SERVER_WG_NIC	Имя интерфейса VPN	awg0
SERVER_WG_IPV4	IPv4-адрес сервера	10.9.8.1
SERVER_WG_IPV4_MASK	Маска подсети IPv4	24
SERVER_PORT	Порт сервера	45732
SERVER_PRIV_KEY	Приватный ключ	(скрыт)
SERVER_PUB_KEY	Публичный ключ	(скрыт)
CLIENT_DNS	DNS для клиентов	1.1.1.1,1.0.0.1
ALLOWED_IPS	Разрешенные IP-сети	0.0.0.0/0
3. hand_params.conf — Параметры для файрвола (nftables)
Создается командой install. Используется в apply_rules.sh. Содержит множество настроек для гибкой сегментации сети и безопасности.

Основные переменные:

Переменная	Описание	Пример
SSH_PORT	Порт SSH для защиты от брутфорса	22
WG_PROTO	Протокол VPN (udp для WG/AWG)	udp
WG_NET	VPN-сеть в формате CIDR	10.9.8.0/24
PROVIDER_GW_MAC	MAC-адрес шлюза провайдера (для защиты ARP)	"08:05:e2:fa:07:f0"
NFT_COUNTER	Включает счетчики пакетов в nftables	counter
NFT_NAT_NET	Сети, для которых будет работать NAT	"192.168.15.0/24"
Списки доступа:		
NFT_LIST_TRUST_WAN	Доверенные IP-адреса из WAN (например, для SSH)	'cl.vpn.mrovo.ru'
NFT_LIST_TRUST_VPN	Доверенные IP-адреса из VPN-сети	"10.9.8.2, 192.168.15.202"
NFT_LIST_VPN	Клиенты с доступом в LAN	"10.9.8.3"
NFT_LIST_VPN_ONLY	Клиенты только с доступом в LAN	"10.9.8.4"
NFT_LIST_INET_DROP	Клиенты без доступа в Интернет	"10.9.8.5"
DNS и сервисы:		
NFT_DNS_LOCALNET	DNS-сервер для VPN-клиентов (resolvectl)	192.168.15.3
NFT_SEARCH_DOMAIN_LOCALNET	Домены поиска для VPN-клиентов	"home.lan"
NFT_ALLOWED_SERVICES	Разрешенные сервисы на сервере (для защиты от сканирования)	'tcp . 80, tcp . 443'
DNAT и ACL:		
NFT_MAP_DNAT	Правила DNAT (проброс портов)	"tcp . 443 : 192.168.15.79 . 443"
NFT_MAP_FORWARD_ACL	Правила фильтрации на FORWARD	"192.168.15.79 . tcp . 80 : accept"
🚀 Команды
prepare — Подготовка конфигурации
Автоматически создает файл vars4install.conf с параметрами для установки.

bash
wg-mgr.sh prepare [options]
Опции:

Опция	Описание	Пример
-c, --config <filename>	Имя файла конфигурации	-c awg.conf
-i, --wg-nic <IFACE>	Имя интерфейса	-i awg0
--ip4 <address/mask>	IPv4-адрес сервера	--ip4 10.9.8.1/24
--ip6 <address/mask>	IPv6-адрес сервера	--ip6 fc00::1/64
--dns <list>	DNS-серверы	--dns 8.8.8.8,1.1.1.1
-e, --allowed-ips <list>	Разрешенные IP-сети	-e 0.0.0.0/0,::/0
Примеры:

bash
# Базовый конфиг
wg-mgr.sh prepare -c awg.conf -i awg0 --ip4 10.9.8.1/24
install — Установка WireGuard
Важно: Эта команда устанавливает только WireGuard. Для AmneziaWG используйте --dry-run для генерации файлов.

bash
wg-mgr.sh install [options]
Опции:

Опция	Описание	Пример
-c, --config <filename>	Файл с параметрами установки	-c awg.conf
-i, --wg-nic <IFACE>	Имя интерфейса	-i awg0
-p, --params <filename>	Файл параметров (по умолч. params.conf)	-p params.conf
-d, --hand-params <filename>	Дополнительный конфиг для файрвола	-d hand_params.conf
-t, --option <StringOptions>	Передать параметры в hand_params.conf	-t "SSH_PORT=2222; NFT_LIST_VPN=10.9.8.2"
--dry-run	Пробный запуск (генерация файлов без установки)	--dry-run
--debug	Отладочный вывод	--debug
Примеры:

bash
# Установка WireGuard
wg-mgr.sh install -c awg.conf

# Подготовка файлов для AmneziaWG
wg-mgr.sh install -c awg.conf --dry-run
client — Управление клиентами
Управляет клиентами WireGuard/AmneziaWG.

bash
wg-mgr.sh client [options]
Опции:

Опция	Описание	Пример
-a, --action <action>	Действие: add, del, list, count	-a add
-n, --name <name>	Имя клиента	-n client1
-i, --wg-nic <IFACE>	Имя интерфейса сервера	-i awg0
--ip4 <address/mask>	IPv4-адрес клиента	--ip4 10.9.8.2/24
-k, --keepalive <sec>	PersistentKeepalive для клиентов за NAT	-k 25
-p, --params <filename>	Файл параметров сервера	-p params.conf
Примеры:

bash
# Добавить клиента
wg-mgr.sh client -a add -n client1 -i awg0 --ip4 10.9.8.2/24

# Список клиентов
wg-mgr.sh client -a list -i awg0

# Удалить клиента
wg-mgr.sh client -a del -n client1 -i awg0
🔧 Использование для AmneziaWG
Подготовка конфигурации:

bash
wg-mgr.sh prepare -c awg.conf -i awg0 --ip4 10.9.8.1/24
Генерация всех файлов (без установки):

bash
wg-mgr.sh install -c awg.conf --dry-run --debug
Этот шаг создаст все необходимые файлы: params.conf, hand_params.conf, apply_rules.sh.

Ручная установка AmneziaWG:
Используйте сгенерированные файлы для настройки сервера AmneziaWG и файрвола.

🛡️ Файрвол: apply_rules.sh
Генерируется из шаблона nft.rules.sh во время установки.

Подключается через директивы PostUp/PostDown в конфигурации VPN.

Обеспечивает:

Сегментацию сети с использованием ct mark и списков доступа (NFT_LIST_VPN, NFT_LIST_VPN_ONLY, NFT_LIST_INET_DROP).

Защиту от сканирования портов (бан IP на 24 часа).

Защиту SSH от брутфорса.

DNAT (проброс портов) через NFT_MAP_DNAT.

ACL для FORWARD через NFT_MAP_FORWARD_ACL.

Интеграцию с systemd-resolved для DNS через resolvectl.

🆕 Дополнительные опции: -t, --option
Позволяет передавать параметры прямо из командной строки в hand_params.conf.

Формат: NAME=VALUE (несколько опций разделяются ;).

bash
wg-mgr.sh install -c awg.conf -t "SSH_PORT=2222; NFT_LIST_VPN=\"10.9.8.2, 10.9.8.3\""

⚠️ Важные замечания
Требуются права root — все операции выполняются от root

Поддерживаемые ОС — Debian 10+, Ubuntu 18.04+, Alpine Linux

Виртуализация — OpenVZ не поддерживается, LXC — только с флагом --allow-lxc

IPv6 — поддержка частичная (опция --use-ipv6 не полностью реализована)

nftables — используется через шаблон nft.rules.sh

uninstall — пока не реализован

AmneziaWG — скрипт используется только для подготовки конфигураций с --dry-run

🎯 Заключение
wg-mgr.sh — это профессиональный инструмент для управления VPN-инфраструктурой, который:

✅ Автоматизирует развертывание WireGuard и AmneziaWG.

✅ Предоставляет гибкую систему управления клиентами.

✅ Включает расширенную систему безопасности на основе nftables.

✅ Позволяет гибко настраивать сетевые политики (сегментация, ACL, DNAT).

✅ Используется как для установки WireGuard, так и для подготовки конфигураций AmneziaWG.

This response is AI-generated, for reference only.

