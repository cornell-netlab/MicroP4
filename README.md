# μP4

## Overview
μP4 is a framework for programming data plane of network devices in a portable, modular and composable manner. It comprises 
1. μP4 Architecture (μPA) - a logical Architecture for data plane
2. μP4 Compiler (μP4C) - to compile data plane programs written against μPA 
3. μP4 Language - A subtle variant of [P4-16](https://p4.org/p4-spec/docs/P4-16-v1.2.1.html)

μP4 allows to build libraries of packet-processing functions in data plane, reuse them to develop new programs and compile the programs to architectures of real target devices. μP4 maps its logical architecture to real targets like v1model and Tofino.

Using μP4C, programmers can 
1. Compile code to libraries (in form of `.json` files)
2. Generate P4-16 source (`.p4`) specific to a given target architecture (v1model
   or tna)

μP4C-generated `.p4` should be used with target-specific P4-16 compiler backends
to generate executable.


## Getting started
μP4C is developed by extending a fork repo `https://github.com/hksoni/p4c.git` of P4_16 prototype compiler `https://github.com/p4lang/p4c.git`

1. Install Dependencies
Follow the instructions listed at `https://github.com/hksoni/p4c#dependencies`.

2. Install μP4C
```bash
git clone --recursive https://github.com/hksoni/microp4.git microp4
cd microp4
mkdir build
cmake ..  or cmake .. -DCMAKE_BUILD_TYPE=DEBUG 
make -j4
```
This should create `p4c-msa` executable in the `build` directory 


3. How to Use
There are example programs at `extensions/csa/msa-examples` path

