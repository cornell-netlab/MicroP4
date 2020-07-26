#!/bin/bash
bold=$(tput bold)
normal=$(tput sgr0)

PROGRAMS="routerv4_main routerv6_main routerv46_main router_ipv4v6_nat_acl router_ipv4v6srv6_main routerv46lrx_main router_ipv4srv4ipv6_main"

declare -A desc=( ["routerv4_main"]="Eth + IPv4 (P5)" \
["routerv6_main"]="Eth + IPv6 (P1)" \
["routerv46_main"]="Eth + IPv4 + IPv6 (P4)" \
["router_ipv4v6_nat_acl"]="Eth + IPv4 + IPv6 + NAT + NPT6 + ACL (P6)" \
["router_ipv4v6srv6_main"]="Eth + IPv4 + IPv6 + SRv6 (P3)" \
["routerv46lrx_main"]="Eth + IPv4 + IPv6 + MPLS (P2)" \
["router_ipv4srv4ipv6_main"]="Eth + IPv4 + IPv6 + SRv4 (P7)")

BMV2_MININET_PATH=./bmv2/mininet/msa-examples
BMV2_SIMPLE_SWITCH_BIN=./bmv2/targets/simple_switch/simple_switch
count=1

for prog in $PROGRAMS; do
    echo -e "${bold}\n*********************************" 
    echo -e "Test program: ${count} / 7" 
    echo -e "Corresponds to this from paper: " ${desc[$prog]}
    echo -e "Testing composed program: ${prog}${normal}" 
    read -n 1 -s -r -p "Press any key to continue ..."
    sudo $BMV2_MININET_PATH/${prog}_sw.py --behavioral-exe $BMV2_SIMPLE_SWITCH_BIN \
      --num-hosts 2 --json ./build/${prog}_v1model/${prog}_v1model.json
    echo -e ${bold}"Finished testing composed program: ${prog}" 
    echo -e "*********************************\n${normal}" 
    sleep 2
    let count=count+1
done
