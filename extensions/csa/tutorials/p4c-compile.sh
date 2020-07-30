#!/bin/bash
bold=$(tput bold)
normal=$(tput sgr0)

for prog in $*; do
  echo -e "${bold}\n*********************************"
  echo -e "Compiling program: ${prog}" 
  ${UP4ROOT}/extensions/csa/msa-examples/p4c/build/p4c --target bmv2 \
    --arch v1model --p4runtime-file  ${prog}rt --p4runtime-format json \
    --std p4-16 ${prog}
  echo -e "*********************************\n${normal}"
done
