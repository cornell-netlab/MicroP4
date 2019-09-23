# ComposableP4

CSA architecture
extensions/csa/p4include/csa.p4


# How to Build

```bash
git clone --recursive https://github.com/cornell-netlab/p4-composition.git cp4
cd cp4
mkdir build
cmake .. -DCMAKE_BUILD_TYPE=DEBUG
make -j4
```

# How to Use

There are example module programs `l2.p4` and `l3.p4` at following location
```bash
/extensions/csa/testdata/explicit-specialization
```

Execute following set of commands from `cp4/build`
```bash
./p4c-csa  -o ../extensions/csa/testdata/explicit-specialization/l2.json ../extensions/csa/testdata/explicit-specialization/l2.p4

./p4c-csa  -o ../extensions/csa/testdata/explicit-specialization/l3.json ../extensions/csa/testdata/explicit-specialization/l3.p4

./p4c-csa  --arch=v1model -l ../extensions/csa/testdata/explicit-specialization/l2.json,../extensions/csa/testdata/explicit-specialization/l3.json  ../extensions/csa/testdata/explicit-specialization/l2l3.p4
```
