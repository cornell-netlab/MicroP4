# Micro P4

MSA architecture
```bash
extensions/csa/p4include/msa.p4
```

# How to Build

```bash
git clone --recursive https://github.com/hksoni/microp4.git microp4
cd microp4
mkdir build
cmake .. -DCMAKE_BUILD_TYPE=DEBUG
make -j4
```

# How to Use

There are example module programs `l2.p4` and `l3.p4` at following location
```bash
./extensions/csa/msa-v2-example
```

Execute following set of commands from `microp4/build`
Currently, I have disabled arch flag for v1model. Default arch is tofino.
```bash

./p4c-msa  -o ../extensions/csa/msa-v2-example/l3.json ../extensions/csa/msa-v2-example/l3.p4

./p4c-msa -I ./p4include/ -l ../extensions/csa/msa-v2-example/l3.json  ../extensions/csa/msa-v2-example/modular-router.p4
```
