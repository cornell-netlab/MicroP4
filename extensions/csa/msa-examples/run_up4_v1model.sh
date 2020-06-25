#!/bin/bash

# PROGRAMS="routerv4_main routerv6_main routerv46_main"
PROGRAMS="router_ipv4v6_nat_acl"

BMV2_MININET_PATH=./bmv2/mininet/msa-examples
BMV2_SIMPLE_SWITCH_BIN=./bmv2/targets/simple_switch/simple_switch

for prog in $PROGRAMS; do
    sudo $BMV2_MININET_PATH/${prog}_sw.py --behavioral-exe $BMV2_SIMPLE_SWITCH_BIN \
      --num-hosts 2 --json ./build/${prog}_v1model/${prog}_v1model.json
done
