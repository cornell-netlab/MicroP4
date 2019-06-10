# MicroP4

architecture file is here:
https://github.com/cornell-netlab/p4-composition/blob/master/extensions/csa/p4include/csa.p4


./p4c-csa  -o ../extensions/csa/testdata/explicit-specialization/l2.json ../extensions/csa/testdata/explicit-specialization/l2.p4

./p4c-csa  -o ../extensions/csa/testdata/explicit-specialization/l3.json ../extensions/csa/testdata/explicit-specialization/l3.p4


./p4c-csa  --top4  MidEndLast -l ../extensions/csa/testdata/explicit-specialization/l2.json,../extensions/csa/testdata/explicit-specialization/l3.json  ../extensions/csa/testdata/explicit-specialization/l2l3.p4
