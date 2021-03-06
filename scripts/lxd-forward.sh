#!/usr/bin/env bash
cmd=$1
container_name=$2
container_port=$3
host_port=$4

function usage() {
  echo "Usage: $(basename ${0}) [add|list|delete] [container] [port] [host port]"
  exit 1
}

function error() {
  echo "$1"
  exit 1
}

test -n "$cmd" || usage

function list() {
  printf "Rule #\tCont\tIP\t\tHost port\tContainer port\n"
  containers=$(lxc list | grep RUNNING | awk '{print $2, $6}')
  echo "${containers}" | while read line; do
    c_name=$(echo $line | awk '{print $1}')
    c_ip=$(echo $line | awk '{print $2}')
    forwarded_ports=$(iptables -t nat --line-numbers -L --numeric | grep $c_ip)
    echo $forwarded_ports | while read ports_line; do
      test -z "${rule_no}" || break
      rule_no=$(echo $ports_line | awk '{print $1}')
      host_port=$(echo $ports_line | awk '{print $8}')
      host_port=$(echo $host_port | awk -F\: '{print $2}')
      container=$(echo $ports_line | awk '{print $9}')
      container=$(echo $container | awk -F\: '{print $3}')
      if [ "${rule_no}" != "" ]; then
        printf "${rule_no}\t${c_name}\t${c_ip}\t${host_port}\t${container}\n"
      fi
    done
  done
}

function forward() {
  c_name=$1
  c_port=$2
  h_port=$3
  container_info=$(lxc list $c_name | grep RUNNING | awk '{print $2, $6}' | grep $c_name)
  ip=$(echo -n $container_info | awk '{printf("%s",$2)}')
  test -n "$ip" || error "Container not found or not assigned an IP address"
  test -n "$c_port" || error "Container port not specified"
  test -n "$h_port" || h_port=$c_port

  iptables -t nat -A PREROUTING -p tcp -i enp0s8 --dport "$h_port" -j DNAT --to-destination "${ip}:${c_port}"
  netfilter-persistent save
}

function delete() {
  rule_no=$1
  test -n "${rule_no}" || error "Must specify rule no."
  iptables -t nat -D PREROUTING "${rule_no}"
  netfilter-persistent save
}

case "$cmd" in
  "list") list
  ;;
  "add") forward $container_name $container_port $host_port
  ;;
  "delete") delete $2 # Rule no.
  ;;
  *) usage
  ;;
esac