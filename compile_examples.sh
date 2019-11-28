#!/bin/bash
cd build/ 
echo "Compiling submodules"
./p4c-msa -o ../extensions/csa/msa-v2-example/ecnv4.json ../extensions/csa/msa-v2-example/ecnv4.p4
./p4c-msa -o ../extensions/csa/msa-v2-example/ecnv6.json ../extensions/csa/msa-v2-example/ecnv6.p4
./p4c-msa -o ../extensions/csa/msa-v2-example/l3v4.json ../extensions/csa/msa-v2-example/l3v4.p4
./p4c-msa -o ../extensions/csa/msa-v2-example/l3v6.json ../extensions/csa/msa-v2-example/l3v6.p4
./p4c-msa -o ../extensions/csa/msa-v2-example/Filter_L4.json ../extensions/csa/msa-v2-example/Filter_L4.p4
./p4c-msa -o ../extensions/csa/msa-v2-example/Nat_L4.json ../extensions/csa/msa-v2-example/Nat_L4.p4
./p4c-msa -o ../extensions/csa/msa-v2-example/Nat_L3.json ../extensions/csa/msa-v2-example/Nat_L3.p4
echo "Compiling composed modules"
./p4c-msa --arch=v1model -l ../extensions/csa/msa-v2-example/l3v4.json ../extensions/csa/msa-v2-example/modular-routerv4.p4
./p4c-msa --arch=v1model -l ../extensions/csa/msa-v2-example/l3v6.json ../extensions/csa/msa-v2-example/modular-routerv6.p4
./p4c-msa --arch=v1model -l ../extensions/csa/msa-v2-example/ecnv4.json,../extensions/csa/msa-v2-example/l3v4.json ../extensions/csa/msa-v2-example/modular-qosrouterv4.p4
./p4c-msa --arch=v1model -l ../extensions/csa/msa-v2-example/ecnv6.json,../extensions/csa/msa-v2-example/l3v6.json ../extensions/csa/msa-v2-example/modular-qosrouterv6.p4 
./p4c-msa --arch=v1model -l ../extensions/csa/msa-v2-example/Filter_L4.json,../extensions/csa/msa-v2-example/l3v4.json ../extensions/csa/msa-v2-example/modular-firewall.p4
./p4c-msa --arch=v1model -l ../extensions/csa/msa-v2-example/Nat_L4.json ../extensions/csa/msa-v2-example/Nat_L3.p4
./p4c-msa --arch=v1model -l ../extensions/csa/msa-v2-example/Nat_L3.json ../extensions/csa/msa-v2-example/modular-nat.p4

