#!/bin/bash

RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

ARR_CMD=("install" "new")
# is_debug=0

VARS_FOR_INSTALL=./vars4install.conf
VARS_PARAMS=./params.conf

function show_help() {
    msg "Использование:"
    msg "wg-mgr.sh [command] [options]"
    msg "command (одна из [ ${ARR_CMD[*]} ], по-умолчанию install):"
    msg "    install    - установка пакета wireguard и других, требующихся для работы (iptables, qrencode и др.)"
    msg "        options:"
    msg "            -c, --config       - файл с данными для инсталяции"
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
    msg "    -p, --params               - файл с уточненными данными после инсталяции"
    msg "                                 если команда install, то создать файл с этими данными"
    msg "                                 если команда new, то использовать данные из него для создания файлов клиента"
}

# Вывод всех сообщений
# $1 - текст сообщения
# $2 - цвет, по-умолчанию $ORANGE
function msg() {
    [ -z "$1" ] && return
    mess="$1"
    color_b=${2}
    color_b=${color_b:=$ORANGE}
    color_e=${NC}
    echo -e "${color_b}${mess}${color_e}" >&2
    # printf "%d"  "${color_b}${mess}${color_e}\n" >&2
}

# Вывод отладочной информации
function debug() {
    if [ "$is_debug" -ne 0 ]; then
        msg "$@" "$GREEN"
    fi
}

# Вывод ошибок
function _err() {
    # echo -e "${RED}$@${NC}" >&2
    msg "$@" "${RED}"
}

# Проверить что текущий пользователь root, и если это не так, то прервать выполнение скрипта
function check_root() {
    flag_root=$(is_root)
    debug "USER is root: ${flag_root}"
    if [ "${flag_root}" -ne 1 ]; then
        echo -e "${RED}Для запуска этого скрипта необходимо иметь права root.${NC}"
        exit 1
    fi
}

# Вернуть 1, если текущий пользователь root. Иначе вернуть 0
function is_root() {
    uid=$(id | sed -En 's/.*uid=([0-9]*).*/\1/p')
    # debug "USER id: ${uid}"
    debug "USER: $(id)"
    if [ "${uid}" -eq 0 ]; then
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
function check_os() {
	source /etc/os-release
	OS="${ID}"
	if [[ ${OS} == "debian" || ${OS} == "raspbian" ]]; then
		if [[ ${VERSION_ID} -lt 10 ]]; then
			echo "Ваша версия Debian (${VERSION_ID}) не поддерживается. Используйте Debian 10 Buster или старше"
			exit 1
		fi
		OS=debian # overwrite if raspbian
	elif [[ ${OS} == "ubuntu" ]]; then
		RELEASE_YEAR=$(echo "${VERSION_ID}" | cut -d'.' -f1)
		if [[ ${RELEASE_YEAR} -lt 18 ]]; then
			echo "Ваша версия Ubuntu (${VERSION_ID}) не поддерживается. Используйте Ubuntu 18.04 or старше"
			exit 1
		fi
	# elif [[ -e /etc/alpine-release ]]; then
    elif [[ ${OS} == "alpine" ]]; then
		# OS=alpine
		if ! command -v virt-what &>/dev/null; then
			if ! (apk update && apk add virt-what); then
				_err "Невозможно установить virt-what. Продолжить без проверки работы на виртуальной машине."
			fi
		fi
	else
		echo "Этот установщик на данный момент поддерживает только Debian и Ubuntu"
		exit 1
	fi
    # printf "%s" "${OS}"
}

# Проверить что 
function check_virt() {
    # a=$(virt-what | sed ':a;N;$!ba;s/\n/ /g');  read -ra arr <<< "$a"; echo "${#arr[@]}"
	if command -v virt-what &>/dev/null; then
		# VIRT=$(virt-what)
        read -ra VIRT <<< "$(virt-what | sed ':a;N;$!ba;s/\n/ /g')"
  	else
		# VIRT=$(systemd-detect-virt)
        read -ra VIRT <<< "$(systemd-detect-virt | sed ':a;N;$!ba;s/\n/ /g')"
	fi
    debug "VIRTUAL SYSTEM: ${VIRT[*]}"
	# if [[ ${VIRT} =~ "openvz" ]]; then
	if [[ " ${VIRT[@]} " =~ "openvz" ]]; then
		err "OpenVZ не поддерживается"
		exit 1
	fi
	if [[ " ${VIRT[@]} " =~ "lxc" ]]; then
		_err "LXC не поддерживается."
		_err "Технически WireGuard может работать в контейнере LXC,"
		_err "но есть проблемы с модулями ядра и с настройкой Wireguard в контейнере."
		_err "Поэтому не заморачиваемся и пока не реализовано."
		exit 1
	fi
}

# Проверить что первый символ в строке, заданной в 1-ом аргументе, это символ, который задан во 2-ом аргументе
_startswith() {
  _str="$1"
  _sub="$2"
  echo "$_str" | grep -- "^$_sub" >/dev/null 2>&1
}


# function installPackages() {
#   if ! "$@"; then
#     echo -e "${RED}Failed to install packages.${NC}"
#     echo "Please check your internet connection and package sources."
#     exit 1
#   fi
# }


#debug $(_get_is_root)
function _question_() {
	read -rp "IPv4 or IPv6 public address: " -e -i "${SERVER_PUB_IP}" SERVER_PUB_IP
}

function install_wg() {
    debug "install_wg BEGIN"
    # debug "file_config__: ${file_config}"
    # debug "file_params__: ${file_params}"
    # debug "${OS}"

    source "${file_config}" > /dev/null 2>&1
    # INST_SERVER_PUB_NIC=nameIFACE
    # INST_SERVER_PUB_IP=IPv4 or IPv6
    # INST_SERVER_WG_NIC=wireguard IFACE
    # INST_SERVER_WG_IPV4=IPv4 wireguard server
    # INST_SERVER_WG_IPV6=IPv6 wireguard server
    # INST_SERVER_PORT=wireguard port
    # INST_SERVER_PRIV_KEY=wireguatd private key
    # INST_SERVER_PUB_KEY=wireguatd public key
    # INST_CLIENT_DNS_1=DNS client 1
    # INST_CLIENT_DNS_2=DNS client 2
    # INST_ALLOWED_IPS=allowed address
    # публичный интерфейс сервера
    [[ -z ${INST_SERVER_PUB_NIC} ]] && {
        # grep default | sed -E 's/.*\sdev\s*([^\s]*).*/\1/'
        # sed -E 's/.*\sdev\s*([a-zA-Z0-9]*)\s.*/\1/'
	    INST_SERVER_PUB_NIC=$(ip route | grep default | sed -E 's/.*\sdev\s*([a-zA-Z0-9]*)\s.*/\1/')
    }
    # публичный адрес сервера
    [[ -z ${INST_SERVER_PUB_IP} ]] && {
	SERVER_PUB_IP=$(ip -4 addr | sed -ne 's|^.* inet \([^/]*\)/.* scope global.*$|\1|p' | awk '{print $1}' | head -1)
        INST_SERVER_PUB_IP=$(_question_ "Публичный IPv4 сервера: " )
    }
    debug "INST_SERVER_PUB_NIC: ${INST_SERVER_PUB_NIC}"
    debug "INST_SERVER_PUB_IP: ${INST_SERVER_PUB_IP}"
    debug "install_wg END"
}

function main() {
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
    if [[ ! " ${ARR_CMD[@]} " =~ " ${cmd} " ]]; then
        _err "Неверная команда: ${cmd}"
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
        --debug)
            is_debug=1
            ;;
        -h | --help)
            show_help
            exit 0
            ;;
        *)
            _err "Неверный параметр: ${1}"
            return 1
            ;;
        esac

        shift 1
    done
    is_debug=${is_debug:=0}
    cmd=${cmd:=install}
    file_config=${file_config:="$VARS_FOR_INSTALL"}
    file_params=${file_params:="$VARS_PARAMS"}
    debug "main BEGIN"
    # echo "cmd: ${cmd}"
    # echo "is_debug: ${is_debug}"
    debug "cmd__________: ${cmd}"
    debug "is_debug_____: ${is_debug}"
    debug "file_config__: ${file_config}"
    debug "file_params__: ${file_params}"
    
    debug "OS: ${OS}"
    debug "flag_root: ${flag_root}"

    # debug "$(is_root)"
    # Проверить что из под root и в противном случае прервать выполнение
    check_root
    # Проверить что выполняется в поддерживаемой OS и в противном случае прервать выполнение
    check_os
    # Проверить что выполняется в поддерживаемой системе виртуализации и в противном случае прервать выполнение
    check_virt
    #
    case "$cmd" in
    "install")
        install_wg
        ;;
    "new")
        ;;
    *)
        _err "Неверная команда: ${cmd}"
        show_help
        ;;
    esac

    debug "main END"
}

main $@


