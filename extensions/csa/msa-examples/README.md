# Composing Dataplane Programs with μP4 - SIGCOMM '20

Instructions to reproduce results published in the paper titled "Composing Dataplane Programs with μP4".
μP4 supports two real targets, [v1model (BMv2)](https://github.com/hksoni/p4c/blob/master/p4include/v1model.p4) and [Tofino](https://www.barefootnetworks.com/products/brief-tofino/). It is necessary to use the specified versions of both architectures, because μP4C backends are target specific.

- v1model : https://github.com/hksoni/p4c.git
- Tofino : bf-sde-9.0.0

## Prerequisites
Download and compile μP4C along with associated version of p4c and BMv2 from [here](https://github.com/cornell-netlab/MicroP4/blob/master/README.md).

## How to Compile Examples
μP4C requires target-specific architecture file to generate source. The compatible v1model.p4 is already available at [p4include/v1model.p4](https://github.com/cornell-netlab/MicroP4/blob/master/p4include/v1model.p4) path of this repository.

### To compile for v1model
```
make TARGET=v1model
```

### To compile for Tofino
```
make TARGET=tna
```


## Using BMv2
```
 sudo ./bmv2/mininet/msa-examples/routerv4_sw.py --behavioral-exe ./bmv2/targets/simple_switch/simple_switch --num-hosts 2 --mode l3  --json ./p4c/build/v1model/routerv4-main-v1model.json
```

