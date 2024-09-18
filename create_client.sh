# сгенерируем приватный ключ

DEBUG_LEVEL=2

help(){
  echo "
  Использование:
    create-client.sh command options
    Команды:
    create-key  - создать ключи для клиента Wireguard
    qr          - создать файл QR-код конфигурации клиента для подключения в приложении WireGuard Android
    create-conf - создать файл конфигурации клиента на сервере WireGuard
    all         - выполнить все задачи по порядку: create-key, сreate-conf, qr

    Опции для команд:
    -k  --key-priv              - имя файла с приватным ключом. Создается во время create-key. Для чтения в других action.
    -p, --key-psk               - имя файла с Pre-Shared Key
    -u, --key-pub               - имя файла с публичным ключом
          Эти опции используются во время create-key для создания файлов.
          Для чтения в других action.
        
    -c, --conf-client           - имя файла с конфигурацией клиента
    -s  --conf-server           - имя файла с конфигурацией сервера
          Эти опции используются во время create-conf для создания файлов.
          Для чтения в других action (qr).
        
    -q, --qr                    - имя файла с QR кодом
          Эта опция используется во время qr для создания файла.
  "
}

_debug(){
  level=$2
  level=${level:=$DEBUG_LEVEL}
  if [[ $DEBUG -ne "0" ]]; then
    echo "debug(l${level})::: $1" > 2
  fi
}

_startswith() {
  _str="$1"
  _sub="$2"
  echo "$_str" | grep -- "^$_sub" >/dev/null 2>&1
}


nm="$1"
dt="$(date +"%Y%m%d-%H%M%S")"
name="${nm:=client-$dt}"

declare -a array_env
# массив всех доступных action
actions=(create-key qr create-conf all)


# новый разбор аргументов. Теперь если первый аргумент не начинается с '-', то это action, осталное опции для action
# action: add, backup, delete, decode-file, encode-file, export
#args=$@
if ! _startswith "$1" '-'; then
  # здесь 1-й аргумент не начинается с '-', т.е. здесь первый аргумент, все остальное опции
  action="$1"
  shift
else
  action='qr'
fi

if ! args=$(getopt -u -o 'k:p:u:c:s:q:d' --long 'key-priv:,key-psk:,key-pub:,conf-client:,conf-server:,qr:debug,debug-level:' -- "$@"); then
  help;
  exit 0;
fi

set -- $args
_debug "$args"
i=0
for i; do
  case "$i" in
    '-k' | '--key-priv')    file_key_priv=${2};     shift 2;;
    '-p' | '--key-psk')     file_key_psk=${2};      shift 2;;
    '-u' | '--key-pub')     file_key_pub=${2};      shift 2;;
    '-c' | '--conf-client') file_conf_client=${2};  shift 2;;
    '-s' | '--conf-server') file_conf_server=${2};  shift 2;;
    '-q' | '--qr')          file_qr_code=${2};      shift 2;;
    '-d' | '--debug')       DEBUG=1;                shift;;
    '--debug-level')        DEBUG_LEVEL="${1}";     shift 2;;
  esac
done
echo $DEBUG

_debug "debug: $DEBUG"

file_key_priv="${file_key_priv:=${name}-private.key}"
file_key_psk="${file_key_psk:=${name}-psk.key}"
file_key_pub="${file_key_pub:=${name}-public.key}"

file_conf_client="${file_conf_client:=${name}-client.conf}"
file_conf_server="${file_conf_server:=${name}-server.conf}"

file_qr_code="${file_qr_code:=${name}-qr.png}"

_debug "action: ${action}"
_debug "file_key_priv: ${file_key_priv}"
_debug "file_key_psk: ${file_key_psk}"
_debug "file_key_pub: ${file_key_pub}"

_debug "file_conf_client: ${file_conf_client}"
_debug "file_conf_server: ${file_conf_server}"

_debug "file_qr_code: ${file_qr_code}"

exit

#wg genkey | tee "${name}_private.key"
#wg genpsk | tee "${name}_psk.key"
# сгенерируем публичный ключ
#cat "${name}_private.key" | wg pubkey | tee "${name}_public.key"

# from https://timeweb.cloud/tutorials/network-security/wireguard-na-svoem-servere
#wg genkey | tee /etc/wireguard/user1_privatekey | wg pubkey | tee /etc/wireguard/user1_publickey
# generate QR code
qrencode -t png -o "${name}-qr.png" -r  "${name}.conf"
