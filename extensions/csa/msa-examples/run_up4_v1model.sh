#!/bin/bash

PROGRAMS="routerv4 routerv6 routerv46"

BMV2_MININET_PATH=./bmv2/mininet/msa-examples
BMV2_SIMPLE_SWITCH_BIN=./bmv2/targets/simple_switch/simple_switch

for prog in $PROGRAMS; do
    sudo $BMV2_MININET_PATH/${prog}_sw.py --behavioral-exe $BMV2_SIMPLE_SWITCH_BIN \
      --num-hosts 2 --json ./build/${prog}_main_v1model/${prog}_main_v1model.json
done
