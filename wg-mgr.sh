#!/bin/sh

# TODO Разобраться с DNS в Alpine linux. Пока в Alpine чистый список DNS для интерфейса сервера

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
ACTION_CLIENT_ADD='a add new'
ACTION_CLIENT_DEL='d del delete'
ACTION_CLIENT_LIST='l list'
DELIMITER_TITLE_CLIENT='[= ]*'
BEGIN_TITLE_CLIENT="###${DELIMITER_TITLE_CLIENT}Client${DELIMITER_TITLE_CLIENT}"

VARS_FOR_INSTALL="./vars4install.conf"
VARS_PARAMS="./params.conf"

DEF_SERVER_WG_NIC=wg0
DEF_SERVER_WG_IPV4=10.66.66.1
DEF_SERVER_WG_IPV4_MASK=24
DEF_SERVER_WG_IPV6=fc00:66:66:66::1
DEF_SERVER_WG_IPV6_MASK=64
DEF_SERVER_PORT=32124
DEF_CLIENT_DNS=1.1.1.1,1.0.0.1
DEF_ALLOWED_IPS=0.0.0.0/0,::/0

is_debug=0

# path_wg=/etc/wireguard
# path_wg=.
file_sysctl='/etc/sysctl.d/wg.conf'
def_file_hand_params="./hand_params.conf"
def_file_args='./last-args'
is_file_args=''

oi6='[0-9a-fA-F]{1,4}'
ai4='((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])'

show_help() {
    # -c -r -p -d -h -o -6 -w -f -u -a -l -n -x -i
    msg "Использование:"
    msg "wg-mgr.sh [command] [options]"
    msg "command (одна из [ ${ARR_CMD} ], по-умолчанию install):"
    msg "    install    - установка пакета wireguard и других, требующихся для работы (iptables, qrencode и др.)"
    msg "        options:"
    msg "            -c, --config <filename>        - файл с данными для инсталяции"
    msg "            -r, --rules-iptables <filename>- файл с правилами iptables (ip6tables)"
    msg "            -p, --params <filename>        - создается файл с уточненными данными после инсталяции"
    msg "            -d, --hand-params <filename>   - файл созданный вручную для определения дополнительных переменных"
    msg "            -i, --wg-nic <nic_name>        - имя интерфейса для установки сервера WIREGUARD"
    msg "                --ip4 <address/mask>       - IPv4 (ip/mask) сервера для установки сервера WIREGUARD"
    msg "                --ip6 <address/mask>       - IPv6 (ip/mask) сервера для установки сервера WIREGUARD"
    msg " "
    msg "    uninstall  - удаление пакета wireguard и других, установленных вместе с ним, а также удалить все созданные каталоги и файлы"
    msg " "
    msg "    prepare    - подготовить файл с данными для инсталяции"
    msg "        options:"
    msg "            -c, --config <filename> - файл для подготовки данных для инсталяции"
    msg "            -i, --wg-nic <nic_name>        - имя интерфейса для подготовки файла настроек для дальнейшей работы скрипта"
    msg "                --ip4 <address/mask>       - IPv4 (ip/mask) сервера для подготовки файла настроек для дальнейшей работы скрипта"
    msg "                --ip6 <address/mask>       - IPv6 (ip/mask) сервера для подготовки файла настроек для дальнейшей работы скрипта"
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
    msg "            -i, --wg-nic <nic_name>        - имя интерфейса сервера для подключения клиента"
    msg "                --ip4 <address/mask>       - IPv4 (ip/mask) клиента"
    msg "                --ip6 <address/mask>       - IPv6 (ip/mask) клиента"
    msg "            -e, --allowed-ips <network>    - список ip адресов, которым разрешен доступ в формате 1.1.1.0/24,fdoo::0/64,2.2.2.2/32"
    msg "                                             по-умолчанию только адрес клиента"
    msg "                --dns <dns1,dns2>          - список ip адресов DNS"
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
    msg "    -x, --allow-lxc            - флаг, что не блокировать установку WIREGUARD в контейнеры и VM LXD"
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

exec_cmd() {
    if [ -z "${dry_run}" ] || [ "${dry_run}" -eq "0" ]; then
        if [ "$is_debug" = "0" ]; then
            "$@" > /dev/null 2>&1
        else
            printf "${GREEN}" >&2
            "$@" >&2
            printf "${NC}" >&2
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
        debug "${res}"
    else
        local ttt="$@"
        printf "${PURPLE}Выполнить команду: '${ttt}'${NC}\n" 1>&2
    fi
    printf "${res}"
}

# 
install_packages() {
    debug "install_packages BEGIN ==================================="
    local ttt="$@"
    debug "install_packages, args: ${ttt}"
    # if [ -z "${ID}" ] || [ -z "{VERSION_ID}" ]; then
    if [ -z "${OS}" ] || [ -z "{VERSION_ID}" ]; then
        # . "${OS_RELEASE}"
        local os_data=$(check_os 2)
        OS="$(get_item_str "${os_data}" 'os')"
        VERSION_ID="$(get_item_str "${os_data}" 'version_id')"
    fi
    if [ -n "${ttt}" ]; then
        debug "install_packages, os_data: ${os_data}"
        if [ "${OS}" = 'debian' ] || [ "${OS}" = 'ubuntu' ] ; then
            # exec_cmd apt-get update
            local _cmd_="apt-get install -y ${ttt}"
        elif [ "${OS}" = 'alpine' ]; then
            # exec_cmd apk update
            local _cmd_="apk add ${ttt}"
        else
            local _cmd_=''
        fi
        if [ -n "${_cmd_}" ]; then
            debug "install_packages, выполняемая команда: ${_cmd_}"
            if [ -z "${dry_run}" ] || [ "${dry_run}" -eq "0" ]; then
                # if ! "$@"; then
                if [ -z "${is_debug}" ] || [ "${is_debug}" -eq "0" ]; then
                    ${_cmd_} > /dev/null
                else
                    printf "${GREEN}"
                    ${_cmd_} >&2
                    printf "${NC}"
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
        fi
    fi
    debug "install_packages END --==================================="
}

restart_wg() {
    debug "restart_wg BEGIN ==================================="
    if [ -z "${OS}" ] || [ -z "{VERSION_ID}" ]; then
        local os_data=$(check_os 2)
        OS="$(get_item_str "${os_data}" 'os')"
    fi
    local _sn='wg-quick'
    if [ "${OS}" = 'debian' ] || [ "${OS}" = 'ubuntu' ]; then
        local _sn="${_sn}@${SERVER_WG_NIC}"
    elif [ "${OS}" = 'alpine' ]; then
        local _sn="${_sn}.${SERVER_WG_NIC}"
    fi
    debug "restart_wg cmd: service ${_sn} restart"
    exec_cmd service "${_sn}" 'restart'
    debug "restart_wg END ====================================="
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

# проверить OS:
#   debian >=10
#   raspbian >=10
#   ubuntu >=18.4
#   alpine
# Так же можно проинициализировать ОС под себя (см. например если ОС Alpine)
# АРГУМЕНТЫ:
# $1 - как выводить сообщения
#   =0, то вывод красным цветом
#   =1, то вывод оранжевым цветом
#   =2, то НЕ выводить сообщений
# ВОЗВРАТ:
# $?
#   =0, поддерживаемая ОС
#   =1, НЕ поддерживаемая ОС
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
        # проверить что установлен coreutils, и если нет, то добавть в список устанавливаемых пакетов
        debug "OS: alpine"
    else
        local _msg_="Этот установщик на данный момент поддерживает только Debian, Ubuntu и Alpine"
        if [ "${is_out_err}" -eq "0" ]; then
            err "${_msg_}"
        elif [ "${is_out_err}" -eq "1" ]; then
            msg "${_msg_}"
        fi
        # exit 1
        local res_exit=1
    fi
    debug "OS: ${OS}"
    debug "VERSION_ID: ${VERSION_ID}"
    debug "res_exit: ${res_exit}"
    debug "check_os END ====================="
    printf "%s" "id=${OS}; version_id=${VERSION_ID}; notsupported=${res_exit}"
    return ${res_exit}
}

# вытащить из строки вида "имя1=знач1; имя2=знач2 имя3=знач3..." значение по имени
# $1    - строка с переменными
# $2    - имя переменной
# $3    - значение по-умолчанию
get_item_str() {
    debug "get_item_str BEGIN --- arg1: ${1} ;;; arg2: $2 ;;; arg3: $3 ==========================="
    if [ -n "${1}" ]; then
        local val="$(echo "${1}" | sed -En "s/^(.*[; \t])??(${2})\s*=\s*([^'\";][^; ]*|[\"][^\"]*\"|['][^']*')[; \t]?.*$/\3/p")"
        if [ -z "${val}" ]; then
            if [ -n "$3" ]; then
                local val="$3"
                local res=0
            else
                local val=""
                local res=1
            fi
        else
            local res=0
        fi
        printf "${val}"
    else
        printf ''
        local res=1
    fi
    debug "get_item_str END --- val: ${val}; res: ${res} ==========================="
    return $res
}

# Начальная инициализация перед выполнением скриптом основной части
init_os() {
    debug "init_os BEGIN ==============================="
    debug "init_os args: $@"
    local os_data="$(check_os 2)"
    local _os_="$(get_item_str  "${os_data}" "id")"
    OS="${_os_}"
    VERSION_ID="$(get_item_str  "${os_data}" "version_id")"
    if [ "${_os_}" = "alpine" ]; then
        # OS=alpine
        exec_cmd apk update
        # установить требуемые пакеты
        # проверить что установлен coreutils, и если нет, то добавть в список устанавливаемых пакетов
        if apk list --installed | grep coreutils > /dev/null; then
            local list_packet=''
        else
            local list_packet='coreutils'
        fi
        # проверить что установлен virt-what, и если нет, то добавть в список устанавливаемых пакетов
        if ! command -v virt-what >/dev/null; then
                local list_packet="${list_packet} virt-what"
        fi
        # проверить что установлен sed совместимый с GNU, и если нет, то добавть в список устанавливаемых пакетов
        sed_vers="$(sed --version | grep 'not GNU')"
        if [ -n "${sed_vers}" ]; then
            local list_packet="${list_packet} sed"
        fi
        install_packages "${list_packet}"
    elif [ "${_os_}" = "debian" ] || [ "${_os_}" = "ubuntu" ]; then
        printf "${GREEN}"
        exec_cmd apt-get update
        printf "${NC}"
    fi
    debug "init_os END ================================="
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
            err "Если хотите проигнорировать это условие и установить WIREGUARD в контейнер LXD используйте аргумент --allow-lxc (-x)."
            exit 1
        else
            msg "LXC не поддерживается."
            msg "Технически WireGuard может работать в контейнере LXC,"
            msg "но есть проблемы с модулями ядра и с настройкой Wireguard в контейнере."
            msg "Включен режим игнорирования этой ситуации и работа продолжится на Ваш страх и риск."
            msg "Чтобы выключить данный режим НЕ используйте аргумент --allow-lxc (-x)."
        fi
    fi
    debug "check_virt END ====================="
}

# TRIM
# Убрать м слева, и справа в строке $1 символы $2
# $2 по-умолчанию символьные пробелы \s (пробелы, табы, перевод строки)
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
# Убрать слева в строке $1 символы $2
# $2 по-умолчанию символьные пробелы \s (пробелы, табы, перевод строки)
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
# Убрать справа в строке $1 символы $2
# $2 по-умолчанию символьные пробелы \s (пробелы, табы, перевод строки)
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
# Если валидный - возвращается 0, 
# Иначе - возвращается 1
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
# Если валидная - возвращается 0, 
# Иначе - возвращается 1
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
# Если валидный - возвращается 0, 
# Иначе - возвращается 1
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
# Если валидная - возвращается 0, 
# Иначе - возвращается 1
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
    # debug "ip=${ip}; mask=${mask}"
    # debug "get_ip_mask_4 END ================================="
    printf "%s" "ip=${ip}; mask=${mask}"
}

# Распарсить строку IPv6 в адрес и маску
# $1 - ipv6/mask
# $2 - ip адрес по-умолчанию
# $3 - маска по-умолчанию
# $4 - флаг что для возврата, если в ${1} ошибочные адрес или маска, то будут подставляться или "${2}" или "${3}"
#      если он присутствует и не равен 0, то будут подстановки
#      если он отсутствует или   равен 0, то подстановок не будет и вместо ошибочного элемента будет возвращаться "" (пустая строка)
# Возвращает строку в формате 'ip=[addr_ipv6]; mask=[mask_ipv6]'
get_ip_mask_6() {
    local ip_full=$1
    local args="$@"
    # debug "get_ip_mask_6 BEGIN ================================"
    # debug "ARGS: ${args}"
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
    # debug "ip=${ip}; mask=${mask}"
    # debug "get_ip_mask_6 END =================================="
    printf "%s" "ip=${ip}; mask=${mask}"
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
    printf "INST_SERVER_PUB_NIC=${INST_SERVER_PUB_NIC}\n" > "${file_config}"
    # публичный адрес сервера
    INST_SERVER_PUB_IP=$(ip -4 addr show "$INST_SERVER_PUB_NIC" | sed -nE 's|^.*\sinet\s([^/]*)/.*\sscope global.*$|\1|p') # | awk '{print $1}' | head -1)
    if [ -z "${INST_SERVER_PUB_IP}" ]; then
        INST_SERVER_PUB_IP=$(ip -6 addr show "$INST_SERVER_PUB_NIC" | sed -nE 's|^.*\sinet6\s([^/]*)/.*\sscope global.*$|\1|p')
    fi
    printf "INST_SERVER_PUB_IP=${INST_SERVER_PUB_IP}\n" >> "${file_config}"
    # WIREGUARD interface NIC
    printf "INST_SERVER_WG_NIC=${INST_SERVER_WG_NIC:=${DEF_SERVER_WG_NIC}}\n" >> "${file_config}"
    # WIREGUARD SERVER IPv4/MASK
    # if [ -n "${ipv4}" ]; then
    #     local _ip_="${ipv4}"
    # else
    #     local _ip_="${DEF_SERVER_WG_IPV4}/${DEF_SERVER_WG_IPV4_MASK}"
    # fi
    # printf "INST_SERVER_WG_IPV4=${_ip_}\n" >> "${file_config}"
    printf "INST_SERVER_WG_IPV4=${INST_SERVER_WG_IPV4:=${DEF_SERVER_WG_IPV4}}/${INST_SERVER_WG_IPV4_MASK:=${DEF_SERVER_WG_IPV4_MASK}}\n" >> "${file_config}"

    # WIREGUARD SERVER IPv6/MASK
    # if [ -n "${ipv6}" ]; then
    #     local _ip_="${ipv6}"
    # else
    #     local _ip_="${DEF_SERVER_WG_IPV6}/${DEF_SERVER_WG_IPV6_MASK}"
    # fi
    # printf "INST_SERVER_WG_IPV6=${_ip_}\n" >> "${file_config}"
    printf "INST_SERVER_WG_IPV6=${INST_SERVER_WG_IPV6:=${DEF_SERVER_WG_IPV6}}/${INST_SERVER_WG_IPV6_MASK:=${DEF_SERVER_WG_IPV6_MASK}}\n" >> "${file_config}"
    # WIREGUARD SERVER PORT
    RANDOM_PORT=$(shuf -i49152-65535 -n1)
    printf "INST_SERVER_PORT=${RANDOM_PORT}\n" >> "${file_config}"
    # PRIVATE and PUBLIC KEY SERVER
    if command -v wg > /dev/null 2>&1; then
        # WIREGUARD SERVER PRIVATE KEY
        _priv_key=$(wg genkey)
        printf "INST_SERVER_PRIV_KEY=${_priv_key}\n" >> "${file_config}"
        # WIREGUARD SERVER PUBLIC KEY
        debug "PUBLIC_KEY: $(echo ${_priv_key} | wg pubkey)"
        printf "INST_SERVER_PUB_KEY=$(echo ${_priv_key} | wg pubkey)\n" >> "${file_config}"
    else
        # WIREGUARD SERVER PRIVATE KEY
        printf "INST_SERVER_PRIV_KEY=\n" >> "${file_config}"
        # WIREGUARD SERVER PUBLIC KEY
        printf "INST_SERVER_PUB_KEY=\n" >> "${file_config}"
    fi
    # FIRST DNS FOR CLIENT 
    printf "INST_CLIENT_DNS=${DEF_CLIENT_DNS}\n" >> "${file_config}"
    # Разрешенные адреса для клиента
    printf "INST_ALLOWED_IPS=${DEF_ALLOWED_IPS}\n" >> "${file_config}"
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
    printf "# сохраненные аргументы для запуска\n"              >  "${file_args}"
    # printf "is_debug=${_a_is_debug?:=0}\n"                      >> "${file_args}"
    # printf "dry_run=${_a_dry_run}\n"                            >> "${file_args}"
    # printf "use_ipv6=${_a_use_ipv6}\n"                          >> "${file_args}"
    # printf "nic_name=${nic_name}\n"                             >> "${file_args}"
    printf "path_wg=${_a_path_wg}\n"                            >> "${file_args}"
    printf "file_params=${_a_file_params}\n"                    >> "${file_args}"
    printf "file_hand_params=${_a_file_hand_params}\n"          >> "${file_args}"
    printf "path_out=${_a_path_out}\n"                          >> "${file_args}"
    printf "file_rules_firewall=${_a_file_rules_firewall}\n"    >> "${file_args}"
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
            printf "PostUp=${script_rules} add\n" >> "${FILE_CONF_WG}"
            printf "PostDown=${script_rules} delete\n" >> "${FILE_CONF_WG}"
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
    debug "file_config: ${file_config}"
    debug "pwd: $(pwd)"
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
        if [ -n "${ipv6_mask}" ] && [ -n "${is_digit}" ]; then
            # есть ipv6
            INST_SERVER_WG_IPV6="$(echo "${ipv6_mask}" | sed -En 's/^.*ip\s*=\s*([0-9a-fA-F:]+).*$/\1/p')"
            INST_SERVER_WG_IPV6_MASK="$(echo "${ipv6_mask}" | sed -En 's/^.*mask\s*=\s*([0-9]+).*$/\1/p')"
        fi
    else
        INST_SERVER_WG_IPV6=''
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
    if [ -z "${INST_CLIENT_DNS}" ]; then
        INST_CLIENT_DNS=$(_question "Первый DNS для клиентов" "${DEF_CLIENT_DNS}")
    fi
    # Разрешенные адреса для клиента
    # INST_ALLOWED_IPS=allowed address
    if [ -z "${INST_ALLOWED_IPS}" ]; then
        INST_ALLOWED_IPS=$(_question "Разрешенные адреса для сервера WG" "${DEF_ALLOWED_IPS}")
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
    debug "INST_CLIENT_DNS: ${INST_CLIENT_DNS}"
    debug "INST_ALLOWED_IPS: ${INST_ALLOWED_IPS}"
    # установка WIREGUARD
    if [ "${OS}" = 'ubuntu' ] || ([ "${OS}" = 'debian' ] && [ "${VERSION_ID}" -gt "10" ]); then
        # apt-get update > /dev/null 2>&1
        # exec_cmd apt-get update
        # exit
        # install_packages apt-get install -y wireguard iptables systemd-resolved qrencode
        install_packages wireguard iptables systemd-resolved qrencode ipcalc
    elif [ "${OS}" = 'alpine' ]; then
        # apk update > /dev/null 2>&1
        # exec_cmd apk update
        # install_packages apk add wireguard-tools iptables libqrencode-tools
        install_packages wireguard-tools iptables libqrencode-tools ipcalc
        # TODO Разобраться с DNS в Alpine linux. Пока в Alpine чистый список DNS для интерфейса сервера
        # INST_CLIENT_DNS=
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
    printf "SERVER_PUB_NIC=${INST_SERVER_PUB_NIC}\n" > "${file_params}"
    printf "SERVER_PUB_IP=${INST_SERVER_PUB_IP}\n" >> "${file_params}"
    printf "SERVER_WG_NIC=${INST_SERVER_WG_NIC}\n" >> "${file_params}"
    printf "SERVER_WG_IPV4=${INST_SERVER_WG_IPV4}\n" >> "${file_params}"
    printf "SERVER_WG_IPV4_MASK=${INST_SERVER_WG_IPV4_MASK}\n" >> "${file_params}"
    printf "SERVER_WG_IPV6=${INST_SERVER_WG_IPV6}\n" >> "${file_params}"
    printf "SERVER_WG_IPV6_MASK=${INST_SERVER_WG_IPV6_MASK}\n" >> "${file_params}"
    printf "SERVER_PORT=${INST_SERVER_PORT}\n" >> "${file_params}"
    printf "SERVER_PRIV_KEY=${INST_SERVER_PRIV_KEY}\n" >> "${file_params}"
    printf "SERVER_PUB_KEY=${INST_SERVER_PUB_KEY}\n" >> "${file_params}"
    printf "CLIENT_DNS=${INST_CLIENT_DNS}\n" >> "${file_params}"
    printf "ALLOWED_IPS=${INST_ALLOWED_IPS}\n" >> "${file_params}"
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
    debug "CLIENT_DNS: ${CLIENT_DNS}"
    debug "ALLOWED_IPS: ${ALLOWED_IPS}"

    # Настройка sysctl Включить форвардинг на сервере
    local c1="$(exec_cmd_with_result echo "net.ipv4.ip_forward = 1")"
    local c2="$(exec_cmd_with_result echo "net.ipv6.conf.all.forwarding = 1")"
    if [ -n "${c1}" ] && ([ -z "${dry_run}" ] || [ "${dry_run}" = "0" ]); then
        printf "${c1}\n" > "${file_sysctl}"
    fi
    if [ -n "${c2}" ] && ([ -z "${dry_run}" ] || [ "${dry_run}" = "0" ]); then
        printf "${c2}\n" >> "${file_sysctl}"
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
    printf "[Interface]\n" > "${FILE_CONF_WG}"
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
    printf "Address = ${_addr_wg_serv}\n"  >> "${FILE_CONF_WG}"
    printf "ListenPort = ${SERVER_PORT}\n" >> "${FILE_CONF_WG}"
    printf "PrivateKey = ${SERVER_PRIV_KEY}\n" >> "${FILE_CONF_WG}"
    # if [ -n "${CLIENT_DNS}" ]; then
    #     printf "DNS = ${CLIENT_DNS}\n" >> "${FILE_CONF_WG}"
    # fi
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
    # файл hand_params, дополнительные параметры
    printf "SSH_PORT=22\n" > "${file_hand_params}"
    printf "WG_PROTO=udp\n" >> "${file_hand_params}"
    local _net="$(ipcalc "${SERVER_WG_IPV4}/${SERVER_WG_IPV4_MASK}" | grep -e "^Network:" | sed -En "s/^Network:\s*([^ \t]*).*$/\1/p")"
    printf "WG_NET=${_net}\n" >> "${file_hand_params}"
    if [ "${OS}" = 'alpine' ]; then
        local _net="$(ipcalc "${SERVER_WG_IPV6}/${SERVER_WG_IPV6_MASK}" | grep -e "^Network:" | sed -En "s/^Network:\s*([^ \t]*).*$/\1/p")"
        printf "WG_NET6=${_net}\n" >> "${file_hand_params}"
    elif [ "${OS}" = 'debian' ] || [ "${OS}" = 'ubuntu' ]; then
        local _net="$(ipcalc "${SERVER_WG_IPV6}/${SERVER_WG_IPV6_MASK}" | grep -e "^Prefix:" | sed -En "s/^Prefix:\s*([^ \t]*).*$/\1/p")"
        printf "WG_NET6=${_net}\n" >> "${file_hand_params}"
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
    restart_wg
    debug "wg_install END =============================================="
}

wg_uninstall() {
    debug "wg_uninstall BEGIN ============================================"

    debug "wg_uninstall END =============================================="
}

# Поиск клиента по имени в файле конфигурации сервера
# $1 - имя клиента для поиска
search_client() {
    local _btc="${BEGIN_TITLE_CLIENT}"
    local _dtc="${DELIMITER_TITLE_CLIENT}"
    if [ -n "$1" ]; then
        if grep -E "^${_btc}${1}${_dtc}" "${_file_wg}" > /dev/null; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

# Удалить файлы настроек для клиента
# $1 имя клиента
# $2 имя файла настроек сервера ...wg<N>.conf
delete_client_config_serv() {
    local _btc="${BEGIN_TITLE_CLIENT}"
    local _dtc="${DELIMITER_TITLE_CLIENT}"
    if [ -n "$1" ]; then
        local clnt_cfg="$(_join_path "${path_out}" "${_name}-client.conf")"
        local serv_cfg="$(_join_path "${path_out}" "${_name}-server.conf")"
        local clnt_qrc="$(_join_path "${path_out}" "${_name}-qrcode.png")"
        rm "${clnt_cfg}" > /dev/null 2>&1
        rm "${serv_cfg}" > /dev/null 2>&1
        rm "${clnt_qrc}" > /dev/null 2>&1
        # удалить в файле конфигурации сервера инфу о клиенте
        if [ -n "$2" ]; then
            sed -i -En "/^${_btc}$1${_dtc}/,/^${_btc}$1${_dtc}/!p" "${2}"
        fi
    fi
}

# функция работы с клиентом
# $1 action
# $2 name
# клиенты в файле конфигурации wg<N>.conf описываются следующим образом
# ### Client=NAME_CLIENT=DESC CLIENT до конца строки
# остальные строки до следуюющей строки такого вида или до конца файла - это параметры Wireguard для этого клиента
client_action() {
    debug "client_action BEGIN ============================"
    debug "client_action; args: $(echo "$@")"
    local _name="$2"
    debug "_name: ${_name}"
    local _btc="${BEGIN_TITLE_CLIENT}"
    local _dtc="${DELIMITER_TITLE_CLIENT}"
    local _file_wg="$(realpath -m "$(_join_path "${path_wg}" "${SERVER_WG_NIC}.conf")")"
    debug "_file_wg: ${_file_wg}"
    case "$1" in
    'list')
        # найти IP адрес
        # local ip_cln="$(awk "/^${_btc}${cn}/{flag=1; next} /^${_btc}/{flag=0} flag" ./test/wg1.conf | sed -En 's/^\s*Address\s*=\s*(.*)$/\1/p')"
        # прочитать клиентов в файле SERVER_WG_NIC.conf
        debug "${_file_wg}"
        NUMBER_OF_CLIENTS="$(grep -c -E "^${_btc}" "${_file_wg}")"
        msg "В данной конфигурации ${_file_wg} клиентов ${NUMBER_OF_CLIENTS}:\n"
        msg "$(grep -E "^${_btc}" "${_file_wg}" | awk -F "${_dtc}" '{print $3"; "$4";"}' | nl -s ') ' -w 2)"
    ;;
    'del')
    ;;
    'add')
        # Подготовить адрес:порт для подключения клиента Wireguard
        # И если тип адреса SERVER_PUB_IP есть IPv6, то добавить по краям []
        if check_ipv6_addr "${SERVER_PUB_IP}"; then
            if ! _startswith "${SERVER_PUB_IP}" "["; then
                SERVER_PUB_IP="[${SERVER_PUB_IP}"
            fi
            if ! _endswith "${SERVER_PUB_IP}" "]"; then
                SERVER_PUB_IP="${SERVER_PUB_IP}]"
            fi
            debug "Адрес для подключения к серверу ${SERVER_PUB_IP}"
        elif check_ipv4_addr "${SERVER_PUB_IP}"; then
            debug "Адрес для подключения к серверу ${SERVER_PUB_IP}"
        else
            err "Неверный адрес ${SERVER_PUB_IP} для подключения к серверу Wireguard"
            exit 1
        fi
        # Найти в файле конфигурации сервера ListenPort и использовать значение как порт для подключения
        # Иначе взять ${SERVER_PORT}
        local _port="$(grep -E '^\s*ListenPort' "${_file_wg}" | sed -En 's/^\s*ListenPort\s*=\s*([0-9]*).*$/\1/p')"
        debug "_port: ${_port}"
        if [ -z "${_port}" ]; then
            local _poprt="${SERVER_PORT}"
        fi
        debug "_port: ${_port}"
        local _endpoint="${SERVER_PUB_IP}:${_port}"
        debug "_endpoint: ${_endpoint}"
        # AllowedIPs для клиента
        local _allowed_ips_client='0.0.0.0/0'
        if [ -n "${use_ipv6}" ] && [ "${use_ipv6}" = "1" ]; then
            local _allowed_ips_client="${_allowed_ips_client}, ::0/0"
        fi
        debug "_allowed_ips_client: ${_allowed_ips_client}"
        # IPv4 клиента
        if [ -z "${ipv4}" ]; then
            local _ipv4_client="${INST_SERVER_WG_IPV4}/32"
        else
            local _ipv4_client="$(get_item_str "$(get_ip_mask_4 "${ipv4}")" "ip")/32"
        fi
        # IPv6 клиента
        if [ -n "${use_ipv6}" ] && [ "${use_ipv6}" != 0 ]; then
            if [ -z "${ipv6}" ]; then
                local _ipv6_client="${INST_SERVER_WG_IPV6}/128"
            else
                local _ipv6_client="${ipv6}"
                local _ipv6_client="$(get_item_str "$(get_ip_mask_6 "${ipv6}")" "ip")/128"
            fi
        fi
        debug "_ipv4_client: ${_ipv4_client}"
        debug "_ipv6_client: ${_ipv6_client}"
        local _address="${_ipv4_client}"
        if [ -n "${use_ipv6}" ] && [ "${use_ipv6}" != "0" ] && [ -n "${_ipv6_client}" ]; then
            if [ -z "${_address}" ]; then
                local _address="${_ipv6_client}"
            else
                local _address="${_ipv4_client}, ${_ipv6_client}"
            fi
        fi
        debug "Address: ${_address}"
        # AllowedIPs для сервера
        if [ -n "${client_allowed_ips}" ]; then
            local _allowed_ips_srv="${client_allowed_ips}"
        else
            local _allowed_ips_srv="${_address}"
        fi
        debug "_allowed_ips_srv: ${_allowed_ips_srv}"
        # DNS для клиента $dns_list
        dns_list=${dns_list:=${DEF_CLIENT_DNS}}
        debug "dns_list: ${dns_list}"
        # сформировать ключи для клиента
        local _client_key_priv="$(wg genkey)"
        local _client_key_pub="$(echo ${_client_key_priv} | wg pubkey)"
        local _client_key_pkey="$(wg genpsk)"
        # создать файл для клиента
        local clnt_cfg="$(_join_path "${path_out}" "${_name}-client.conf")"
        local serv_cfg="$(_join_path "${path_out}" "${_name}-server.conf")"
        local clnt_qrc="$(_join_path "${path_out}" "${_name}-qrcode.png")"
        exec_cmd touch "${clnt_cfg}"
        exec_cmd touch "${serv_cfg}"
        exec_cmd chmod 0600 "${clnt_cfg}"
        exec_cmd chmod 0600 "${serv_cfg}"
        # найти клиента с именем ${_name}, и если есть, то сначала удалить строки из wg.conf для его конфигурации
        # и затем создать новые строки
        if search_client "${_name}"; then
            debug "Клиент с именем ${_name} уже есть. Его удаляем"
            delete_client_config_serv "${_name}" "${_file_wg}"
        fi
        # сформировать файлы конфигурации для клиента
        # [Interface]
        # PrivateKey = $client_key_priv
        # Address = 10.16.16.4/24
        # DNS = 9.9.9.9, 149.112.112.112
        #
        # [Peer]
        # PublicKey = $SERVER_PUB_KEY
        # PresharedKey = $client_key_pkey
        # Endpoint = 77.105.139.99:51820
        # AllowedIPs = 0.0.0.0/0, ::0/0
        printf "[Interface]\n"                          >  "${clnt_cfg}"
        printf "PrivateKey = ${_client_key_priv}\n"     >> "${clnt_cfg}"
        printf "Address = ${_address}\n"                >> "${clnt_cfg}"
        printf "DNS = ${dns_list}\n"                    >> "${clnt_cfg}"
        printf "\n"                                     >> "${clnt_cfg}"
        printf "[Peer]\n"                               >> "${clnt_cfg}"
        printf "PublicKey = ${SERVER_PUB_KEY}\n"        >> "${clnt_cfg}"
        printf "PresharedKey = ${_client_key_pkey}\n"   >> "${clnt_cfg}"
        printf "Endpoint = ${_endpoint}\n"              >> "${clnt_cfg}"
        printf "AllowedIPs = ${_allowed_ips_client}\n"  >> "${clnt_cfg}"
        # сформировать файлы конфигурации для сервера
        # ###=Client=ASUS_home= Description
        # [Peer]
        # PublicKey = $client_key_pub
        # PresharedKey = $client_key_pkey
        # AllowedIPs = 10.16.16.4/32
        # файл конфигурации для сервера в $path_out
        local _ip_desc="$( if [ -n ${_ipv4_client} ]; then echo ${_ipv4_client}; else echo ${_ipv6_client}; fi )"
        local title_client="### Client = ${_name} = ${_ip_desc}"
        debug "title_client: ${title_client}"
        printf "${title_client}\n"                      >  "${serv_cfg}"
        printf "[Peer]\n"                               >> "${serv_cfg}"
        printf "PublicKey = ${_client_key_pub}\n"       >> "${serv_cfg}"
        printf "PresharedKey = ${_client_key_pkey}\n"   >> "${serv_cfg}"
        printf "AllowedIPs = ${_allowed_ips_srv}\n"     >> "${serv_cfg}"
        printf "${title_client}\n"                      >> "${serv_cfg}"
        # теперь все тоже самое записать в файл конфигурации для сервера $_file_wg
        # printf "\n"                                     >> "${_file_wg}"
        printf "${title_client}\n"                      >> "${_file_wg}"
        printf "[Peer]\n"                               >> "${_file_wg}"
        printf "PublicKey = ${_client_key_pub}\n"       >> "${_file_wg}"
        printf "PresharedKey = ${_client_key_pkey}\n"   >> "${_file_wg}"
        printf "AllowedIPs = ${_allowed_ips_srv}\n"     >> "${_file_wg}"
        printf "${title_client}\n"                      >> "${_file_wg}"
        printf "\n"                                     >> "${_file_wg}"
        # сформировать QR-код для клиента
        if command -v qrencode &>/dev/null; then
            debug "Формируем QR-код для клиента в файл ${clnt_qrc}"
            qrencode -t ansiutf8 -l L -o "${clnt_qrc}" <"${clnt_cfg}"
        fi

    ;;
    esac

    debug "client_action END   ============================"
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

main() {
    debug "main BEGIN +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
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
                is_debug='1'
            ;;
            -h | --help)
                show_help
                exit 0
            ;;
            -6 | --use-ipv6)
                # TODO пока не реализовано, поэтому use_ipv6 = 0. Не реализовано из-за iptables6
                use_ipv6='1'
            ;;
            --dry-run)
                dry_run='1'
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
                local client_name="$2"
                shift
            ;;
            -x | --allow-lxc)
                # флаг, что не блокировать установку WIREGUARD в контейнеры и VM LXD"
                allow_lxc=1
            ;;
            -i | --wg-nic)
                # <nic_name>    - имя интерфейса сервера WIREGUARD"
                nic_name="$2"
                shift
            ;;
            --dns)
                # <dns1,dns2>   - список ip адресов DNS"
                dns_list="$2"
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
    debug "Инициализация...\n"
    # local r="$(check_os 2)"
    # TODO проверка $cmd временно для ускорения отладки, в ПРОД убрать
    if [ "${cmd}" != "client" ]; then
        if [ -z "${is_debug}" ] || [ "${is_debug}" = 0 ]; then
            init_os > /dev/null 2>&1
        else
            init_os
        fi
    fi
    # TODO проверка $cmd временно для ускорения отладки, в ПРОД убрать
    debug "Инициализация закончилась...\n"

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
        # local _a_is_debug=${_a_is_debug:=0}
        # local _a_dry_run=${_a_dry_run:=0}
        # local _a_use_ipv6=${_a_use_ipv6:=0}
        # local _a_nic_name="${_a_nic_name:=${DEF_SERVER_WG_NIC}}"
        local _a_path_wg="$(_add_current_dot "${_a_path_wg:=/etc/wireguard}")"
        local temp_path="$(_join_path "${_a_path_wg}" "$(_add_current_dot "${_a_file_params:="$VARS_PARAMS"}")")"
        local _a_file_params="$(realpath -m "${temp_path}")"
        local temp_path="$(_join_path "${_a_path_wg}" "$(_add_current_dot "${_a_file_hand_params:=${def_file_hand_params}}")")"
        local _a_file_hand_params="$(realpath -m "${temp_path}")"
        local temp_path="$(_join_path "${_a_path_wg}" ".clients")"
        local _a_path_out="$(realpath -m "$(_add_current_dot "${_a_path_out:=${temp_path}}")")"
        local _a_file_rules_firewall="$(_add_current_dot "${_a_file_rules_firewall:=./iptables/default-iptables.rules}")"
    fi
    # set_var is_debug ${is_debug} ${_a_is_debug}
    # set_var dry_run ${dry_run} ${_a_dry_run}
    # set_var use_ipv6 ${use_ipv6} ${_a_use_ipv6}
    # set_var nic_name "${nic_name}" "${_a_nic_name}"
    set_var path_wg "${path_wg}" "${_a_path_wg}"
    set_var file_params "${file_params}" "${_a_file_params}"
    set_var file_hand_params "${file_hand_params}" "${_a_file_hand_params}"
    set_var path_out "${path_out}" "${_a_path_out}"
    set_var file_rules_firewall "${file_rules_firewall}" "${_a_file_rules_firewall}"
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
        # записать в файл аргументы текущего запуска
        printf "# сохраненные аргументы для запуска\n"          >  "${file_args}"
        # printf "is_debug=${is_debug}\n"                         >> "${file_args}"
        # printf "dry_run=${dry_run}\n"                           >> "${file_args}"
        # printf "use_ipv6=${use_ipv6}\n"                         >> "${file_args}"
        # printf "nic_name=${nic_name}\n"                         >> "${file_args}"
        printf "path_wg=${path_wg}\n"                           >> "${file_args}"
        printf "file_params=${file_params}\n"                   >> "${file_args}"
        printf "file_hand_params=${file_hand_params}\n"         >> "${file_args}"
        printf "path_out=${path_out}\n"                         >> "${file_args}"
        printf "file_rules_firewall=${file_rules_firewall}\n"   >> "${file_args}"
    fi
    # аргументы, которые не сохраняются, не имеют значений по-умолчанию и не настраиваются предварительно
    if [ "${cmd}" = "client" ]; then
        # проверить на валидность action для cmd client
        local l_act=$(echo " ${ACTION_CLIENT} " | sed -rn "s/.*( $action ).*/\1/p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -z "${l_act}" ]; then
            err "Неверный аргумент --action ( or -a ) ${action}"
            show_help
            exit 1
        fi
    fi

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
    debug "nic_name____________: ${nic_name}"
    debug "ipv4________________: ${ipv4}"
    debug "ipv6________________: ${ipv6}"
    debug "client_allowed_ips__: ${client_allowed_ips}"
    debug "client_name_________: ${client_name}"
    debug "dns_list____________: ${dns_list}"
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

    # проверить наличие файла с конфигурацией для установки WG
    if check_file_exists 0 "${file_config}"; then
        . "${file_config}" #> /dev/null # 2>&1
    fi
    # переопределить переменную из файла file_config
    # INST_SERVER_WG_NIC
    if [ -n "${nic_name}" ]; then
        INST_SERVER_WG_NIC="${nic_name}"
    fi
    # INST_SERVER_WG_IPV4/INST_SERVER_WG_IPV4_MASK
    # WIREGUARD SERVER IPv4/MASK
    if [ -n "${ipv4}" ]; then
        local _ip_="$(get_ip_mask_4 "${ipv4}")"
        INST_SERVER_WG_IPV4="$(get_item_str "${_ip_}" "ip")"
        INST_SERVER_WG_IPV4_MASK="$(get_item_str "${_ip_}" "mask")"
    fi
    # INST_SERVER_WG_IPV6/INST_SERVER_WG_IPV6_MASK
    # WIREGUARD SERVER IPv6/MASK
    if [ -n "${ipv6}" ]; then
        local _ip_="$(get_ip_mask_6 "${ipv6}")"
        INST_SERVER_WG_IPV6="$(get_item_str "${_ip_}" "ip")"
        INST_SERVER_WG_IPV6_MASK="$(get_item_str "${_ip_}" "mask")"
    fi
    # INST_CLIENT_DNS
    # printf "INST_SERVER_WG_IPV4=${_ip_}\n" >> "${file_config}"

    case "$cmd" in
        "install")
            # Проверить что из под root и в противном случае прервать выполнение
            check_root
            # Проверить что выполняется в поддерживаемой OS, в противном случае прервать выполнение
            if ! check_os > /dev/null ; then
                err "Прервать выполнение: ОС не поддерживается" >&2
                exit 1
            fi
            local os_data="$(check_os)"
            ID="$(get_item_str "${os_data}" 'id')"
            OS="${ID}"
            VERSION_ID="$(get_item_str "${os_data}" 'version_id')"
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
            # проверить наличие файла с конфигурацией для установки WG
            if check_file_exists 0 "${file_params}"; then
                . "${file_params}"
            fi
            # заменить пременные аргументами командной строки
            # SERVER_WG_NIC
            if [ -n "${nic_name}" ]; then
                SERVER_WG_NIC="${nic_name}"
            fi
            # WIREGUARD SERVER IPv4/MASK
            if [ -n "${ipv4}" ]; then
                local _ip_="$(get_ip_mask_4 "${ipv4}")"
                SERVER_WG_IPV4="$(get_item_str "${_ip_}" "ip")"
                SERVER_WG_IPV4_MASK="$(get_item_str "${_ip_}" "mask")"
            fi
            # WIREGUARD SERVER IPv6/MASK
            if [ -n "${ipv6}" ]; then
                local _ip_="$(get_ip_mask_6 "${ipv6}")"
                SERVER_WG_IPV6="$(get_item_str "${_ip_}" "ip")"
                SERVER_WG_IPV6_MASK="$(get_item_str "${_ip_}" "mask")"
            fi
            # Проверить на валидность
            if [ -z "${SERVER_WG_IPV6}" ] || [ -z "${SERVER_WG_IPV6_MASK}" ]; then
                if [ -n "${use_ipv6}" && "${use_ipv6}" != "0" ]; then
                    err "Неверный IPv6 ${SERVER_WG_IPV6}/${SERVER_WG_IPV6_MASK}"
                    exit 1
                fi
            fi
            if [ -z "${SERVER_WG_IPV4}" ] || [ -z "${SERVER_WG_IPV4_MASK}" ]; then
                err "Неверный IPv4 ${SERVER_WG_IPV4}/${SERVER_WG_IPV4_MASK}"
                exit 1
            fi
            # Нормализировать action
            local _act="$(echo " ${ACTION_CLIENT} " | sed -rn "s/.*( $action ).*/\1/p" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            case "${_act}" in
                a | add | new)
                    action='add'
                ;;
                d | del | delete)
                    action='del'
                ;;
                l | list)
                    action='list'
                ;;
                default)
                    action=
                ;;
            esac
            client_action "${action}" "${client_name}"
        ;;
        "prepare")
            wg_prepare_file_config
        ;;
        *)
            err "Неверная команда: ${cmd}"
            show_help
        ;;
    esac

    debug "main END +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
}

########################
#### Начало скрипта ####
########################

main $@

exit
