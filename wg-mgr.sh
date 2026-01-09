#!/bin/sh

RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'
DARKBLUE='\033[34m'
PURPLE='\033[35m'
BLUE='\033[36m'

# ARR_CMD=("install" "new" "prepare")
ARR_CMD='install new prepare'

VARS_FOR_INSTALL='./vars4install.conf'
VARS_PARAMS='./params.conf'

DEF_SERVER_WG_NIC=wg0
DEF_SERVER_WG_IPV4=10.66.66.1
DEF_SERVER_WG_IPV4_MASK=24
DEF_SERVER_WG_IPV6=fd42:42:42::1
DEF_SERVER_WG_IPV6_MASK=64
DEF_SERVER_PORT=32124
DEF_CLIENT_DNS_1=1.1.1.1
DEF_CLIENT_DNS_2=1.0.0.1
DEF_ALLOWED_IPS=0.0.0.0/0,::/0

is_debug=0

# path_wg=/etc/wireguard
# path_wg=.
file_sysctl='/etc/sysctl.d/wg.conf'

oi6='[0-9a-fA-F]{1,4}'
ai4='((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])'

show_help() {
    msg "Использование:"
    msg "wg-mgr.sh [command] [options]"
    msg "command (одна из [ ${ARR_CMD} ], по-умолчанию install):"
    msg "    install    - установка пакета wireguard и других, требующихся для работы (iptables, qrencode и др.)"
    msg "        options:"
    msg "            -c, --config <filename> - файл с данными для инсталяции"
    msg " "
    msg "    prepare    - подготовить файл с данными для инсталяции"
    msg "        options:"
    msg "            -c, --config <filename> - файл для подготовки данными для инсталяции"
    msg " "
    msg "    new        - создание клиента и файлов для него: файл настройки для клиента, файл QRcode для клиента"
    msg "        options:"
    msg " "
    msg "common options:"
    msg "    -h, --help                 - описание использования скрипта"
    msg "        --debug                - вывод отладочных сообщений"
    msg "    -o, --out-path <path out>  - путь куда записываются файлы клиента,"
    msg "                                 если команда install, то создать каталог, если его нет"
    msg "                                 если команда new, то создать каталог, если его нет и записать в него файлы для клиента"
    msg "    -p, --params <filename>    - файл с уточненными данными после инсталяции"
    msg "                                 если команда install, то создать файл с этими данными"
    msg "                                 если команда new, то использовать данные из него для создания файлов клиента"
    msg "    -6, --use-ipv6             - использовать IPv6 или нет для настройки локальных адресов WIREGUARD VPN"
    msg "        --dry-run              - команду не выполнять, только показать"
    msg "    -w, --wg-path <path>       - путь к установленному Wireguard"
    msg " "
}

# Вывод всех сообщений
# $1 - текст сообщения
# $2 - цвет, по-умолчанию $ORANGE
msg() {
    [ -z "$1" ] && return
    mess="$@"
    color_b=${2}
    color_b=${color_b:=$ORANGE}
    color_e=${NC}
    # echo -e "${color_b}${mess}${color_e}" >&2
    printf "${color_b}${mess}${color_e}\n" >&2
}

# Вывод отладочной информации
debug() {
    if [ -n "${is_debug+x}" ] && [ "${is_debug}" -ne "0" ]; then
        msg "$@" "$GREEN"
    fi
}

# Вывод ошибок
err() {
    # echo -e "${RED}$@${NC}" >&2
    msg "$@" "${RED}"
}

# Проверить что текущий пользователь root, и если это не так, то прервать выполнение скрипта
check_root() {
    flag_root=$(is_root)
    debug "USER is root: ${flag_root}"
    if [ "${flag_root}" -ne "1" ]; then
        echo -e "${RED}Для запуска этого скрипта необходимо иметь права root.${NC}"
        exit 1
    fi
}

# Вернуть 1, если текущий пользователь root. Иначе вернуть 0
is_root() {
    uid=$(id | sed -En 's/.*uid=([0-9]*).*/\1/p')
    # debug "USER id: ${uid}"
    debug "USER: $(id)"
    if [ "${uid}" -eq "0" ]; then
        # это root
        printf "%d" 1
    else
        # это НЕ root
        printf "%d" 0
    fi
}

# проверить OS:
#   debian >=10
#   raspbian >=10
#   ubuntu >=18.4
#   alpine
check_os() {
	. /etc/os-release
	OS="${ID}"
	if [ "${OS}" = "debian" ] || [ "${OS}" = "raspbian" ]; then
		if [ "${VERSION_ID}" -lt "10" ]; then
			err "Ваша версия Debian (${VERSION_ID}) не поддерживается. Используйте Debian 10 Buster или старше"
			exit 1
		fi
		OS=debian # overwrite if raspbian
	elif [ "${OS}" = "ubuntu" ]; then
		RELEASE_YEAR=$(echo "${VERSION_ID}" | cut -d'.' -f1)
		if [ "${RELEASE_YEAR}" -lt "18" ]; then
			err "Ваша версия Ubuntu (${VERSION_ID}) не поддерживается. Используйте Ubuntu 18.04 or старше"
			exit 1
		fi
	# elif [ -e '/etc/alpine-release' ]; then
    elif [ "${OS}" == "alpine" ]; then
		# OS=alpine
		if ! command -v virt-what >/dev/null; then
            if [ "$is_debug" = "0" ]; then
                if ! (apk update > /dev/null && apk add virt-what > /dev/null); then
                    err "Невозможно установить virt-what. Продолжить без проверки работы на виртуальной машине."
                fi
            else
                if ! (apk update && apk add virt-what); then
                    err "Невозможно установить virt-what. Продолжить без проверки работы на виртуальной машине."
                fi
            fi
		fi
	else
		err "Этот установщик на данный момент поддерживает только Debian, Ubuntu и Alpine"
		exit 1
	fi
    # printf "%s" "${OS}"
}

# Проверить что 
check_virt() {
	# if which virt-what &>/dev/null; then
	if command -v virt-what >/dev/null; then
		# VIRT=$(virt-what)
        # read -ra VIRT <<< "$(virt-what | sed ':a;N;$!ba;s/\n/ /g')"
        VIRT=" $(virt-what | sed ':a;N;$!ba;s/\n/ /g') "
  	else
		# VIRT=$(systemd-detect-virt)
        # read -ra VIRT <<< "$(systemd-detect-virt | sed ':a;N;$!ba;s/\n/ /g')"
        VIRT=" $(systemd-detect-virt | sed ':a;N;$!ba;s/\n/ /g') "
	fi
    # debug "VIRTUAL SYSTEM: ${VIRT[*]}"
    debug "VIRTUAL SYSTEM: ${VIRT}"
	# if [[ " ${VIRT[@]} " =~ "openvz" ]]; then
	# if [[ "${VIRT}" =~ " openvz " ]]; then
    local v_openvz="$(echo "${VIRT}" | sed -rn 's/.*( openvz ).*/\1/p' | sed -n 's/^[[:space:]]*//;s/[[:space:]]*$//p')"
    debug "v_openvz: ${v_openvz}"
	if [ -n "${v_openvz}" ]; then
		err "OpenVZ не поддерживается"
		exit 1
	fi
	# if [[ " ${VIRT[@]} " =~ "lxc" ]]; then
	# if [[ "${VIRT}" =~ " lxc " ]]; then
    local v_lxc="$(echo "${VIRT}" | sed -E 's/.*( lxc ).*/\1/' | sed -n 's/^[[:space:]]*//;s/[[:space:]]*$//p')"
    debug "v_lxc: ${v_lxc}"
	if [ -n "${v_lxc}" ]; then
		err "LXC не поддерживается."
		err "Технически WireGuard может работать в контейнере LXC,"
		err "но есть проблемы с модулями ядра и с настройкой Wireguard в контейнере."
		err "Поэтому не заморачиваемся и пока не реализовано."
		# exit 1
	fi
}

install_packages() {
    ttt="$@"
    # if [ "${dry_run}" -eq "0" ]; then
    if [ -z "${dry_run}" ] || [ "${dry_run}" -eq "0" ]; then
    	if ! "$@"; then
	    	err "Ошибка установки пакетов: '$ttt'"
		    err "Проверьте подключение к интернету и настройки пакетного менеджера."
		    exit 1
        fi
    else
        printf "${PURPLE}Выполнить команду: '${ttt}'${NC}\n" 1>&2
	fi
}

exec_cmd() {
    if [ -z "${dry_run}" ] || [ "${dry_run}" -eq "0" ]; then
        if [ "$is_debug" = "0" ]; then
        	"$@" > /dev/null 2>&1
        else
        	"$@"
        fi
    else
        ttt="$@"
        printf "${PURPLE}Выполнить команду: '${ttt}'${NC}\n" 1>&2
	fi
}

exec_cmd_with_result() {
    local res=''
    if [ -z "${dry_run}" ] || [ "${dry_run}" -eq "0" ]; then
        res=$("$@")
    else
        ttt="$@"
        printf "${PURPLE}Выполнить команду: '${ttt}'${NC}\n" 1>&2
	fi
    printf "${res}"
}

# Проверить что первый символ в строке, заданной в 1-ом аргументе, это символ, который задан во 2-ом аргументе
_startswith() {
  _str="$1"
  _sub="$2"
  echo "$_str" | grep -- "^$_sub" >/dev/null 2>&1
}

_question() {
	# echo -n "${PURPLE}${1}:${NC} "
	# read -r -e -i "${2}" res_var
	read -rp "${1}: " -e -i "${2}" res_var
    printf "%s" "${res_var}"
}

check_ipv4() {
    res=0
    debug "check_ipv4 arg1: ${1}"
    if [ -n "${1}" ]; then
        r=$(echo "${1}" | sed -rn "/(^|\s)$ai4(\s|$)/p")
        if [ -n "$r" ]; then res=1; else res=0; fi
    fi
    debug "check_ipv4 res: ${res}"
    printf "%d" $res
}

check_ipv6() {
    res=0
    debug "check_ipv6 arg1: ${1}"
    if [ -n "${1}" ]; then
        r=$(echo "${1}" | sed -rn "/(^|\s)(($oi6:){7,7}$oi6|($oi6:){1,7}:|($oi6:){1,6}:$oi6|($oi6:){1,5}(:$oi6){1,2}|($oi6:){1,4}(:$oi6){1,3}|($oi6:){1,3}(:$oi6){1,4}|($oi6:){1,2}(:$oi6){1,5}|$oi6:((:$oi6){1,6})|:((:$oi6){1,7}|:)|fe80:(:$oi6){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}$ai4|($oi6:){1,4}:$ai4)($|\s)/p")
        if [ -n "$r" ]; then res=1; else res=0; fi
    fi
    debug "check_ipv6 res: ${res}"
    printf "%d" $res
}

wg_prepare_file_config() {
    debug "wg_prepare_file_config BEGIN"
    # публичный интерфейс сервера
	INST_SERVER_PUB_NIC=$(ip route | grep default | sed -E 's/.*\sdev\s*([a-zA-Z0-9]*)\s.*/\1/')
    # INST_SERVER_PUB_NIC=$(_question "Внешний интерфейс" "${INST_SERVER_PUB_NIC}")
    echo "INST_SERVER_PUB_NIC=${INST_SERVER_PUB_NIC}" > "${file_config}"
    # публичный адрес сервера
    INST_SERVER_PUB_IP=$(ip -4 addr show "$INST_SERVER_PUB_NIC" | sed -nE 's|^.*\sinet\s([^/]*)/.*\sscope global.*$|\1|p') # | awk '{print $1}' | head -1)
    if [ -z "${INST_SERVER_PUB_IP}" ]; then
        INST_SERVER_PUB_IP=$(ip -6 addr show "$INST_SERVER_PUB_NIC" | sed -nE 's|^.*\sinet6\s([^/]*)/.*\sscope global.*$|\1|p')
    fi
    echo "INST_SERVER_PUB_IP=${INST_SERVER_PUB_IP}" >> "${file_config}"
    # WIREGUARD interface NIC
    echo "INST_SERVER_WG_NIC=${DEF_SERVER_WG_NIC}" >> "${file_config}"
    # WIREGUARD SERVER IPv4
    echo "INST_SERVER_WG_IPV4=${DEF_SERVER_WG_IPV4}" >> "${file_config}"
    # WIREGUARD SERVER IPv4 MASK
    echo "INST_SERVER_WG_IPV4_MASK=${DEF_SERVER_WG_IPV4_MASK}" >> "${file_config}"
    # WIREGUARD SERVER IPv6
    echo "INST_SERVER_WG_IPV6=${DEF_SERVER_WG_IPV6}" >> "${file_config}"
    # WIREGUARD SERVER IPv6 MASK
    echo "INST_SERVER_WG_IPV6_MASK=${DEF_SERVER_WG_IPV6_MASK}" >> "${file_config}"
    # WIREGUARD SERVER PORT
	RANDOM_PORT=$(shuf -i49152-65535 -n1)
    echo "INST_SERVER_PORT=${RANDOM_PORT}" >> "${file_config}"
    # PRIVATE and PUBLIC KEY SERVER
    if command -v wg > /dev/null 2>&1; then
        # WIREGUARD SERVER PRIVATE KEY
        _priv_key=$(wg genkey)
        echo "INST_SERVER_PRIV_KEY=${_priv_key}" >> "${file_config}"
        # WIREGUARD SERVER PUBLIC KEY
        debug "PUBLIC_KEY: $(echo ${_priv_key} | wg pubkey)"
        echo "INST_SERVER_PUB_KEY=$(echo ${_priv_key} | wg pubkey)" >> "${file_config}"
    else
        # WIREGUARD SERVER PRIVATE KEY
        echo "INST_SERVER_PRIV_KEY=" >> "${file_config}"
        # WIREGUARD SERVER PUBLIC KEY
        echo "INST_SERVER_PUB_KEY=" >> "${file_config}"
    fi
    # FIRST DNS FOR CLIENT 
    echo "INST_CLIENT_DNS_1=${DEF_CLIENT_DNS_1}" >> "${file_config}"
    # SECOND DNS FOR CLIENT 
    echo "INST_CLIENT_DNS_2=${DEF_CLIENT_DNS_2}" >> "${file_config}"
    # Разрешенные адреса для клиента
    echo "INST_ALLOWED_IPS=${DEF_ALLOWED_IPS}" >> "${file_config}"
    [ "$is_debug" -ne "0" ] && {
        cat "${file_config}" | while read line; do
            if [ -n "$(echo ${line} | grep INST_SERVER_PRIV_KEY)" ]; then
                debug "INST_SERVER_PRIV_KEY=[inst_server_priv_key]"
            elif [ -n "$(echo ${line} | grep INST_SERVER_PUB_KEY)" ]; then
                debug "INST_SERVER_PUB_KEY=[inst_server_pub_key]"
            else
                debug "$line"
            fi
        done
    }
    
    debug "wg_prepare_file_config END"
}

wg_install() {
    debug "wg_install BEGIN"
    # debug "file_config__: ${file_config}"
    # debug "file_params__: ${file_params}"
    # debug "${OS}"

    debug "file_config: ${file_config}"
    debug "pwd: $(pwd)"
    . "${file_config}" # > /dev/null #2>&1
    debug "wg_install BEGIN"
    # публичный интерфейс сервера
    if [ -z "${INST_SERVER_PUB_NIC}" ]; then
        # grep default | sed -E 's/.*\sdev\s*([^\s]*).*/\1/'
        # sed -E 's/.*\sdev\s*([a-zA-Z0-9]*)\s.*/\1/'
	    INST_SERVER_PUB_NIC=$(ip route | grep default | sed -E 's/.*\sdev\s*([a-zA-Z0-9]*)\s.*/\1/')
        INST_SERVER_PUB_NIC=$(_question "Внешний интерфейс" "${INST_SERVER_PUB_NIC}")
    fi
    if ! ip link | grep -e ".*\s${INST_SERVER_PUB_NIC}" >/dev/null 2>&1; then
        err "В файле ${file_config} или при вводе указан не верный внешний интерфейс ${INST_SERVER_PUB_NIC}";
        exit 1
    fi
    # публичный адрес сервера
    [ -z "${INST_SERVER_PUB_IP}" ] && {
    	INST_SERVER_PUB_IP=$(ip -4 addr show "$INST_SERVER_PUB_NIC" | sed -nE 's|^.*\sinet\s([^/]*)/.*\sscope global.*$|\1|p') # | awk '{print $1}' | head -1)
        if [ -z "${INST_SERVER_PUB_IP}" ]; then
            INST_SERVER_PUB_IP=$(ip -6 addr show "$INST_SERVER_PUB_NIC" | sed -nE 's|^.*\sinet6\s([^/]*)/.*\sscope global.*$|\1|p')
        fi
        title_quest="Публичный IPv4 или IPv6 сервера"
        INST_SERVER_PUB_IP=$(_question "${title_quest}" "$INST_SERVER_PUB_IP")
    }
    if [ -z "${INST_SERVER_PUB_IP}" ] ||
        (
            [ "$(check_ipv4 ${INST_SERVER_PUB_IP})" -eq "0" ] && [ "$(check_ipv6 ${INST_SERVER_PUB_IP})" -eq "0" ]
        )
    then
        err "В файле ${file_config} или при вводе указан не верный внешний IP адрес ${INST_SERVER_PUB_IP}";
        exit 1
    fi
    # имя интерфейса сервера WIREGUARD
    if [ -z "${INST_SERVER_WG_NIC}" ]; then
        INST_SERVER_WG_NIC=$(_question "Имя интерфейса сервера wireguard" "${DEF_SERVER_WG_NIC}")
    fi
    # IPv4 интерфейса сервера
    if [ -z "${INST_SERVER_WG_IPV4}" ]; then
        INST_SERVER_WG_IPV4=$(_question "IPv4 адрес интерфейса сервера wireguard" "${DEF_SERVER_WG_IPV4}")
    fi
    # Маска IPv4 интерфейса сервера
    if [ -z "${INST_SERVER_WG_IPV4_MASK}" ]; then
        INST_SERVER_WG_IPV4_MASK=$(_question "Маска IPv4 адреса интерфейса сервера wireguard" "${DEF_SERVER_WG_IPV4_MASK}")
    fi
    # IPv6 интерфейса сервера
    if [ "${use_ipv6}" -ne "0" ]; then
        if [ -z "${INST_SERVER_WG_IPV6}" ]; then
            INST_SERVER_WG_IPV6=$(_question "IPv4 адреса интерфейса сервера wireguard" "${DEF_SERVER_WG_IPV6}")
        fi
    else
        INST_SERVER_WG_IPV6=''
    fi
    # Маска IPv6 интерфейса сервера
    if [ "${use_ipv6}" -ne "0" ]; then
        if [ -z "${INST_SERVER_WG_IPV6_MASK}" ]; then
            INST_SERVER_WG_IPV6_MASK=$(_question "Длина префикса IPv6 адреса интерфейса сервера wireguard" "${DEF_SERVER_WG_IPV6_MASK}")
        fi
    else
        INST_SERVER_WG_IPV6_MASK=''
    fi
    # порт сервера WIREGUARD
    if [ -z "${INST_SERVER_PORT}" ]; then
        INST_SERVER_PORT=$(_question "Порт сервера wireguard" "${DEF_SERVER_PORT}")
    fi
    # Private key сервера
    # INST_SERVER_PRIV_KEY=wireguatd private key
    # Public key сервера
    # INST_SERVER_PUB_KEY=wireguatd public key
    # DNS первый для клиента
    if [ -z "${INST_CLIENT_DNS_1}" ]; then
        INST_CLIENT_DNS_1=$(_question "Первый DNS для клиентов" "${DEF_CLIENT_DNS_1}")
    fi
    # DNS второй для клиента
    if [ -z "${INST_CLIENT_DNS_2}" ]; then
        INST_CLIENT_DNS_2=$(_question "Второй DNS для клиентов" "${DEF_CLIENT_DNS_2}")
    fi
    # Разрешенные адреса для клиента
    # INST_ALLOWED_IPS=allowed address
    if [ -z "${INST_ALLOWED_IPS}" ]; then
        INST_ALLOWED_IPS=$(_question "Второй DNS для клиентов" "${DEF_ALLOWED_IPS}")
    fi
    # отладка подготовленных данных
    debug "INST_SERVER_PUB_NIC: ${INST_SERVER_PUB_NIC}"
    debug "INST_SERVER_PUB_IP: ${INST_SERVER_PUB_IP}"
    debug "INST_SERVER_WG_NIC: ${INST_SERVER_WG_NIC}"
    debug "INST_SERVER_WG_IPV4: ${INST_SERVER_WG_IPV4}"
    debug "INST_SERVER_WG_IPV4_MASK: ${INST_SERVER_WG_IPV4_MASK}"
    debug "INST_SERVER_WG_IPV6: ${INST_SERVER_WG_IPV6}"
    debug "INST_SERVER_WG_IPV6_MASK: ${INST_SERVER_WG_IPV6_MASK}"
    debug "INST_SERVER_PORT: ${INST_SERVER_PORT}"
    if [ -z "${INST_SERVER_PRIV_KEY}" ]; then
        debug "INST_SERVER_PRIV_KEY:"
    else
        debug "INST_SERVER_PRIV_KEY: INST_SERVER_PRIV_KEY"
    fi
    if [ -z "${INST_SERVER_PUB_KEY}" ]; then
        debug "INST_SERVER_PUB_KEY:"
    else
        debug "INST_SERVER_PUB_KEY: INST_SERVER_PUB_KEY"
    fi
    debug "INST_CLIENT_DNS_1: ${INST_CLIENT_DNS_1}"
    debug "INST_CLIENT_DNS_2: ${INST_CLIENT_DNS_2}"
    debug "INST_ALLOWED_IPS: ${INST_ALLOWED_IPS}"
    # установка WIREGUARD
    if [ "${OS}" = 'ubuntu' ] || ([ "${OS}" = 'debian' ] && [ "${VERSION_ID}" -gt "10" ]); then
        # apt update > /dev/null 2>&1
        exec_cmd apt update
        install_packages apt install -y wireguard iptables systemd-resolved qrencode
    elif [ "${OS}" = 'alpine' ]; then
		# apk update > /dev/null 2>&1
		exec_cmd apk update
		install_packages apk add wireguard-tools iptables libqrencode-tools
    fi
	# Проверить что WireGuard установлен
    is_wg_install=$(command -v wg)
    # if ! command -v wg &>/dev/null; then
    if [ -z "${is_wg_install}" ]; then
        err "WireGuard не установлен. Отсутствует команда 'wg'."
        err "Проверьте вывод программы установки на наличие ошибок."
        if [ -z "${dry_run}" ] || [ "${dry_run}" -eq "0" ]; then
            exit 1
        else
            err "В режиме dry-run программа продолжает работу."
        fi
    fi
	# # Make sure the directory exists (this does not seem the be the case on fedora)
	# mkdir /etc/wireguard >/dev/null 2>&1
	# chmod 600 -R /etc/wireguard/
    # Создать приватный и публичный ключи, если их нет
    if [ -z "${INST_SERVER_PRIV_KEY}" ]; then
        if [ -z "${is_wg_install}" ]; then
            # wg не установлен
            err "Требуется выполнить команду: INST_SERVER_PRIV_KEY=\$\(wg genkey\)"
            err "Но WIREGUARD не установлен."
            if [ -z "${dry_run}" ] || [ "${dry_run}" -eq "0" ]; then
                exit 1
            else
                err "В режиме dry-run программа продолжает работу."
            fi
        else
            # wg установлен
            INST_SERVER_PRIV_KEY=$(exec_cmd_with_result wg genkey)
        fi
    fi
    if [ -z "${is_wg_install}" ]; then
        # wg не установлен
        err "Требуется выполнить команду: INST_SERVER_PUB_KEY=\$\(echo "${INST_SERVER_PRIV_KEY}" | wg pubkey\)"
        err "Но WIREGUARD не установлен."
        if [ -z "${dry_run}" ] || [ "${dry_run}" -eq "0" ]; then
            exit 1
        else
            err "В режиме dry-run программа продолжает работу."
        fi
    else
        # wg установлен
        INST_SERVER_PUB_KEY=$(echo "${INST_SERVER_PRIV_KEY}" | wg pubkey 2>/dev/null)
        # INST_SERVER_PUB_KEY=$(echo "${INST_SERVER_PRIV_KEY}" | wg pubkey)
    fi

	# Сохранить параметры WireGuard
	echo "SERVER_PUB_NIC=${INST_SERVER_PUB_NIC}" > "${file_params}"
	echo "SERVER_PUB_IP=${INST_SERVER_PUB_IP}" >> "${file_params}"
	echo "SERVER_WG_NIC=${INST_SERVER_WG_NIC}" >> "${file_params}"
	echo "SERVER_WG_IPV4=${INST_SERVER_WG_IPV4}" >> "${file_params}"
	echo "SERVER_WG_IPV4_MASK=${INST_SERVER_WG_IPV4_MASK}" >> "${file_params}"
	echo "SERVER_WG_IPV6=${INST_SERVER_WG_IPV6}" >> "${file_params}"
	echo "SERVER_WG_IPV6_MASK=${INST_SERVER_WG_IPV6_MASK}" >> "${file_params}"
	echo "SERVER_PORT=${INST_SERVER_PORT}" >> "${file_params}"
	echo "SERVER_PRIV_KEY=${INST_SERVER_PRIV_KEY}" >> "${file_params}"
	echo "SERVER_PUB_KEY=${INST_SERVER_PUB_KEY}" >> "${file_params}"
	echo "CLIENT_DNS_1=${INST_CLIENT_DNS_1}" >> "${file_params}"
	echo "CLIENT_DNS_2=${INST_CLIENT_DNS_2}" >> "${file_params}"
	echo "ALLOWED_IPS=${INST_ALLOWED_IPS}" >> "${file_params}"
    . "${file_params}"
    debug "SERVER_PUB_NIC: ${SERVER_PUB_NIC}"
    debug "SERVER_PUB_IP: ${SERVER_PUB_IP}"
    debug "SERVER_WG_NIC: ${SERVER_WG_NIC}"
    debug "SERVER_WG_IPV4: ${SERVER_WG_IPV4}"
    debug "SERVER_WG_IPV4_MASK: ${SERVER_WG_IPV4_MASK}"
    debug "SERVER_WG_IPV6: ${SERVER_WG_IPV6}"
    debug "SERVER_WG_IPV6_MASK: ${SERVER_WG_IPV6_MASK}"
    debug "SERVER_PORT: ${SERVER_PORT}"
    debug "SERVER_PRIV_KEY: INST_SERVER_PRIV_KEY"
    debug "SERVER_PUB_KEY: ${SERVER_PUB_KEY}"
    debug "CLIENT_DNS_1: ${CLIENT_DNS_1}"
    debug "CLIENT_DNS_2: ${CLIENT_DNS_2}"
    debug "ALLOWED_IPS: ${ALLOWED_IPS}"

	# Включить форвардинг на сервере
	echo "net.ipv4.ip_forward = 1" > "${file_sysctl}"
    echo "net.ipv6.conf.all.forwarding = 1" >> "${file_sysctl}"
	# Файл конфигурации WIREGUARD
    local file_conf_wg="${path_wg}/${SERVER_WG_NIC}.conf"
	echo "[Interface]" > "${file_conf_wg}"
    echo "Address = ${SERVER_WG_IPV4}/24,${SERVER_WG_IPV6}/64" >> "${file_conf_wg}"
    echo "ListenPort = ${SERVER_PORT}" >> "${file_conf_wg}"
    echo "PrivateKey = ${SERVER_PRIV_KEY}" >> "${file_conf_wg}"
    # права на файл конфигурации
    chmod 0700 "${path_wg}"
    chmod 0600 "${file_conf_wg}"
 
    if [ "${OS}" = "alpine" ]; then
		exec_cmd sysctl -p /etc/sysctl.d/wg.conf
		exec_cmd rc-update add sysctl
		exec_cmd ln -s /etc/init.d/wg-quick "/etc/init.d/wg-quick.${SERVER_WG_NIC}"
		exec_cmd rc-service "wg-quick.${SERVER_WG_NIC}" start
		exec_cmd rc-update add "wg-quick.${SERVER_WG_NIC}"
    else
        exec_cmd sysctl --system
		exec_cmd systemctl start "wg-quick@${SERVER_WG_NIC}"
		exec_cmd systemctl enable "wg-quick@${SERVER_WG_NIC}"
    fi
    # работа с настройками для iptables
    

    echo "INST_SERVER_PRIV_KEY --- $INST_SERVER_PRIV_KEY"
    echo "INST_SERVER_PUB_KEY --- $INST_SERVER_PUB_KEY"
    exit

    debug "wg_install END"
}

main() {
    if [ -z "$1" ]; then
        # show_help
        cmd=install
    elif _startswith "$1" "-"; then
        cmd=install
    else
        cmd="$1"
        shift
    fi
    # echo $@
    # if [[ ! " ${ARR_CMD[@]} " =~ " ${cmd} " ]]; then
    # if [[ ! " ${ARR_CMD} " =~ " ${cmd} " ]]; then
    local l_cmd=$(echo " ${ARR_CMD} " | sed -rn "s/.*( $cmd ).*/\1/p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    # debug "_${ARR_CMD}_"
    # debug "_${l_cmd}_"
    if [ -z " ${l_cmd}" ]; then
        err "Неверная команда: ${cmd}"
        show_help
        exit 1
    fi
    while [ ${#} -gt 0 ]; do
        case "${1}" in
        -c | --config)
            file_config="$2"
            shift
            ;;
        -p | --params)
            file_params="$2"
            shift
            ;;
        -o | --out-path)
            path_out="$2"
            shift
            ;;
        -w | --wg-path)
            path_wg="$2"
            shift
            ;;
        --debug)
            is_debug='1'
            ;;
        -h | --help)
            show_help
            exit 0
            ;;
        -6 | --use-ipv6)
            use_ipv6='1'
            ;;
        --dry-run)
            dry_run='1'
            ;;
        *)
            err "Неверный параметр: ${1}"
            return 1
            ;;
        esac

        shift 1
    done
    is_debug=${is_debug:=0}
    cmd=${cmd:=install}
    file_config=${file_config:="$VARS_FOR_INSTALL"}
    file_config=$([ -z $(echo "${file_config}" | grep '/') ] && echo "./${file_config}" || echo "${file_config}")
    file_params=${file_params:="$VARS_PARAMS"}
    path_wg=${path_wg:='/etc/wireguard'}
    path_out=${path_out:="${path_wg}/.clients"}
    use_ipv6=${use_ipv6:=0}
    dry_run=${dry_run:=0}

    debug "main BEGIN"
    # echo "cmd: ${cmd}"
    # echo "is_debug: ${is_debug}"
    debug "cmd__________: ${cmd}"
    debug "is_debug_____: ${is_debug}"
    debug "file_config__: ${file_config}"
    debug "file_params__: ${file_params}"
    debug "use_ipv6: ${use_ipv6}"
    debug "dry_run: ${dry_run}"
    
    #
    debug "pwd: $(pwd)"
    case "$cmd" in
        "install")
        # Проверить что из под root и в противном случае прервать выполнение
        check_root
        # Проверить что выполняется в поддерживаемой OS и в противном случае прервать выполнение
        check_os
        # Проверить что выполняется в поддерживаемой системе виртуализации и в противном случае прервать выполнение
        check_virt
        wg_install
        ;;
    "new")
        debug "New client"
        ;;
    "prepare")
        wg_prepare_file_config
        ;;
    *)
        err "Неверная команда: ${cmd}"
        show_help
        ;;
    esac

    debug "main END"
}

# ps -p $$
# ps
# msg "GREEN$SHELL$NC"
# echo -e "GREEN$SHELL$NC"
# echo -e "GREEN$0$NC"
# msg "rewq"
# exit

main $@
