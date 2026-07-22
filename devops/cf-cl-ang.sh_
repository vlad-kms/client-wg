#!/bin/bash

_prepare() {
  ../wg-mgr.sh prepare -c ./conf-cl-ang.conf -i wg0 --ip4 10.16.19.1/24 --dns '1.1.1.1,1.0.0.1' -w ../.wg-temp \
    -r ../nftables/nft.rules \
    --debug --dry-run \
    -t "WG_PROTO=udp; SSH_PORT=22" \
    -t "NFT_COUNTER=counter; NFT_SEARCH_DOMAIN_LOCALNET=\"home.lan klinika.lan\";"
    cat ../.wg-temp/params.conf
}

_install() {
  ../wg-mgr.sh install -c ./conf-cl-ang.conf -i wg0 --ip4 10.16.19.1/24 --dns '1.1.1.1,1.0.0.1' -w ../.wg-temp \
    -r ../nftables/nft.rules \
    --debug --dry-run \
    -t "WG_NET=10.16.19.0/24" \
    -t "WG_PROTO=udp; SSH_PORT=22" \
    -t "NFT_COUNTER=counter; NFT_SEARCH_DOMAIN_LOCALNET=\"home.lan klinika.lan\"" \
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
    $@
}

is_true=0
if [[ "$1" =~ p ]]; then
  echo "prepare"
  is_true=1
  _prepare
fi
if [[ "$1" =~ i ]]; then
  echo "install"
  is_true=1
  _install
fi
if [ "$is_true" -eq 1 ]; then
  cat ./hand_params.conf
else
  echo "Не указано что делать"
fi


#  --option "WG_NET=10.16.18.0/24" \
exit 0




NFT_MAP_DNAT=" type inet_proto . inet_service : ipv4_addr . inet_service;
  elements={
    tcp . 80   : 192.168.15.79 . 80,
    tcp . 443  : 192.168.15.79 . 443,
    tcp . 8080 : 192.168.16.79 . 80,
    tcp . 8443 : 192.168.16.79 . 443
  }
"
NFT_MAP_FORWARD_ACL=" type ipv4_addr . inet_proto . inet_service : verdict;
  elements={
    192.168.15.79 . tcp . 80  : accept,
    192.168.15.79 . tcp . 443 : accept,
    192.168.16.79 . tcp . 80  : accept,
    192.168.16.79 . tcp . 443 : accept
  }
"