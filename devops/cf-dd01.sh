#!/bin/bash

# dir_devops=devops
dir_temp=.wg-temp
dir_=dd01.home.lan
file_cfg="../${dir_temp}/${dir_}/cfg.conf"

_prepare() {
  # изменить на force=1, чтобы принудительно создать файл пред-конфигурации пред install
  force=0
  if [ ! -f "$file_cfg" ] || [ $force -eq 1 ]; then
    echo "File create ${file_cfg}"
    ../wg-mgr.sh prepare \
      --debug \
      --dry-run \
      --config "${file_cfg}" \
      --wg-nic wg13 \
      --ip4 172.25.25.254/24 \
      --dns '1.1.1.1' \
      --wg-path "../${dir_temp}/${dir_}" \
      --allowed_ips '0.0.0.0/0' \
      "$@"
  fi
}

_install() {
  ../wg-mgr.sh install \
    --debug \
    --dry-run \
    --config "${file_cfg}" \
    --wg-nic wg13 \
    --ip4 172.25.25.254/24 \
    --dns '1.1.1.1,1.0.0.1' \
    --rules-iptables ../nftables/nft.rules \
    --wg-path "../${dir_temp}/${dir_}" \
    --option "WG_PROTO=udp; NFT_SEARCH_DOMAIN_LOCALNET=\"dom1.as dom2.as\"; SSH_PORT=22" \
    --option "NFT_LIST_VPN_ONLY=\"192.168.15.55, 192.168.16.55\"" \
    --option "SSH_PROTO=UUU;NFT_LIST_TRUST_WAN='192.168.15.0/24'; NFT_LIST_TRUST_VPN='192.168.16.0/24'" \
    --option "NFT_MAP_FORWARD_ACL_BEFORE_DNAT='192.168.1.1 . udp . 80 : accept,
    192.168.1.2 . udp . 81 : accept, 192.168.1.3 . udp . 82 : accept'
    " \
    --option "NFT_MAP_DNAT=\"tcp . 80   : 192.168.15.79 . 80,
        tcp . 443  : 192.168.15.79 . 443,
      \"" \
    --option 'NFT_USE_ARP_TABLE=1' \
    --option "NFT_ALLOWED_SERVICES='tcp . 1-65500, udp . 1-65500'" \
    --option "NFT_ALLOWED_SERVICES_VPN='tcp . 8080, tcp . 8443'" \
    "$@"
}

is_true=0
act="$1"
shift 1
#echo $@

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

