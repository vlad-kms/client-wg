#!/bin/sh

main(){
  while [ ${#} -gt 0 ]; do
    case "${1}" in
      -t | --test)
        test=1
      ;;
      -m | --time)
        tm=$2
        shift 1
        tm=$((tm + 0)) 2>/dev/null 
      ;;
      *)
        echo "Неверный параметр: ${1}" >&2
        return 1
      ;;
    esac
    shift 1
  done
  test=${test:=0}
  tm=${tm:=3}
}

main "$@"
echo "Testing mode  : $(if [ "$test" = "0" ]; then echo OFF; else echo ON; fi)"
echo "Time handshake: $tm minute"

wg_v=$(wg show)
if [ "$test" = "1" ]; then
  # тест
  #wg_v="latest handshake: now\n latest handshake:  Now\n latest handshake:  month\n latest handshake:  2 ago\n latest handshake:  2 minute 24 second ago\n latest handshake:  4 minute 24 second ago\n latest handshake: ago\n latest handshake: dsgdfg"
  printf "Testing string:\n%s" "$wg_v"
  echo '------------------------------------------------------------'
fi

wg_v=$(echo "$wg_v" | grep latest | sed -En 's/^ *latest handshake: *(([^ ].*) *ago|(now)) *$/\1/Ip' | awk -v tm="${tm}" '{
  if ($0 !~ /day|hour|month|year/)
  {
    is_less=0
    if ($0 ~ /minute/) {
      if ($1 <= tm) print $0
    } else print $0
  }
}')

if [ "$1" = "test" ]; then
  printf "wg_v:\n%s" "$wg_v"
fi

# находим количество
if [ -n "$wg_v" ]; then
  wg_v=$(echo "$wg_v" | wc -l | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//')
else
  wg_v=0
fi
if [ "$1" = "test" ]; then
  echo "count: ${wg_v}"
else
  echo "$wg_v"
fi
 
exit 0
