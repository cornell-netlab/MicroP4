# Composing Dataplane Programs with μP4 - SIGCOMM '20

Instructions to reproduce results published in the paper titled "Composing Dataplane Programs with μP4".
μP4 supports to real targets, [v1model (BMv2)](https://github.com/hksoni/p4c/blob/master/p4include/v1model.p4) and [Tofino](https://www.barefootnetworks.com/products/brief-tofino/). It is necessary to use the specified versions of both architectures, because μP4C backends are target specific.

- v1model : https://github.com/hksoni/p4c.git
- Tofino : bf-sde-9.0.0

## How to Compile
μP4C requires target-specific architecture file to generate source. The compatible v1model.p4 is already available at [p4include/v1model.p4](https://github.com/cornell-netlab/MicroP4/blob/master/p4include/v1model.p4) path of this repository.

### To compile for v1model
```
make TARGET=v1model
```

### To compile for Tofino
It is required to provide path to Tofino's architecture files as an argument
```
make TARGET=tna
```

## Comiling on using p4c

BMV2 hash commit 8d9719ea7c7b59ece24feff58763a028f375a739

