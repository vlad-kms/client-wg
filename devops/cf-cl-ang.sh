#!/bin/bash

# shellcheck disable=SC2317
# shellcheck disable=SC2329

dir_root="${DIR_ROOT:-..}"
dir_temp="${DIR_TEMP:-.wg-temp/cl-ang}"
file_cfg="${FILE_CFG:-conf.conf}"

_prepare() {
  force=0
  if [ ! -f "${dir_root}/${dir_temp}/$file_cfg" ] || [ $force -eq 1 ]; then
    echo "Создаем файл конфигурации для инсталляции ${file_cfg}"
    "${dir_root}"/wg-mgr.sh prepare \
      --debug \
      --dry-run \
      --config "${dir_root}/${dir_temp}/${file_cfg}" \
      --wg-path "${dir_root}/${dir_temp}" \
      --rules-iptables "${dir_root}/nftables/nft.rules" \
      --wg-nic wg0 \
      --ip4 10.16.19.1/24 \
      --ip6 '' \
      --dns '1.1.1.1,1.0.0.1' \
      --allowed_ips '0.0.0.0/0' \
      "$@"
  else
    echo "Пропускаем создание файла конфигурации для инсталляции ${file_cfg}.
          Он уже есть и флаг Force не установлен.
          Либо удалите файл ${file_cfg}, либо замените в скрипте 'force=0' на 'force=1'"
  fi
}

_install() {
  "${dir_root}"/wg-mgr.sh install \
    --debug \
    --dry-run \
    --config "${dir_root}/${dir_temp}/${file_cfg}" \
    --wg-path "${dir_root}/${dir_temp}" \
    --rules-iptables "${dir_root}/nftables/nft.rules" \
    --wg-nic wg0 \
    --ip4 10.16.19.1/24 \
    --ip6 '' \
    --dns '1.1.1.1,1.0.0.1' \
    --option "WG_NET=10.16.19.0/24" \
    --option "WG_PROTO=udp; SSH_PORT=22" \
    --option "NFT_COUNTER=counter; NFT_SEARCH_DOMAIN_LOCALNET=\"home.lan klinika.lan\"" \
    --option "PROVIDER_GW_MAC=" \
    --option "NFT_NAT_NET=\"192.168.15.0/24, 192.168.16.0/24,192.168.22.0/24, 192.168.25.0/24,192.168.26.0/24\"" \
    --option "NFT_LIST_TRUST_WAN='vi.vpn.mrovo.ru, cl.vpn.mrovo.ru,v4v.vpn.mrovo.ru,fn.vpn.mrovo.ru'" \
    --option "NFT_LIST_TRUST_VPN=\"10.16.19.2,10.16.19.3,10.16.19.4,10.16.19.5,10.16.19.6,10.16.19.7,10.16.19.254,192.168.15.0/24,192.168.16.0/24\"" \
    --option "NFT_LIST_VPN='10.16.19.102'" \
    --option "NFT_LIST_VPN_ONLY='10.16.19.100'" \
    --option "NFT_LIST_INET_DROP='10.16.19.101, 10.16.19.103'" \
    --option "NFT_DNS_LOCALNET=192.168.15.3" \
    --option 'NFT_ALLOWED_SERVICES="tcp . 80, tcp . 443, tcp . 5201, udp . 5000, tcp . 10051, tcp . 162"' \
    --option 'NFT_ALLOWED_SERVICES_VPN="tcp . 8080, tcp . 5201, tcp . 10051"' \
    --option 'NFT_FILENAME_CUSTOM_RULES=' \
    "$@"
}

is_true=0
act="$1"
shift 1

mkdir -p "${dir_root}/${dir_temp}"

if [[ "$act" =~ p ]]; then
  echo "prepare"
  is_true=1
  _prepare "$@"
fi
if [[ "$act" =~ i ]]; then
  echo "install"
  is_true=1
  _install "$@"
fi
if [ "$is_true" -eq 1 ]; then
  echo "Выполнено"
else
  echo "Не указано что делать"
fi

exit 0
