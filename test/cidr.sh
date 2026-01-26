#!/bin/sh

# Универсальная проверка CIDR
in_cidr_ipv4() {
    ip=$1; cidr=$2
    IFS=./; set -- $ip $cidr; unset IFS
    [ $# -ne 9 ] && return 1
#echo $#
#echo $1
#echo $2
#echo $3
#echo $4
#echo $5
#echo $6
#echo $7
#echo $8
#echo $9

    # IP: $1.$2.$3.$4
    # Network: $5.$6.$7.$8/$9
    # Mask bits: $9
                                
    ip_num=$(( ($1<<24) + ($2<<16) + ($3<<8) + $4 ))
    net_num=$(( ($5<<24) + ($6<<16) + ($7<<8) + $8 ))
    mask_bits=$9
    mask_num=$(( 0xFFFFFFFF << (32 - mask_bits) & 0xFFFFFFFF ))
    echo "ip_num: $ip_num"
    echo "net_num: $net_num"
    echo "mask_bits: $mask_bits"
    echo "mask_num: $mask_num"
    
    [ $(( ip_num & mask_num )) -eq $(( net_num & mask_num )) ] && return 0 || return 1
}

#echo $(in_cidr_ipv4 172.16.1.1 172.16.0.0/16)