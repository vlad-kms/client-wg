#!/bin/bash

# shellcheck disable=SC2317
# shellcheck disable=SC2329

dir_root="${DIR_ROOT:-..}"
dir_temp="${DIR_TEMP:-.wg-temp/4v}"
file_cfg="${FILE_CFG:-conf.conf}"

_prepare() {
  force=0
  if [ ! -f "${dir_root}/${dir_temp}/${file_cfg}" ] || [[ $force -eq 1 ]]; then
    echo "Создаем файл конфигурации для инсталляции ${file_cfg}"
    "${dir_root}"/wg-mgr.sh prepare \
      --debug \
      --dry-run \
      --config "${dir_root}/${dir_temp}/${file_cfg}" \
      --wg-path "${dir_root}/${dir_temp}" \
      --rules-iptables "${dir_root}/nftables/nft.rules" \
      --wg-nic awg0 \
      --ip4 10.9.8.1/24 \
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
    --wg-path "${dir_root}/$dir_temp" \
    --rules-iptables "${dir_root}/nftables/nft.rules" \
    --wg-nic awg0 \
    --ip4 10.9.8.1/24 \
    --ip6 '' \
    --dns '192.168.15.3' \
    -t "NFT_COUNTER=counter; NFT_SEARCH_DOMAIN_LOCALNET=\"home.lan klinika.lan\"" \
    --option "PROVIDER_GW_MAC=\"08:05:e2:fa:07:f0\"" \
    --option "NFT_LIST_VPN_ONLY="\
    --option "NFT_LIST_TRUST_VPN=" \
    --option "NFT_NAT_NET=\"10.16.19.1/32, 192.168.15.0/24, 192.168.16.0/24,192.168.22.0/24,192.168.25.0/24,192.168.26.0/24\"" \
    --option "NFT_LIST_TRUST_WAN='cl.vpn.mrovo.ru, cl-ang.vpn.mrovo.ru'" \
    --option "NFT_LIST_VPN_ONLY=" \
    --option "NFT_LIST_INET_DROP=" \
    --option "NFT_LIST_TRUST_VPN=\"192.168.15.202,10.9.8.2,10.9.8.3,10.9.8.4,10.9.8.5,10.9.8.6,10.9.8.7,192.168.16.55\"" \
    --option "NFT_DNS_LOCALNET=192.168.15.3" \
    --option 'NFT_MAP_FORWARD_ACL="192.168.15.79 . tcp . 80 : accept, 192.168.15.79 . tcp . 443 : accept"' \
    --option 'NFT_MAP_DNAT="
        tcp . 443 : 192.168.15.79 . 443,
        tcp . 80 : 192.168.15.79 . 80
      "' \
    --option 'NFT_USE_ARP_TABLE=1' \
    "$@"
}

is_true=0
act="$1"
shift 1

# echo "dir_root=$dir_root"
# echo "dir_temp=$dir_temp"
# echo "file_cfg=$file_cfg"
# echo "$@"
# exit

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
  echo "Running script"
  # cat ./hand_params.conf
else
  echo "Не указано что делать"
fi

exit 0
