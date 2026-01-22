#!/bin/sh

RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'
DARKBLUE='\033[34m'
PURPLE='\033[35m'
BLUE='\033[36m'

OS_RELEASE="/etc/os-release"
# ARR_CMD=("install" "uninstall" "new" "prepare")
ARR_CMD='install uninstall client prepare'
ACTION_CLIENT='a add new d del delete list l'

VARS_FOR_INSTALL="./vars4install.conf"
VARS_PARAMS="./params.conf"

DEF_SERVER_WG_NIC=wg0
DEF_SERVER_WG_IPV4=10.66.66.1
DEF_SERVER_WG_IPV4_MASK=24
DEF_SERVER_WG_IPV6=fc00:66:66:66::1
DEF_SERVER_WG_IPV6_MASK=64
DEF_SERVER_PORT=32124
DEF_CLIENT_DNS_1=1.1.1.1
DEF_CLIENT_DNS_2=1.0.0.1
DEF_ALLOWED_IPS=0.0.0.0/0,::/0

is_debug=0
allow_lxc=1

# path_wg=/etc/wireguard
# path_wg=.
file_sysctl='/etc/sysctl.d/wg.conf'
def_file_hand_params="./hand_params.conf"
def_file_args='./last-args'
is_file_args=''

oi6='[0-9a-fA-F]{1,4}'
ai4='((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])'

show_help() {
    # -c -r -p -d -h -o -6 -w -f -u -a -l -n
    msg "Использование:"
    msg "wg-mgr.sh [command] [options]"
    msg "command (одна из [ ${ARR_CMD} ], по-умолчанию install):"
    msg "    install    - установка пакета wireguard и других, требующихся для работы (iptables, qrencode и др.)"
    msg "        options:"
    msg "            -c, --config <filename>        - файл с данными для инсталяции"
    msg "            -r, --rules-iptables <filename>- файл с правилами iptables (ip6tables)"
    msg "            -p, --params <filename>        - создается файл с уточненными данными после инсталяции"
    msg "            -d, --hand-params <filename>   - файл созданный вручную для определения дополнительных переменных"
    msg " "
    msg "    uninstall  - удаление пакета wireguard и других, установленных вместе с ним, а также удалить все созданные каталоги и файлы"
    msg " "
    msg "    prepare    - подготовить файл с данными для инсталяции"
    msg "        options:"
    msg "            -c, --config <filename> - файл для подготовки данных для инсталяции"
    msg " "
    msg "    client     - работа с клиентами: добавить, удалить, получить список"
    msg "        options:"
    msg "            -a, --action <action>          - указывает что делать: создать клиента, удалить клиента или получить список клиентов"
    msg "                                             значение должно быть из ACTION_CLIENT (add, del, list)"
    msg "                          a | add | new   :  создать файлы настроек для клиента на сервере и клиенте, файл QRcode для клиента"
    msg "                          d | del | delete:  удалить клиента из файла настроек сервера"
    msg "                          l | list        :  получить список клиентов из файла настроек сервера"
    msg "            -p, --params <filename>        - созданный при install файл с уточненными данными используется для создания файлов клиента"
    msg "            -d, --hand-params <filename>   - файл созданный вручную для определения дополнительных переменных для настройки клиентов"
    msg "                --ip4 <address/mask>       - ipv4 адрес с маской клиента"
    msg "                --ip6 <address/mask>       - ipv6 адрес с маской клиента"
    msg "            -e, --allowed-ips <network>    - список ip адресов, которым разрешен доступ в формате 1.1.1.0/24,fdoo::0/64,2.2.2.2/32"
    msg "                                             по-умолчанию только адрес клиента"
    msg "            -n, --name <name client>       - имя клиента"
    msg " "
    msg "common options:"
    msg "    -h, --help                 - описание использования скрипта"
    msg "        --debug                - вывод отладочных сообщений"
    msg "    -o, --out-path <path out>  - путь куда записываются файлы клиента,"
    msg "                                 если команда install, то создать каталог, если его нет"
    msg "                                 если команда new, то создать каталог, если его нет и записать в него файлы для клиента"
    msg "    -6, --use-ipv6             - использовать IPv6 или нет для настройки локальных адресов WIREGUARD VPN. НЕ РЕАЛИЗОВАНО (пока)"
    msg "        --dry-run              - команду не выполнять, только показать"
    msg "    -w, --wg-path <path>       - путь к установленному Wireguard"
    msg "    -f, --file-args <path>     - путь к файлу где хранятся аргументы для командной строки"
    msg "    -u, --update-args          - флаг, что надо обновить файл с аргументами соответственно текущим аргументам командной строки"
    msg " "
}

# Вывод всех сообщений
# $1 - текст сообщения
# $2 - цвет, по-умолчанию $ORANGE
msg() {
    [ -z "$1" ] && return
    local mess="$@"
    color_b=${2}
    color_b=${color_b:=$ORANGE}
    color_e=${NC}
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
    msg "$@" "${RED}"
}

set_var() {
    local vn="$1"
    if [ -z "$3" ]; then
        eval "${vn}=\"${2}\""
    else
        eval "${vn}=\"${3}\""
    fi
}

# Проверить что текущий пользователь root, и если это не так, то прервать выполнение скрипта
check_root() {
    if is_root > /dev/null 2>&1; then
        debug "USER is root: YES"
    else
        err "Для запуска этого скрипта необходимо иметь права root."
        exit 1
    fi
}

# Вернуть в $? 0, если текущий пользователь root. Иначе вернуть 1
is_root() {
    local uid=$(id | sed -En 's/^.*uid=([0-9]*).*$/\1/p')
    debug "USER id: ${uid}"
    debug "USER: $(id)"
    if [ "${uid}" -eq "0" ]; then
        # это root
        return 0
    else
        # это НЕ root
        return 1
    fi
}

# проверить OS:
#   debian >=10
#   raspbian >=10
#   ubuntu >=18.4
#   alpine
check_os() {
    debug "check_os BEGIN ==================="
    debug "check_os args: $@"
    debug "check_os args: $@"
    if [ -z "$@" ] || [ "${1}" = "0" ]; then
        # выводить сообщение как ошибку, красным цветом
        local is_out_err=0
    elif [ "${1}" = "1" ]; then
        # выводить сообщение как предупреждение, оранжевым цветом
        local is_out_err=1
    elif [ "${1}" = "2" ]; then
        # НЕ выводить сообщение вообще
        local is_out_err=2
    else
        local is_out_err=0
    fi
    local res_exit=0
	. "${OS_RELEASE}"
	OS="${ID}"
	if [ "${OS}" = "debian" ] || [ "${OS}" = "raspbian" ]; then
		if [ "${VERSION_ID}" -lt "10" ]; then
            local _msg_="Ваша версия Debian (${VERSION_ID}) не поддерживается. Используйте Debian 10 Buster или старше"
            if [ "${is_out_err}" -eq "0" ]; then
			    err "${_msg_}"
            elif [ "${is_out_err}" -eq "1" ]; then
			    msg "${_msg_}"
            fi
			# exit 1
            local res_exit=1
		fi
		OS=debian # overwrite if raspbian
	elif [ "${OS}" = "ubuntu" ]; then
		RELEASE_YEAR=$(echo "${VERSION_ID}" | cut -d'.' -f1)
		if [ "${RELEASE_YEAR}" -lt "18" ]; then
			local _msg_="Ваша версия Ubuntu (${VERSION_ID}) не поддерживается. Используйте Ubuntu 18.04 or старше"
            if [ "${is_out_err}" -eq "0" ]; then
			    err "${_msg_}"
            elif [ "${is_out_err}" -eq "1" ]; then
			    msg "${_msg_}"
            fi
			# exit 1
            local res_exit=1
		fi
	# elif [ -e '/etc/alpine-release' ]; then
    elif [ "${OS}" == "alpine" ]; then
		# OS=alpine
        # установить требуемые пакеты
        # проверить что установлен coreutils
        if apk list --installed | grep coreutils > /dev/null; then
            local list_packet=''
        else
            local list_packet='coreutils'
        fi
        # проверить что установлен virt-what
        if ! command -v virt-what >/dev/null; then
                local list_packet="${list_packet} virt-what"
        fi
        if ! command -v virt-what >/dev/null; then
            if [ "$is_debug" = "0" ]; then
                if ! (apk update > /dev/null && apk add ${list_packet} > /dev/null); then
                    err "Невозможно установить пакеты ${list_packet}."
                    local res_exit=1
                fi
            else
                if ! (apk update && apk add ${list_packet}); then
                    err "Невозможно установить пакеты ${list_packet}."
                    local res_exit=1
                fi
            fi
		fi
	else
		local _msg_="Этот установщик на данный момент поддерживает только Debian, Ubuntu и Alpine"
        err "${_msg_}"
        # exit 1
        local res_exit=1
	fi
    debug "OS: ${OS}"
    debug "VERSION_ID: ${VERSION_ID}"
    debug "res_exit: ${res_exit}"
    debug "check_os END ====================="
    printf "%s" "id=${OS}; version_id=${VERSION_ID}"
    return ${res_exit}
}

# Проверить что допустимые виртуалки
check_virt() {
	# if which virt-what &>/dev/null; then
    debug "check_virt BEGIN ==================="
	if command -v virt-what >/dev/null; then
        VIRT=" $(virt-what | sed ':a;N;$!ba;s/\n/ /g') "
  	else
        VIRT=" $(systemd-detect-virt | sed ':a;N;$!ba;s/\n/ /g') "
	fi
    # VIRT=" kvm openvz "
    debug "VIRTUAL SYSTEM: =${VIRT}="
    local v_openvz="$(_trim "$(echo "${VIRT}" | sed -En 's/.*( openvz ).*/\1/p')")" #| sed -n 's/^[[:space:]]*//; s/[[:space:]]*$//p')"
    debug "v_openvz: =${v_openvz}="
	if [ -n "${v_openvz}" ]; then
		err "OpenVZ не поддерживается"
		exit 1
	fi
    local v_lxc="$(_trim "$(echo "${VIRT}" | sed -En 's/.*( lxc ).*/\1/p')")" # | sed -n 's/^[[:space:]]*//; s/[[:space:]]*$//p')"
    debug "v_lxc: =${v_lxc}="
	if [ -n "${v_lxc}" ]; then
        if [ -z "${allow_lxc}" ] || [ "${allow_lxc}" -eq "0" ]; then
            err "LXC не поддерживается."
            err "Технически WireGuard может работать в контейнере LXC,"
            err "но есть проблемы с модулями ядра и с настройкой Wireguard в контейнере."
            err "Поэтому не заморачиваемся и пока не реализовано."
            exit 1
        else
            msg "LXC не поддерживается."
            msg "Технически WireGuard может работать в контейнере LXC,"
            msg "но есть проблемы с модулями ядра и с настройкой Wireguard в контейнере."
            msg "Включен режим игнорирования этой ситуации и работа продолжится на Ваш страх и риск."
            msg "Чтобы выключить данный режим надо в скрипте найти строку 'allow_lxc=...' и заменить на 'allow_lxc=0' или закомментировать эту строку."
        fi
	fi
    debug "check_virt END ====================="
}

install_packages() {
    # ttt="$@"
    # if [ -z "${ID}" ] || [ -z "{VERSION_ID}" ]; then
    if [ -z "${ID+x}" ] || [ -z "{VERSION_ID+x}" ]; then
        # . "${OS_RELEASE}"
        local os_data=$(check_os 2)
    fi
    if [ "${ID}" = 'debian' ]; then
        local _cmd_="apt-get install -y $@"
    elif [ "${ID}" = 'alpine' ]; then
        local _cmd_="apk add $@"
    else
        local _cmd_=''
    fi
    debug "install_packages, выполняемая команда: ${_cmd_}"

    if [ -z "${dry_run}" ] || [ "${dry_run}" -eq "0" ]; then
    	# if ! "$@"; then
        if [ -z "${is_debug}" ] || [ "${is_debug}" -eq "0" ]; then
            ${_cmd_} > /dev/null 2>&1
        else
            ${_cmd_} >&2
        fi
        local _res_=$?
        debug "_res_: $_res_"
    	if [ "${_res_}" -ne "0" ]; then
	    	err "Ошибка установки пакетов: '${_cmd_}'"
		    err "Проверьте подключение к интернету и настройки пакетного менеджера."
		    exit 1
        fi
    else
        printf "${PURPLE}Выполнить команду: '${_cmd_}'${NC}\n" 1>&2
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
        local ttt="$@"
        printf "${PURPLE}Выполнить команду: '${ttt}'${NC}\n" 1>&2
	fi
}

exec_cmd_with_result() {
    local res=''
    if [ -z "${dry_run}" ] || [ "${dry_run}" -eq "0" ]; then
        res=$("$@")
    else
        local ttt="$@"
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

# Проверить что последний символ в строке, заданной в 1-ом аргументе, это символ, который задан во 2-ом аргументе
_endswith() {
  _str="$1"
  _sub="$2"
  echo "$_str" | grep -- "$_sub\$" >/dev/null 2>&1
}

# TRIM
_trim() {
    # debug "_trim BEGIN =========================="
    # debug "ARGS: ${1} ; ${2}"
    local char="$2"
    if [ -z "${char}" ]; then
        local char='\s'
    elif [ "${char}" = '/' ]; then
        local char='\/'
    elif [ "${char}" = '.' ]; then
        local char='\.'
    fi
    # debug "char: ${char}"
    local res="$(echo "${1}" | sed -E "s/^$char*//; s/$char*$//")"
    printf "%s" "${res}"
    # debug "_trim END ;;; res: ${res} ============================"
}

# LEFT TRIM
_ltrim() {
    # debug "_ltrim BEGIN =========================="
    # debug "ARGS: ${1} ; ${2}"
    local char="$2"
    if [ -z "${char}" ]; then
        local char='\s'
    elif [ "${char}" = '/' ]; then
        local char='\/'
    elif [ "${char}" = '.' ]; then
        local char='\.'
    fi
    # debug "char: ${char}"
    local res="$(echo "${1}" | sed -E "s/^$char*//")"
    printf "%s" "${res}"
    # debug "_ltrim END ;;; res: ${res} ============================"
}

# RIGHT TRIM
_rtrim() {
    # debug "_rtrim BEGIN =========================="
    # debug "ARGS: ${1} ; ${2}"
    local char="$2"
    if [ -z "${char}" ]; then
        local char='\s'
    elif [ "${char}" = '/' ]; then
        local char='\/'
    elif [ "${char}" = '.' ]; then
        local char='\.'
    fi
    # debug "char: ${char}"
    local res="$(echo "${1}" | sed -E "s/$char*$//")"
    printf "%s" "${res}"
    # debug "_rtrim END ;;; res: ${res} ============================"
}

# Если путь не начинается / (т.е. не абсолютный), или не начинается с ./ ил с ../
# то добавить в начало ./
_add_current_dot() {
    printf "$(echo "${1}" | sed -E 's/^(\.{1,2})$/\1\//; /^[^/]/!b; /^\.{1,2}\//!s/^/.\//')"
}

# Сложить две части пути
_join_path() {
    # debug "_join_path BEGIN =========================="
    local args="$@"
    # debug "ARGS: $args"
    if ! _startswith "$2" '/'; then
        local first="$(_rtrim "$1" '/')"
        # local second="$(_ltrim "$2" '/')"
        # local second="$(_ltrim "${second}" '/')"
        local res="${first}/${2}"
    else
        msg "Нельзя соединить каталоги $1 и $2, так как 2-й каталог является абсолютным"
        local res="${2}"
    fi
    printf "%s" "${res}"
    # debug "_join_path END; res: ${res} ============================"
}

# Проверить наличие файла
# ${1} (обязательный) - если !=0, то прерывать выполнение скрипта
# ${2} (обязательный) - имя файла для проверки
# ${3} (не обязательный) - сообщение об ошибке, по-умолчанию: Невозможно найти файл ${2}
check_file_exists() {
    local fn="${2}"
    local err_msg="${3}"
    #err "Невозможно открыть файл с конфигурацией для установки WIREGUARD ${file_config}"
    local err_msg="${err_msg:=Невозможно найти файл ${2}}"
    local is_break_script="${1}"
    if [ ! -f "${2}" ]; then
        # нет файла
        if [ "${1}" = "0" ]; then
            msg "${err_msg}"
        else
            err "${err_msg}"
            exit 1
        fi
        return 1
    else
        return 0
    fi
}

# установить права на каталог, его подкаталоги и файлы
# $1 - каталог, по-умолчанию './'
# $2 - маска файлов, по-умолчанию '*'
set_mode() {
    debug "set_mode BEGIN ==============================="
    if [ -z "$1" ]; then
        local _ct='./'
    else
        local _ct="$1"
    fi
    if [ -z "$2" ]; then
        local _fm='*.sh'
    else
        local _fm="$2"
    fi
    if [ -z "${is_debug}" ] || [ "${is_debug}" = "0" ]; then
        find "$_ct" -type d -exec chmod 0700 {} \; > /dev/null
        find "$_ct" -type f -exec chmod 0600 {} \; > /dev/null
        find "$_ct" -type f -name "$_fm" -exec chmod 0700 {} \; > /dev/null
    else
        printf "${GREEN}\n" >&2
        find "$_ct" -type d -exec chmod -v 0700 {} \; >&2
        find "$_ct" -type f -exec chmod -v 0600 {} \; >&2
        find "$_ct" -type f -name "$_fm" -exec chmod -v 0700 {} \; >&2
        printf "${NC}\n" >&2
    fi
    debug "set_mode END =================================="
}

# Запрос
_question() {
    debug "_question BEGIN ========================"
    # debug "_question args: '$@'"
    # local res_var=''
    local _title_="$1"
    # Проверить, что опция -e поддерживается у read и подготовить к запуску read
    {
        echo "test" | read -e _check > /dev/null 2>&1
    } > /dev/null 2>&1
    local t=$?
    if [ "$t" -eq "0" ]; then
        local is_opt_e=' -e '
        local is_opt_i=" -i ${2} "
    else
        local is_opt_e=''
        local is_opt_i=''
        [ -n "${3}" ] && local _title_="${_title_} (default ${2})"
    fi
    # запросить
    read -rp "${_title_}: " $is_opt_e $is_opt_i res_var
    printf "%s" "${res_var}"
    debug "_question END ==========================="
}

# Проверить что строка является валидным адресом IPv4
check_ipv4_addr() {
    # debug "check_ipv4_addr arg1: ${1} ========================"
    if [ -n "${1}" ]; then
        r=$(echo "${1}" | sed -rn "/(^|\s)$ai4(\s|$)/p")
        # if [ -n "$r" ]; then local res=1; else local res=0; fi
        if [ -n "$r" ]; then
            # валидный адрес
            return 0
        else
            # НЕ валидный адрес
            return 1
        fi
    else
        # НЕ валидный адрес
        return 1
    fi
    if [ "${res}" = "0" ];then
        return 1
    else
        return 0
    fi
}

# Проверить что строка является валидной маской IPv4 (число 0-32)
check_ipv4_mask() {
    debug "check_ipv4_mask arg1: ${1} ===================="
    if [ -n "${1}" ]; then
        # убрать все лишнее кроме первой группы цифр
        val=$(echo "${1}" | sed -En "s/^[^0-9]*([0-9]*)[^0-9]?.*$/\1/p")
        debug "Выделенное число для маски: ${val}"
        # POSITIVE LOOKHEAD ^[^0-9:]*([1-9](?=[^0-9])|1|2[0-9](?=[^\d])|[3][0-2](?=[^\d])).*$
        #                   ^[^0-9:]*([1-9](?=[^0-9])|1[0-9](?=[^\d])|2[0-9](?=[^\d])|3[0-2](?=[^\d]))$
        # POSITIVE LOOKHEAD не работает  в sed
        # проверить маска ipv4 валидная, т.е. что это число от 1 до 32
        r=$(echo "${val}" | sed -En "/^([1-9]|(1|2)[0-9]|3[0-2])$/p")
        if [ -n "$r" ]; then
            # валидная маска
            return 0
        else
            # НЕ валидная маска
            return 1
        fi
    else
        # НЕ валидная маска
        return 1
    fi
}

# Проверить что строка является валидным адресом IPv6
check_ipv6_addr() {
    debug "check_ipv6_addr arg1: ${1} =========================="
    if [ -n "${1}" ]; then
        r=$(echo "${1}" | sed -rn "/(^|\s)(($oi6:){7,7}$oi6|($oi6:){1,7}:|($oi6:){1,6}:$oi6|($oi6:){1,5}(:$oi6){1,2}|($oi6:){1,4}(:$oi6){1,3}|($oi6:){1,3}(:$oi6){1,4}|($oi6:){1,2}(:$oi6){1,5}|$oi6:((:$oi6){1,6})|:((:$oi6){1,7}|:)|fe80:(:$oi6){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}$ai4|($oi6:){1,4}:$ai4)($|\s)/p")
        if [ -n "$r" ]; then
            # валидный адрес
            return 0
        else
            # НЕ валидный адрес
            return 1
        fi
    else
        # НЕ валидный адрес
        return 1
    fi
}

# Проверить что строка является валидной маской IPv6 (число 0-128)
check_ipv6_mask() {
    # local res=0
    debug "check_ipv6_mask BEGIN arg1: ${1} =========================="
    if [ -n "${1}" ]; then
        # убрать все лишнее кроме первой группы цифр
        val=$(echo "${1}" | sed -En "s/^[^0-9]*([0-9]*?).*$/\1/p")
        debug "Выделенное число для маски: ${val}"
        # проверить, что это число от 1 до 128
        r=$(echo "${val}" | sed -En '/^([1-9]|(1|2|3|4|5|6|7|8|9)[0-9]|1[0-1][0-9]|12[0-8])$/p')
        if [ -n "$r" ]; then
            # валидная маска
            return 0
        else
            # НЕ валидная маска
            return 1
        fi
    else
        # НЕ валидная маска
        return 1
    fi
}

# Распарсить строку IPv4 в адрес и маску
# $1 - ipv4/mask
# $2 - ip адрес по-умолчанию
# $3 - маска по-умолчанию
# $4 - флаг что для возврата, если в ${1} ошибочные адрес или маска, то будут подставляться или "${2}" или "${3}"
#      если он присутствует и не равен 0, то будут подстановки
#      если он отсутствует или   равен 0, то подстановок не будет и вместо ошибочного элемента будет возвращаться "" (пустая строка)
get_ip_mask_4() {
    ip_full=$1
    # debug "get_ip_mask_4 BEGIN ================================="
    # debug "ARGS: ${ip_full}"
    if [ -z "$4" ] || [ "$4" = "0" ]; then
        local flag_use_def=0
    else
        local flag_use_def=1
    fi
    # разделить на ip адрес и маску (ipv4/mask)
    local ip=$(echo "${ip_full}"   | sed -En "s/^[^0-9/]*([0-9.]*)(\/([0-9]*)|[^/]?).*$/\1/p")
    local mask=$(echo "${ip_full}" | sed -En "s/^[^0-9/]*([0-9.]*)(\/([0-9]*)|[^/]?).*$/\3/p")
    # Проверить что это ip
    # is_ipv4=$(check_ipv4_addr "${ip}")
    # if [ "${is_ipv4}" -eq "0" ]; then
    #     ip="${DEF_SERVER_WG_IPV4}"
    # fi
    if ! check_ipv4_addr "${ip}" > /dev/null; then
        if [ "${flag_use_def}" = "1" ]; then
            local ip="${2}"
        else
            local ip=""
        fi
    fi
    # is_ipv4_mask=$(check_ipv4_mask "${mask}")
    # if [ "${is_ipv4_mask}" = "0" ]; then
    if ! check_ipv4_mask "${mask}"; then
        if [ "${flag_use_def}" = "1" ]; then
            mask="${3}"
        else
            mask=""
        fi
    fi
    # debug "ip=${ip} mask=${mask}"
    # debug "get_ip_mask_4 END ================================="
    printf "%s" "ip=${ip} mask=${mask}"
}

# Распарсить строку IPv6 в адрес и маску
# $1 - ipv6/mask
# $2 - ip адрес по-умолчанию
# $3 - маска по-умолчанию
# $4 - флаг что для возврата, если в ${1} ошибочные адрес или маска, то будут подставляться или "${2}" или "${3}"
#      если он присутствует и не равен 0, то будут подстановки
#      если он отсутствует или   равен 0, то подстановок не будет и вместо ошибочного элемента будет возвращаться "" (пустая строка)
# Возвращает строку в формате 'ip=[addr_ipv6] mask=[mask_ipv6]'
get_ip_mask_6() {
    local ip_full=$1
    local args="$@"
    debug "get_ip_mask_6 BEGIN ================================"
    debug "ARGS: ${args}"
    local si6='0-9a-fA-F:'
    if [ -z "$4" ] || [ "$4" = "0" ]; then
        local flag_use_def=0
    else
        local flag_use_def=1
    fi
    # разделить на ip адрес и маску (ipv4/mask)
    local ip=$(echo "${ip_full}"   | sed -En "s/^[^${si6}/]*([${si6}]*)(\/([0-9]*)|[^/]?).*$/\1/p")
    local mask=$(echo "${ip_full}" | sed -En "s/^[^${si6}/]*([${si6}]*)(\/([0-9]*)|[^/]?).*$/\3/p")
    # local is_ipv6="$(check_ipv6_addr "${ip}")"
    if ! check_ipv6_addr "${ip}" > /dev/null; then
        if [ "${flag_use_def}" = "1" ]; then
            # local ip="${DEF_SERVER_WG_IPV6}"
            local ip="${2}"
        else
            local ip=""
        fi
    fi
    # local is_ipv6_mask=$(check_ipv6_mask "${mask}")
    # if [ "${is_ipv6_mask}" = "0" ]; then
    if ! check_ipv6_mask "${mask}"; then
        if [ "${flag_use_def}" = "1" ]; then
            # local mask="${DEF_SERVER_WG_IPV6_MASK}"
            local mask="${3}"
        else
            local mask=""
        fi
    fi
    debug "ip=${ip} mask=${mask}"
    debug "get_ip_mask_6 END =================================="
    printf "%s" "ip=${ip} mask=${mask}"
}

# Проверить валидность адреса и маски ipv4. Адрес должен быть в формате <addIPv4>/<maskIPv4>
# Подстановок адреса и маски по-умолчанию нет.
check_ip_addr_mask_4() {
    local res="$(get_ip_mask_4 "$1")"
    # res - строка 'ip=addrIPv4 mask=maskIPv4'
    local addr="$(echo "${res}" | sed -En 's/^.*ip\s*=\s*([0-9.]+).*$/\1/p')"
    local mask="$(echo "${res}" | sed -En 's/^.*mask\s*=\s*([0-9]+).*$/\1/p')"
    debug "check_ip_addr_mask_4 addr: ${addr}"
    debug "check_ip_addr_mask_4 mask: ${mask}"
    # проверить на валидность адрес и маску
    if check_ipv4_addr "${addr}" > /dev/null && check_ipv4_mask "${mask}" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Проверить валидность адреса и маски ipv6. Адрес должен быть в формате <addIPv6>/<maskIPv6>
# Подстановок адреса и маски по-умолчанию нет.
check_ip_addr_mask_6() {
    local res="$(get_ip_mask_6 "$1")"
    # res - строка 'ip=addrIPv6 mask=maskIPv6'
    local addr="$(echo "${res}" | sed -En 's/^.*ip\s*=\s*([0-9a-fA-F:]+).*$/\1/p')"
    local mask="$(echo "${res}" | sed -En 's/^.*mask\s*=\s*([0-9]+).*$/\1/p')"
    debug "check_ip_addr_mask_6 addr: ${addr}"
    debug "check_ip_addr_mask_6 mask: ${mask}"
    # проверить на валидность адрес и маску
    if check_ipv6_addr "${addr}" > /dev/null && check_ipv6_mask "${mask}" > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Проверить валидность ip-адреса ipv4 и вернуть его.
# Параметры как и в get_ip_mask_4
# Возвращает ip адрес v4:
#   код возврата =0 и строку 'addr_ipv4', если адрес валидный
#   код возврата =1 и строку (пустую) '', если адрес НЕ валидный
check_get_ip_addr_4() {
    local res="$(get_ip_mask_4 $@)"
    # res - строка 'ip=addrIPv4 mask=maskIPv4'
    local addr="$(echo "${res}" | sed -En 's/^.*ip\s*=\s*([0-9.]+).*$/\1/p')"
    # проверить на валидность адрес
    if check_ipv4_addr "${addr}" > /dev/null; then
        printf "${addr}"
        return 0
    else
        printf ""
        return 1
    fi
}

# Проверить валидность ip-адреса ipv6 и вернуть его.
# Параметры как и в get_ip_mask_6
# Возвращает ip адрес v6:
#   код возврата =0 и строку 'addr_ipv6', если адрес валидный
#   код возврата =1 и строку (пустую) '', если адрес НЕ валидный
check_get_ip_addr_6() {
    local res="$(get_ip_mask_6 $@)"
    # res - строка 'ip=addrIPv6 mask=maskIPv6'
    local addr="$(echo "${res}" | sed -En 's/^.*ip\s*=\s*([0-9a-fA-F:]+).*$/\1/p')"
    debug "check_get_ip_addr_6 addr: ${addr}"
    # проверить на валидность адрес
    if check_ipv6_addr "${addr}" > /dev/null; then
        printf "${addr}"
        return 0
    else
        printf ""
        return 1
    fi
}

# Проверить валидность маски ipv4 и вернуть ее.
# Параметры как и в get_ip_mask_4
# Возвращает маску v4:
#   код возврата =0 и строку 'mask' (число 0..32), если маска валидная
#   код возврата =1 и строку (пустую) '', если маска НЕ валидная
check_get_ip_mask_4() {
    local res="$(get_ip_mask_4 $@)"
    # res - строка 'ip=addrIPv6 mask=maskIPv6'
    local mask="$(echo "${res}" | sed -En 's/^.*mask\s*=\s*([0-9]+).*$/\1/p')"
    debug "check_get_ip_mask_4 mask: ${mask}"
    # проверить на валидность маску
    if check_ipv4_mask "${mask}" > /dev/null; then
        printf "${mask}"
        return 0
    else
        printf ""
        return 1
    fi
}

# Проверить валидность маски ipv6 и вернуть ее.
# Параметры как и в get_ip_mask_6
# Возвращает маску v6:
#   код возврата =0 и строку 'mask' (число 0..128), если маска валидная
#   код возврата =1 и строку (пустую) '', если маска НЕ валидная
check_get_ip_mask_6() {
    local res="$(get_ip_mask_6 $@)"
    # res - строка 'ip=addrIPv6 mask=maskIPv6'
    local mask="$(echo "${res}" | sed -En 's/^.*mask\s*=\s*([0-9]+).*$/\1/p')"
    debug "check_get_ip_mask_6 mask: ${mask}"
    # проверить на валидность маску
    if check_ipv6_mask "${mask}" > /dev/null; then
        printf "${mask}"
        return 0
    else
        printf ""
        return 1
    fi
}

wg_prepare_file_config() {
    debug "wg_prepare_file_config BEGIN ========================"
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
    # WIREGUARD SERVER IPv4/MASK
    echo "INST_SERVER_WG_IPV4=${DEF_SERVER_WG_IPV4}/${DEF_SERVER_WG_IPV4_MASK}" >> "${file_config}"
    # WIREGUARD SERVER IPv6/MASK
    echo "INST_SERVER_WG_IPV6=${DEF_SERVER_WG_IPV6}/${DEF_SERVER_WG_IPV6_MASK}" >> "${file_config}"
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
    # Подготовить файл с последними аргументами при установке WG
    echo "is_debug=${_a_is_debug:=0}"                       > "${file_args}"
    echo "dry_run=${_a_dry_run}"                            >> "${file_args}"
    echo "use_ipv6=${_a_use_ipv6}"                          >> "${file_args}"
    echo "path_wg=${_a_path_wg}"                            >> "${file_args}"
    echo "file_params=${_a_file_params}"                    >> "${file_args}"
    echo "file_hand_params=${_a_file_hand_params}"          >> "${file_args}"
    echo "path_out=${_a_path_out}"                          >> "${file_args}"
    echo "file_rules_firewall=${_a_file_rules_firewall}"    >> "${file_args}"
    debug "wg_prepare_file_config END  =========================="
}

inst_iptables(){
    debug "inst_iptables BEGIN"
    local frf="${1}"
    local result=1
    debug "frf: ${frf}"
    debug "FILE_CONF_WG: ${FILE_CONF_WG}"
    if [ -z "${frf}" ]; then
        err "Не определен файл с правилами для firewall"
        err "Настройте firewall вручную"
    else
        if [ -f "${frf}" ]; then
            # есть файл с правилами для iptables
            # копируем файл-шаблон в каталог WIREGUARD
            local script_rules="$(realpath -m "$(_join_path "${path_wg}" "apply_rules.sh")")"
            local _fp="$(realpath -m "${file_params}")"
            local _fhp="$(realpath -m "${file_hand_params}")"
            debug "script_rules: ${script_rules}"
            cp "${frf}" "${script_rules}"
            # настроить переменные
            # удалить строки до первого ШЕБАНГА и удалить все остальные ШЕБАНГИ в файле
            sed -i -En '/^#!/{:a; p; n; ba}' "${script_rules}" && sed -i '2,${/#!/d}' "${script_rules}"
            # добавить строку подключения файла с параметрами установки и доп.параметрами
            #sed -i -E "/^#\!\/bin\/.*$/a\. ${file_params}" "${script_rules}"
            sed -i -E "1aif [ -f \"${_fp}\" \]\;  then \. \"${_fp}\"\;  fi" "${script_rules}"
            sed -i -E "2aif [ -f \"${_fhp}\" \]\; then \. \"${_fhp}\"\; fi" "${script_rules}"
            echo "PostUp=${script_rules} add" >> "${FILE_CONF_WG}"
            echo "PostDown=${script_rules} delete" >> "${FILE_CONF_WG}"
            # sed -i -r "s/^\s*(server_port\s*=\s*)[^ \t\n\r]+?(.*)$/\1${SERVER_PORT}\2/g" "${script_rules}"
            # sed -i -r "s/^\s*(server_pub_nic\s*=\s*)[^ \t\n\r]+?(.*)$/\1${SERVER_PUB_NIC}\2/g" "${script_rules}"
            # sed -i -r "s/^\s*(server_wg_nic\s*=\s*)[^ \t\n\r]+?(.*)$/\1${SERVER_WG_NIC}\2/g" "${script_rules}"
            chmod +x "${script_rules}"
            local result=0
        else
            # нет файла с правилами для iptables
            err "Не определен файл с правилами для firewall"
            err "Настройте firewall вручную"
        fi
    fi
    # sed -i -r 's/^\s*(server_port\s*=\s*)[^ \t\n\r]+?(.*)$/\1ert\2/g' 
    debug "inst_iptables END"
    return $result
}

inst_nftables(){
    debug "inst_nftables BEGIN"
    err "Пока не реализована работа с nftables"
    err "Настройте firewall вручную"
    debug "inst_nftables END"
}

wg_install() {
    debug "wg_install BEGIN ============================================"
    # debug "file_config__: ${file_config}"
    # debug "file_params__: ${file_params}"
    # debug "${OS}"
    debug "file_config: ${file_config}"
    debug "pwd: $(pwd)"
    # проверить наличие файла с конфигурацией для установки WG
    # check_file_exists 0 "${file_config}" "Нет файла с конфигурацией для установки WIREGUARD ${file_config}"
    # check_file_exists 0 "${file_config}"
    # if [ check_file_exists 0 "${file_config}" '' > /dev/null 2>&1 ]; then
    if check_file_exists 0 "${file_config}"; then
        . "${file_config}" #> /dev/null # 2>&1
    fi
    # публичный интерфейс сервера
    if [ -z "${INST_SERVER_PUB_NIC}" ]; then
        # grep default | sed -E 's/.*\sdev\s*([^\s]*).*/\1/'
        # sed -E 's/.*\sdev\s*([a-zA-Z0-9]*)\s.*/\1/'
	    INST_SERVER_PUB_NIC=$(ip route | grep default | sed -E 's/.*\sdev\s*([a-zA-Z0-9]*)\s.*/\1/')
        INST_SERVER_PUB_NIC=$(_question "Внешний интерфейс" "${INST_SERVER_PUB_NIC}")
    fi
    if [ -z "${INST_SERVER_PUB_NIC}" ]
    then
        err "В файле ${file_config} или при вводе не указан внешний сетевой интерфейс";
        exit 1
    fi
    if ! ip link show ${INST_SERVER_PUB_NIC} > /dev/null 2>&1; then
        err "В файле ${file_config} или при вводе указан неверный внешний сетевой интерфейс ${INST_SERVER_PUB_NIC}";
        exit 1
    fi
    # публичный адрес сервера
    # 1. Взять из вывода ip -4 addr show
    # 2. Если пустой вывод, то нет IPv4. Поэтому берем IPv6 вывод из ip -6 addr show
    # 3. _ip_dev_pub_ - это адрес IPv4 или IPv6
    if [ -z "${INST_SERVER_PUB_IP}" ]; then
    	local _ip_dev_pub_=$(ip -4 addr show "${INST_SERVER_PUB_NIC}" | sed -nE 's/^.*\sinet\s([^/]*)\/.*\sscope global.*$/\1/p' | awk '{print $1}' | head -1)
        if [ -z "${_ip_dev_pub_}" ]; then
            local _ip_dev_pub_=$(ip -6 addr show "${INST_SERVER_PUB_NIC}" | sed -nE 's|^.*\sinet6\s([^/]*)/.*\sscope global.*$|\1|p' | awk '{print $1}' | head -1)
        fi
        title_quest="Публичный IPv4 или IPv6 сервера"
        INST_SERVER_PUB_IP=$(_question "${title_quest}" "${_ip_dev_pub_}")
    fi
    if [ -z "${INST_SERVER_PUB_IP}" ] ||
        (
            ! (check_get_ip_addr_4 "${INST_SERVER_PUB_IP}" > /dev/null || check_get_ip_addr_6 "${INST_SERVER_PUB_IP}" > /dev/null)
        )
    then
        err "В файле ${file_config} или при вводе указан не верный внешний IP адрес ${INST_SERVER_PUB_IP}";
        exit 1
    fi
    # имя интерфейса сервера WIREGUARD. REQUIRED
    if [ -z "${INST_SERVER_WG_NIC}" ]; then
        INST_SERVER_WG_NIC=$(_question "ОБЯЗАТЕЛЬНО! Имя интерфейса сервера wireguard" "${DEF_SERVER_WG_NIC}" "1")
    fi
    if [ -z "${INST_SERVER_WG_NIC}" ]; then
        INST_SERVER_WG_NIC="${DEF_SERVER_WG_NIC}"
    fi
    # IPv4 и маска интерфейса сервера WIREGUARD
    local _IP_="${INST_SERVER_WG_IPV4}"
    if [ -n "${ipv4}" ]; then
        local _IP_="${ipv4}"
    fi
    if [ -z "${_IP_}" ]; then
        local _IP_=$(_question "ОБЯЗАТЕЛЬНО! IPv4 адрес интерфейса сервера wireguard" "${DEF_SERVER_WG_IPV4}/${DEF_SERVER_WG_IPV4_MASK}" "1")
    fi
    INST_SERVER_WG_IPV4="${_IP_}"
    local ipv4_mask=$(get_ip_mask_4 "${INST_SERVER_WG_IPV4}" "${DEF_SERVER_WG_IPV4}" "${DEF_SERVER_WG_IPV4_MASK}" "1")
    local is_digit=$(echo "${ipv4_mask}" | sed -En '/^.*[0-9./].*$/p')
    # if [ -z "${INST_SERVER_WG_IPV4}" ]; then
    #     INST_SERVER_WG_IPV4=$(_question "ОБЯЗАТЕЛЬНО! IPv4 адрес интерфейса сервера wireguard" "${DEF_SERVER_WG_IPV4}/${DEF_SERVER_WG_IPV4_MASK}" "1")
    # fi
    # local ipv4_mask=$(get_ip_mask_4 "${INST_SERVER_WG_IPV4}" "${DEF_SERVER_WG_IPV4}" "${DEF_SERVER_WG_IPV4_MASK}" "1")
    # local is_digit=$(echo "${ipv4_mask}" | sed -En '/^.*[0-9./].*$/p')
    if [ -n "${ipv4_mask}" ] && [ -n "${is_digit}" ]; then
        # есть IPv4
        INST_SERVER_WG_IPV4=$(echo "${ipv4_mask}" | sed -En 's/^.*ip\s*=\s*([0-9.]+).*$/\1/p')
        INST_SERVER_WG_IPV4_MASK=$(echo "${ipv4_mask}" | sed -En 's/^.*mask\s*=\s*([0-9]+).*$/\1/p')
    fi
    # IPv6 и маска интерфейса сервера WIREGUARD
    if [ "${use_ipv6}" != "0" ]; then
        local _IP_="${INST_SERVER_WG_IPV6}"
        if [ -n "${ipv6}" ]; then
            local _IP_="${ipv6}"
        fi
        if [ -z "${_IP_}" ]; then
            local _IP_=$(_question "ОБЯЗАТЕЛЬНО! IPv6 адреса интерфейса сервера wireguard" "${DEF_SERVER_WG_IPV6}/${DEF_SERVER_WG_IPV6_MASK}" "1")
        fi
        INST_SERVER_WG_IPV6="${_IP_}"
        local ipv6_mask=$(get_ip_mask_6 "${INST_SERVER_WG_IPV6}" "${DEF_SERVER_WG_IPV6}" "${DEF_SERVER_WG_IPV6_MASK}" "1")
        local is_digit=$(echo "${ipv6_mask}" | sed -En '/^.*[0-9a-fA-F:].*$/p')
        # if [ -z "${INST_SERVER_WG_IPV6}" ]; then
        #     INST_SERVER_WG_IPV6=$(_question "ОБЯЗАТЕЛЬНО! IPv6 адреса интерфейса сервера wireguard" "${DEF_SERVER_WG_IPV6}/${DEF_SERVER_WG_IPV6_MASK}" "1")
        # fi
        # local ipv6_mask=$(get_ip_mask_6 "${INST_SERVER_WG_IPV6}")
        # local is_digit=$(echo "${ipv6_mask}" | sed -En '/^.*[0-9a-fA-F:].*$/p')
        if [ -n "${ipv6_mask}" ] && [ -n "${is_digit}" ]; then
            # есть ipv6
            INST_SERVER_WG_IPV6="$(echo "${ipv6_mask}" | sed -En 's/^.*ip\s*=\s*([0-9a-fA-F:]+).*$/\1/p')"
            INST_SERVER_WG_IPV6_MASK="$(echo "${ipv6_mask}" | sed -En 's/^.*mask\s*=\s*([0-9]+).*$/\1/p')"
        fi
    else
        INST_SERVER_WG_IPV6=''
        INST_SERVER_WG_IPV6_MASK=''
    fi
    # # Маска IPv6 интерфейса сервера
    # if [ "${use_ipv6}" -ne "0" ]; then
    #     if [ -z "${INST_SERVER_WG_IPV6_MASK}" ]; then
    #         INST_SERVER_WG_IPV6_MASK=$(_question "Длина префикса IPv6 адреса интерфейса сервера wireguard" "${DEF_SERVER_WG_IPV6_MASK}")
    #     fi
    # else
    #     INST_SERVER_WG_IPV6_MASK=''
    # fi
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
        # apt-get update > /dev/null 2>&1
        exec_cmd apt-get update
        # exit
        # install_packages apt-get install -y wireguard iptables systemd-resolved qrencode
        install_packages wireguard iptables systemd-resolved qrencode ipcalc
    elif [ "${OS}" = 'alpine' ]; then
		# apk update > /dev/null 2>&1
		exec_cmd apk update
		# install_packages apk add wireguard-tools iptables libqrencode-tools
		install_packages wireguard-tools iptables libqrencode-tools ipcalc
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

	# Настройка sysctl Включить форвардинг на сервере
    local c1="$(exec_cmd echo "net.ipv4.ip_forward = 1")"
    local c2="$(exec_cmd echo "net.ipv6.conf.all.forwarding = 1")"
    if [ -n "${c1}" ] && ([ -z "${dry_run}" ] || [ "${dry_run}" = "0" ]); then
        echo "${c1}" > "${file_sysctl}"
    fi
    if [ -n "${c2}" ] && ([ -z "${dry_run}" ] || [ "${dry_run}" = "0" ]); then
        echo "${c2}" > "${file_sysctl}"
    fi
    # if [ -z "${dry_run}" ] || [ "${dry_run}" -eq "0" ]; then
    #     echo "net.ipv4.ip_forward = 1" > "${file_sysctl}"
    #     echo "net.ipv6.conf.all.forwarding = 1" >> "${file_sysctl}"
    # else
    #     exec_cmd echo "net.ipv4.ip_forward = 1 > ${file_sysctl}"
    #     exec_cmd echo "net.ipv6.conf.all.forwarding = 1 >> ${file_sysctl}"
    # fi
	# Файл конфигурации WIREGUARD
    # FILE_CONF_WG="${path_wg}/${SERVER_WG_NIC}.conf"
    # FILE_CONF_WG="$(_join_path "${path_wg}" "${SERVER_WG_NIC}.conf")"
    FILE_CONF_WG="$(realpath -m "$(_join_path "${path_wg}" "${SERVER_WG_NIC}.conf")")"
	echo "[Interface]" > "${FILE_CONF_WG}"
    local _addr_wg_serv=''
    if [ -n "${SERVER_WG_IPV4}" ]; then
        local _addr_wg_serv="${SERVER_WG_IPV4}/${SERVER_WG_IPV4_MASK}"
    fi
    if [ -n "${SERVER_WG_IPV6}" ]; then
        if [ -n "${_addr_wg_serv}" ]; then
            local _addr_wg_serv="${_addr_wg_serv},"
        fi
        local _addr_wg_serv="${_addr_wg_serv}${SERVER_WG_IPV6}/${SERVER_WG_IPV6_MASK}"
    fi
    echo "Address = ${_addr_wg_serv}"  >> "${FILE_CONF_WG}"
    echo "ListenPort = ${SERVER_PORT}" >> "${FILE_CONF_WG}"
    echo "PrivateKey = ${SERVER_PRIV_KEY}" >> "${FILE_CONF_WG}"
    # права на файл конфигурации
    chmod 0700 "${path_wg}"
    chmod 0600 "${FILE_CONF_WG}"
 
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
    if which iptables > /dev/null 2>&1; then
        inst_iptables "${file_rules_firewall}"
    elif which nft > /dev/null 2>&1; then
        inst_nftables
    else
        err "Нет поддерживаемого файервола (iptables или nftables)."
        err "Если используется какой-то другой файервол, то настройте его сами."
        err "Создайте скрипты с добавлением и удалением правил, и подключите их в файл конфигурации Wireguard."
        err "Например:"
        err "    [Interface]"
        err "    .............."
        err "    PostUp = <СкриптИнициализацииПравилФайервола.sh>"
        err "    PostDown = <СкриптОчисткиПравилФайервола.sh>"
        err "    .............."
    fi

    debug "wg_install END =============================================="
}

wg_uninstall() {
    debug "wg_uninstall BEGIN ============================================"

    debug "wg_uninstall END =============================================="
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

main() {
    if [ -z "$1" ]; then
        # show_help
        local cmd=install
    elif _startswith "$1" "-"; then
        local cmd=install
    else
        local cmd="$1"
        shift
    fi
    # Проверить на допустимость команды, она должна быть одной из списка ARR_CMD
    local l_cmd=$(echo " ${ARR_CMD} " | sed -rn "s/.*( $cmd ).*/\1/p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "${l_cmd}" ]; then
        err "Неверная команда: ${cmd}"
        show_help
        exit 1
    fi
    while [ ${#} -gt 0 ]; do
        case "${1}" in
            -c | --config)
                file_config="$(_trim "$2")"
                shift
                ;;
            -p | --params)
                local _a_file_params="$(_trim "$2")"
                shift
                ;;
            -o | --out-path)
                local _a_path_out="$(_trim "$2")"
                shift
                ;;
            -w | --wg-path)
                local _a_path_wg="$(_trim "$2")"
                shift
                ;;
            --debug)
                local _a_is_debug='1'
                ;;
            -h | --help)
                show_help
                exit 0
                ;;
            -6 | --use-ipv6)
                # TODO пока не реализовано, поэтому use_ipv6 = 0. Не реализовано из-за iptables6
                local _a_use_ipv6='0'
                local _a_use_ipv6='1'
                ;;
            --dry-run)
                local _a_dry_run='1'
                ;;
            -r | --rules-iptables)
                local _a_file_rules_firewall="$(_trim "$2")"
                shift
                ;;
            -d | --hand-params)
                local _a_file_hand_params="${2}"
                shift
                ;;
            -f | --file-args)
                # путь к файлу где хранятся аргументы для командной строки"
                file_args="${2}"
                is_file_args=is_file_args
                shift
                ;;
            -u | --update-args)
                # флаг, что надо обновить файл с аргументами соответственно текущим аргументам командной строки
                is_update_file_args=1
                ;;
            -a | --action)
                action="$2"
                shift
                ;;
            --ip4)
                # <address/mask>
                ipv4="$2"
                shift
                ;;
            --ip6)
                # <address/mask>
                ipv6="$2"
                shift
                ;;
            -e | --allowed_ips)
                # <address/mask>
                client_allowed_ips="$2"
                shift
                ;;
            -n | --name)
                # <address/mask>
                client_name="$2"
                shift
                ;;
            *)
                err "Неверный параметр: ${1}"
                return 1
                ;;
        esac
        shift 1
    done
    # Установить пакеты, требующиеся для работы скрипта, отладочных сообщений нет совсем
    # установятся они до инициализации аргументов
    check_os 2 > /dev/null

    is_update_file_args="${is_update_file_args:=0}"
    file_config="$(_add_current_dot "${file_config:="$VARS_FOR_INSTALL"}")"
    mkdir -p "$(dirname "${file_config}")" > /dev/null
    # file_args="$(realpath -m "$(_join_path "${_a_path_wg}" "$(_add_current_dot "${file_args:=${def_file_args}}")")")"
    # file_args="$(_add_current_dot "${file_args}")"
    file_args="$(_add_current_dot "${file_args:=${def_file_args}}")"
    mkdir -p "$(dirname "${file_args}")" > /dev/null
    if [ -f "${file_args}" ]; then
        . "${file_args}"
    fi
    # if [ -n "${file_args}" ]; then
    #     local path_file_args="$(dirname ${file_args})"
    #     if [ -n "${path_file_args}" ]; then
    #         mkdir -p "${path_file_args}" > /dev/null
    #     fi
    # fi
    cmd=${cmd:=install}
    if [ -z "${is_file_args}" ] || [ ! -f "${file_args}" ]; then
        local _a_is_debug=${_a_is_debug:=0}
        local _a_dry_run=${_a_dry_run:=0}
        local _a_use_ipv6=${_a_use_ipv6:=0}
        local _a_path_wg="$(_add_current_dot "${_a_path_wg:=/etc/wireguard}")"
        local temp_path="$(_join_path "${_a_path_wg}" "$(_add_current_dot "${_a_file_params:="$VARS_PARAMS"}")")"
        local _a_file_params="$(realpath -m "${temp_path}")"
        local temp_path="$(_join_path "${_a_path_wg}" "$(_add_current_dot "${_a_file_hand_params:=${def_file_hand_params}}")")"
        local _a_file_hand_params="$(realpath -m "${temp_path}")"
        local temp_path="$(_join_path "${_a_path_wg}" ".clients")"
        local _a_path_out="$(realpath -m "$(_add_current_dot "${_a_path_out:=${temp_path}}")")"
        local _a_file_rules_firewall="$(_add_current_dot "${_a_file_rules_firewall:=./iptables/default-iptables.rules}")"
    fi
    set_var is_debug ${is_debug} ${_a_is_debug}
    set_var dry_run ${dry_run} ${_a_dry_run}
    set_var path_wg "${path_wg}" "${_a_path_wg}"
    set_var file_params "${file_params}" "${_a_file_params}"
    set_var file_hand_params "${file_hand_params}" "${_a_file_hand_params}"
    set_var path_out "${path_out}" "${_a_path_out}"
    set_var file_rules_firewall "${file_rules_firewall}" "${_a_file_rules_firewall}"
    set_var use_ipv6 "${use_ipv6}" "${_a_use_ipv6}"
    if [ -z "${use_ipv6}" ]; then
        use_ipv6=0
    fi
    if [ -z "${is_debug}" ]; then
        is_debug=0
    fi
    if [ -z "${dry_run}" ]; then
        dry_run=0
    fi
    # if [ -z "${is_file_args}" ] || [ ! -f "${file_args}" ]; then
    if [ -n "${is_update_file_args}" ] && [ "${is_update_file_args}" != "0" ]; then
        # file_args="$(_add_current_dot "${file_args:=${def_file_args}}")"
        # записать в файл арнументы текущего запуска
        echo "is_debug=${is_debug}" > "${file_args}"
        echo "dry_run=${dry_run}" >> "${file_args}"
        echo "use_ipv6=${use_ipv6}" >> "${file_args}"
        echo "path_wg=${path_wg}" >> "${file_args}"
        echo "file_params=${file_params}" >> "${file_args}"
        echo "file_hand_params=${file_hand_params}" >> "${file_args}"
        echo "path_out=${path_out}" >> "${file_args}"
        echo "file_rules_firewall=${file_rules_firewall}" >> "${file_args}"
    fi
    # аргументы, которые не сохраняются, не имеют значений по-умолчанию и не настраиваются предварительно
    if [ "${cmd}" = "client" ]; then
        local l_act=$(echo " ${ACTION_CLIENT} " | sed -rn "s/.*( $action ).*/\1/p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -z "${l_act}" ]; then
            err "Неверный аргумент --action ( or -a ) ${action}"
            show_help
            exit 1
        fi
    fi

    debug "main BEGIN"
    debug "cmd_________________: ${cmd}"
    debug "is_update_file_args_: ${is_update_file_args}"
    debug "is_debug____________: ${is_debug}"
    debug "file_config_________: ${file_config}"
    debug "file_params_________: ${file_params}"
    debug "file_hand_params____: ${file_hand_params}"
    debug "file_rules_firewall_: ${file_rules_firewall}"
    debug "path_out___________ : ${path_out}"
    debug "path_wg____________ : ${path_wg}"
    debug "use_ipv6____________: ${use_ipv6}"
    debug "dry_run_____________: ${dry_run}"
    debug "file_args___________: ${file_args}"
    debug "action______________: ${action}"
    debug "ipv4________________: ${ipv4}"
    debug "ipv6________________: ${ipv6}"
    debug "client_allowed_ips__: ${client_allowed_ips}"
    debug "client_name_________: ${client_name}"
    # создать каталоги
    local path_file_params="$(dirname ${file_params})"
    debug "Создаем каталоги: ${path_wg} ; ${path_out} ; ${path_file_params}"
    if [ -n "${path_wg}" ]; then mkdir -p "${path_wg}" > /dev/null; fi
    if [ -n "${path_out}" ]; then mkdir -p "${path_out}" > /dev/null; fi
    if [ -n "${path_file_params}" ]; then mkdir -p "${path_file_params}" > /dev/null; fi
    # создать каталоги
    chown -R root:root "${path_wg}" > /dev/null
    chown -R root:root "${path_out}" > /dev/null
    chown -R root:root "${path_file_params}" > /dev/null
    # установить права на созданные каталоги, их подкаталоги и файлы
    # find ./ -type d -exec chmod 0700 {} \;
    # find ./ -type f -exec chmod 0600 {} \;
    # find ./ -type f -name '*.sh' -exec chmod 0700 {} \;
    set_mode "${path_wg}"
    set_mode "${path_out}"
    set_mode "${path_file_params}"

    case "$cmd" in
        "install")
            # Проверить что из под root и в противном случае прервать выполнение
            check_root
            # Проверить что выполняется в поддерживаемой OS, в противном случае прервать выполнение
            local os_data="$(check_os)"
            if [ "$?" -ne "0" ]; then
                exit 1
            fi
            # Проверить что выполняется в поддерживаемой системе виртуализации и в противном случае прервать выполнение
            check_virt
            wg_install
            ;;
        "uninstall")
            # удалить установленные пакеты и все созданные каталоги и файлы
            wg_uninstall
            ;;
        "client")
            debug "Client"


# msg "            -a, --action <action>          - указывает что делать: создать клиента, удалить клиента или получить список клиентов"
# msg "                                             значение должно быть из ACTION_CLIENT (add, del, list)"
# msg "                          a | add | new   :  создать файлы настроек для клиента на сервере и клиенте, файл QRcode для клиента"
# msg "                          d | del | delete:  удалить клиента из файла настроек сервера"
# msg "                          l | list        :  получить список клиентов из файла настроек сервера"
# msg "            -p, --params <filename>        - созданный при install файл с уточненными данными используется для создания файлов клиента"
# msg "            -d, --hand-params <filename>   - файл созданный вручную для определения дополнительных переменных для настройки клиентов"
# msg "                --ip4 <address/mask>       - ipv4 адрес с маской клиента"
# msg "                --ip6 <address/mask>       - ipv6 адрес с маской клиента"
# msg "            -e, --allowed-ips <network>    - список ip адресов, которым разрешен доступ в формате 1.1.1.0/24,fdoo::0/64,2.2.2.2/32"
# msg "                                             по-умолчанию только адрес клиента"
# msg "            -n, --name <name client>       - имя клиента"



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

########################
#### Начало скрипта ####
########################

main $@

exit
