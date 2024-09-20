#!/bin/bash
# сгенерируем приватный ключ

WG_PRIVATE_KEY_CLIENT=''
WG_PUBLIC_KEY_CLIENT=''
WG_PSK_KEY_CLIENT=''
WG_PUBLIC_KEY_SERVER=''
WG_IP_CLIENT=''
WG_DNS='1.1.1.1'
WG_ENDPOINT='77.105.139.99:51820'
WG_ALLOWED_IPS='0.0.0.0/0, ::0/0'
WG_MASK_NET_CLIENT=24

path_files='./.out'

help(){
  # shellcheck disable=SC2016
  ts='dt="$(date +"%Y%m%d-%H%M%S")"; name="${name:=./.out/client-${dt}}"'
  _dt="$(date +"%Y%m%d-%H%M%S")"
  path_files="${path_files:=./.out}"
  echo "
  Использование:
    create-client.sh command options
    create-client.sh create-key options
    Команды:
    create-key  - создать ключи для клиента Wireguard
        Используемые опции:
          -n --name <STR>       - на оcновании на основании этого параметра будут сформированы имена файлов ключей по-умолчанию,
                                  если отсутствуют соответствующие опции.
                                  По-умолчанию: вычисляется как $ts,
                                  например: \"./.out/client-${_dt}\"
          -u, --key-pub <STR>   - имя файла с публичным ключом
                                  По-умолчанию: вычисляется как $(echo -n './.out/${name}-pub.key'),
                                  например: \"./.out/${name}-pub.key\"
          -k  --key-priv <STR>  - имя файла с приватным ключом. Создается во время create-key. Для чтения в других action.
                                  По-умолчанию: вычисляется как $(echo -n './.out/${name}-private.key'),
                                  например: \"./.out/${name}-private.key\"
          -p, --key-psk <STR>   - имя файла с Pre-Shared Key
                                  По-умолчанию: вычисляется как $(echo -n './.out/${name}-psk.key'),
                                  например: \"./.out/${name}-psk.key\"

    qr          - создать файл QR-код конфигурации клиента для подключения в приложении WireGuard Android
        Используемые опции:
          -n --name         - на оcновании на основании этого параметра будет сформировано имя файла конфигурации по-умолчанию,
                              если отсутствует опция --conf-client
                              По-умолчанию: вычисляется как $ts,
                              например: \"./.out/client-${_dt}\"
          -c --conf-client  - на оcновании этого файла и будет сформирован QR-код
                              По-умолчанию: вычисляется как $(echo -n './.out/${name}-client.conf'),
                              например: \"./.out/${name}-client.conf\"

    create-conf - создать файл конфигурации клиента на сервере WireGuard
        Используемые опции:
          -n --name <STR>         - на оcновании на основании этого параметра будут сформированы имена файлов конфигураций по-умолчанию,
                                    если отсутствуют соответствующие опции.
                                    По-умолчанию: вычисляется как $ts,
                                    например: \"./.out/client-${_dt}\"
          -u, --key-pub <STR>   - имя файла с публичным ключом
                                  По-умолчанию: вычисляется как $(echo -n './.out/${name}-pub.key'),
                                  например: \"./.out/${name}-pub.key\"
          -k  --key-priv <STR>  - имя файла с приватным ключом. Создается во время create-key. Для чтения в других action.
                                  По-умолчанию: вычисляется как $(echo -n './.out/${name}-private.key'),
                                  например: \"./.out/${name}-private.key\"
          -p, --key-psk <STR>   - имя файла с Pre-Shared Key
                                  По-умолчанию: вычисляется как $(echo -n './.out/${name}-psk.key'),
                                  например: \"./.out/${name}-psk.key\"
          -c, --conf-client <STR> - имя файла с конфигурацией клиента
                                    По-умолчанию: вычисляется как $(echo -n './.out/${name}-client.conf'),
                                    например: \"./.out/${name}-client.conf\"
          -s  --conf-server <STR> - имя файла с конфигурацией сервера
                                    По-умолчанию: вычисляется как $(echo -n './.out/${name}-server.conf'),
                                    например: \"./.out/${name}-server.conf\"
          -f, --file_pubkey_server <STR>- имя файла с публичным ключом сервера WireGuard
                                          По-умолчанию: etc/wireguard/keys/server_pub
          -i, --ip-client         - ip адрес назначаемый клиенту
                                    По-умолчанию: ''
          -m, --mask-client         - ip адрес назначаемый клиенту
                                    По-умолчанию: ''
              --dns-client        - DNS сервер назначаемый клиенту
                                    По-умолчанию: '1.1.1.1'
          '-e' | '--endpoint'     - EndPoint для подключения к серверу
                                    По-умолчанию: '77.105.139.99:51820'

    all       - выполнить все задачи по порядку: create-key, сreate-conf, qr

    Опции общие:
    -d, --debug                 - флаг вывода отладочных сообщений
        --debug-level <Num>     - не используется (пока)
                                  По-умолчанию: 2
    -r, --restart-server        - перезапустить сервис WireGuard после выполнения действий
    -t, --path-files            - путь где будут сохраняться выходные файлы, если они определены бех пути
                                  По-умолчанию: ./.out

    ${0}
    ${0} qr
    ${0} qr -c /etc/wireguard/config/client.conf
  "
}

_debug(){
  level=${level:=$DEBUG_LEVEL}
  if [[ $DEBUG -ne 0 ]]; then
    echo "debug(l-${level})::: $1" >&2
  fi
}

_startswith() {
  _str="$1"
  _sub="$2"
  echo "$_str" | grep -- "^$_sub" >/dev/null 2>&1
}

_create_key(){
  # _create_key
  _debug "##### Создание ключей (private, PSK, public) для клиента"
  # сгенерируем приватный ключ
  wg genkey | tee "$file_key_priv" > /dev/null
  # сгенерируем PSK ключ
  wg genpsk | tee "$file_key_psk" > /dev/null
  # сгенерируем публичный ключ
  wg pubkey < "$file_key_priv"| tee "$file_key_pub" > /dev/null
}

_create_conf(){
  # _create_conf
  # доинициализировать переменные для шаблонов
  WG_PRIVATE_KEY_CLIENT=$(sed -En 's/(.*)$/\1/p' "$file_key_priv")
  WG_PSK_KEY_CLIENT=$(sed -En 's/(.*)$/\1/p' "$file_key_psk")
  WG_PUBLIC_KEY_CLIENT=$(sed -En 's/(.*)$/\1/p' "$file_key_pub")
  WG_PUBLIC_KEY_SERVER=$(sed -En 's/(.*)$/\1/p' "$file_pubkey_server")

  _debug "##### Создание файлов с конфигурациями для клиента и для сервера"
  _debug "WG_IP_CLIENT: ${WG_IP_CLIENT}"
  _debug "WG_MASK_NET_CLIENT: ${WG_MASK_NET_CLIENT}"
  _debug "WG_DNS: ${WG_DNS}"
  _debug "WG_ENDPOINT: ${WG_ENDPOINT}"
  _debug "WG_ALLOWED_IPS: ${WG_ALLOWED_IPS}"
  _debug "WG_PRIVATE_KEY_CLIENT: ${WG_PRIVATE_KEY_CLIENT}"
  _debug "WG_PSK_KEY_CLIENT: ${WG_PSK_KEY_CLIENT}"
  _debug "WG_PUBLIC_KEY_CLIENT: ${WG_PUBLIC_KEY_CLIENT}"
  _debug "WG_PUBLIC_KEY_SERVER: ${WG_PUBLIC_KEY_SERVER}"

  eval "echo \"$(cat ./template-client.tmpl)\" > \"${file_conf_client}\""
  # генерируем файл для добавления к конфигу сервера
  eval "echo \"$(cat ./template-server.tmpl)\" >> \"${file_conf_server}\""
}

_create_qr(){
  # _create_qr "$name" "$file_conf_client" "$file_qr_code"
  _debug "##### Создание файла с QR кодом"
  _debug "##### name: $name"
  _debug "##### file_conf_client: $file_conf_client"
  _debug "##### file_qr_code: $file_qr_code"
  qrencode -t png -o "$file_qr_code" -r "$file_conf_client"
}

#============================================================================================
#============================================================================================
#============================================================================================
#declare -a array_env
# массив всех доступных action
#actions=(create-key qr create-conf all)

# новый разбор аргументов. Теперь если первый аргумент не начинается с '-', то это action, остальное опции
#args=$@
if ! _startswith "$1" '-'; then
  # здесь 1-й аргумент не начинается с '-', т.е. здесь первый аргумент, все остальное опции
  action="$1"
  shift
else
  action='qr'
fi

if ! args=$(getopt -u -o 'hk:p:u:c:s:q:n:df:i:e:a:m:r,t:' --long 'help,key-priv:,key-psk:,key-pub:,conf-client:,conf-server:,qr:,name:,debug,debug-level:,file-pubkey-server:,ip-client:,dns-client:,endpoint:,allow-addr:,mask-client:,restart-server,path-files:' -- "$@"); then
  help;
  exit 0;
fi

# DEFAULT значения
name="${name:=client-$(date +"%Y%m%d-%H%M%S")}"

set -- ${args}
#echo "$args"
i=0
for i; do
  case "$i" in
    '-h' | '--help')        help; exit 0;;
    '-k' | '--key-priv')    file_key_priv=${2};     shift 2;;
    '-p' | '--key-psk')     file_key_psk=${2};      shift 2;;
    '-u' | '--key-pub')     file_key_pub=${2};      shift 2;;
    '-c' | '--conf-client') file_conf_client=${2};  shift 2;;
    '-s' | '--conf-server') file_conf_server=${2};  shift 2;;
    '-q' | '--qr-file')     file_qr_code=${2};      shift 2;;
    '-n' | '--name')        name=${2};              shift 2;;
    '-d' | '--debug')       DEBUG=1;                shift;;
    '--debug-level')        DEBUG_LEVEL=${2};       shift 2;;
    '-f' | '--file-pubkey-server') file_pubkey_server=${2}; shift 2;;
    '-i' | '--ip-client')   WG_IP_CLIENT="${2}";    shift 2;;
    '-m' | '--mask-client') WG_MASK_NET_CLIENT="${2}"; shift 2;;
    '--dns-client')         WG_DNS="${2}";          shift 2;;
    '-e' | '--endpoint')    WG_ENDPOINT="${2}";     shift 2;;
    '-a' | '--allow-addr')  WG_ALLOWED_IPS="${2}";  shift 2;;
    '-r' | '--restart-server') restart_server=1;    shift;;
    '-t' | '--path-files')  path_files="$2";        shift 2;;
  esac
done

if ! [ -d "$path_files" ]; then
  mkdir "$path_files"
fi

# public key server WireGuard
file_pubkey_server="${file_pubkey_server:=/etc/wireguard/keys/server_pub}"
pubkey_server=$(sed -En 's/(.*)$/\1/p' "$file_pubkey_server")

# файл с приватным ключом клиента
file_key_priv="${file_key_priv:=${name}-private.key}"
#b="safsdfsdf"; aa=$(expr match "$b" '\(.*[\/].*\)'); echo $b; echo $aa; if [[ -z "$aa" ]]; then echo "not slash"; else echo "yes slash"; f
tfn="${file_key_priv}"
aa=$(expr "$tfn" : '\(.*[/].*\)')
if [[ -z $aa ]]; then
  _debug "Имя файла ${tfn} не содержит путей. Добавим к имени ${path_files}: ${path_files}/${tfn}"
  file_key_priv="${path_files}/${tfn}"
fi

# файл с PSK ключом клиента
file_key_psk="${file_key_psk:=${name}-psk.key}"
tfn="${file_key_psk}"
aa=$(expr "$tfn" : '\(.*[/].*\)')
if [[ -z $aa ]]; then
  _debug "Имя файла ${tfn} не содержит путей. Добавим к имени ${path_files}: ${path_files}/${tfn}"
  file_key_psk="${path_files}/${tfn}"
fi

# файл с публичным ключом клиента
file_key_pub="${file_key_pub:=${name}-public.key}"
tfn="${file_key_pub}"
aa=$(expr "$tfn" : '\(.*[/].*\)')
if [[ -z $aa ]]; then
  _debug "Имя файла ${tfn} не содержит путей. Добавим к имени ${path_files}: ${path_files}/${tfn}"
  file_key_pub="${path_files}/${tfn}"
fi

# файл с конфигурацией клиента
file_conf_client="${file_conf_client:=${name}-client.conf}"
tfn="${file_conf_client}"
aa=$(expr "$tfn" : '\(.*[/].*\)')
if [[ -z $aa ]]; then
  _debug "Имя файла ${tfn} не содержит путей. Добавим к имени ${path_files}: ${path_files}/${tfn}"
  file_conf_client="${path_files}/${tfn}"
fi
# файл с конфигурацией сервера
file_conf_server="${file_conf_server:=${name}-server.conf}"
tfn="${file_conf_server}"
aa=$(expr "$tfn" : '\(.*[/].*\)')
if [[ -z $aa ]]; then
  _debug "Имя файла ${tfn} не содержит путей. Добавим к имени ${path_files}: ${path_files}/${tfn}"
  file_conf_server="${path_files}/${tfn}"
fi
#file_conf_server="${file_conf_server:=/etc/wireguard/wg0.conf}"

# файл с конфигурацией клиента в формате QR-кода
file_qr_code="${file_qr_code:=${name}-qr.png}"
tfn="${file_qr_code}"
aa=$(expr "$tfn" : '\(.*[/].*\)')
if [[ -z $aa ]]; then
  _debug "Имя файла ${tfn} не содержит путей. Добавим к имени ${path_files}: ${path_files}/${tfn}"
  file_qr_code="${path_files}/${tfn}"
fi

restart_server="${restart_server:=0}"

DEBUG_LEVEL="${DEBUG_LEVEL:=2}"
_debug "name: $name"
_debug "file_pubkey_server: $file_pubkey_server"
_debug "pubkey_server: $pubkey_server"

_debug "debug: $DEBUG"
_debug "debug_level: $DEBUG_LEVEL"
_debug "action: ${action}"
_debug "file_key_priv: ${file_key_priv}"
_debug "file_key_psk: ${file_key_psk}"
_debug "file_key_pub: ${file_key_pub}"

_debug "file_conf_client: ${file_conf_client}"
_debug "file_conf_server: ${file_conf_server}"

_debug "file_qr_code: ${file_qr_code}"

_debug "restart_server: ${restart_server}"
_debug "path_files: ${path_files}"

#exit
case "$action" in
  "create-key")
      _create_key "$name" "$file_key_priv" "$file_key_psk" "$file_key_pub"
      ;;
  "create-conf")
      _create_conf
      ;;
  "qr")
      _create_qr
      ;;
  "all")
      _create_key "$name"
      _create_conf "$name" "$file_key_priv"
      _create_qr "$name" "$file_qr_code"
      ;;
esac
if [[ $restart_server -ne 0 ]]; then
  _debug "Restart WireGuard server..."
  systemctl restart wg-quick@wg0.service
  _debug "Ending restart..."
fi
