#!/bin/bash
bold=$(tput bold)
normal=$(tput sgr0)

PROGRAMS="Router_v1model"

BMV2_MININET_PATH=${UP4ROOT}/extensions/csa/msa-examples/bmv2/mininet/tutorials
BMV2_SIMPLE_SWITCH_BIN=${UP4ROOT}/extensions/csa/msa-examples/bmv2/targets/simple_switch/simple_switch

P4_MININET_PATH=${UP4ROOT}/extensions/csa/msa-examples/bmv2/mininet

for prog in $PROGRAMS; do
    echo -e "${bold}\n*********************************" 
    echo -e "Running Tutorial program: ${prog}${normal}" 
    sudo bash -c "export P4_MININET_PATH=${P4_MININET_PATH} ;  \
      $BMV2_MININET_PATH/${prog}_sw.py --behavioral-exe $BMV2_SIMPLE_SWITCH_BIN \
      --num-hosts 2 --json ./${prog}.json"
    echo -e "*********************************\n${normal}" 
done
