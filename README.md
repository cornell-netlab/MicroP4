# μP4 

## Overview
μP4 enables programming data plane in a portable, modular and composable manner. 
It comprises 
1. μP4 Architecture (μPA) - a logical Architecture for data plane
2. μP4 Compiler (μP4C) - to compile data plane programs written against μPA 
3. μP4 Language - A subtle variant of [P4-16](https://p4.org/p4-spec/docs/P4-16-v1.2.1.html)

μP4 allows to build libraries of packet-processing functions in data plane, reuse 
them to develop new programs and compile the programs to architectures of real 
target devices. μP4 maps its logical architecture to real targets like v1model and Tofino.

Using μP4C, programmers can 
1. Compile code to libraries (in form of `.json` files)
2. Generate P4-16 source (`.p4`) specific to a given target architecture (v1model
   or tna)

μP4C-generated `.p4` should be used with target-specific P4-16 compiler backends
to generate executables.


## Getting started
μP4C is developed by extending a forked repo `https://github.com/hksoni/p4c.git` of 
P4-16 prototype compiler `https://github.com/p4lang/p4c.git`. The forked p4c repo is
added as submodule at [extensions/csa/msa-examples](https://github.com/cornell-netlab/MicroP4/tree/master/extensions/csa/msa-examples).
Also, a version of BMv2 compatible to the forked p4c repo is added as submodule at [extensions/csa/msa-examples](https://github.com/hksoni/behavioral-model/tree/ed0174d54fc12f28b3b7371a7613d6303143daea).

### 1. Install dependencies and download μP4
#### Dependencies
The dependencies for μP4 as the same as those required for P4. We list the steps here for Ubuntu 16.04:
```bash
sudo apt-get install cmake g++ git automake libtool libgc-dev bison flex libfl-dev libgmp-dev libboost-dev libboost-iostreams-dev libboost-graph-dev llvm pkg-config python python-scapy python-ipaddr python-ply tcpdump
```

Install `protobuf` version 3.2.0 as follows:
```bash
sudo apt-get install autoconf automake libtool curl make g++ unzip
wget https://github.com/protocolbuffers/protobuf/releases/download/v3.2.0/protobuf-cpp-3.2.0.zip
unzip protobuf-cpp-3.2.0.zip
cd protobuf-3.2.0
./configure
 make
 make check
 sudo make install
 sudo ldconfig
```
If you encounter any error, see more details at https://github.com/hksoni/p4c#dependencies.

#### Download

```
git clone --recursive https://github.com/cornell-netlab/MicroP4.git microp4 
```
OR
```
git clone --recurse-submodules https://github.com/cornell-netlab/MicroP4.git microp4
```
if you forgot `--recursive` or `--recurse-submodules`
```
git submodule update --init --recursive
```

### 2. Install 
The previous commands download the source code of μP4 along with `p4c` and `BMv2` as submodules.
To generate v1model-specific P4 source for μP4 programs, installing only μP4C is enough. 
#### Install μP4C
```bash
cd microp4
mkdir build
cd build
cmake ..  or cmake .. -DCMAKE_BUILD_TYPE=DEBUG 
make -j4   # This should create p4c-msa executable in the build directory 
cd ..
```

To create executables for BMv2 from v1model-specific P4 source, install p4c.
#### Install p4c and BMv2
```bash
cd ./extensions/csa/msa-examples/p4c
mkdir build
cd build
cmake ..  or cmake .. -DCMAKE_BUILD_TYPE=DEBUG 
make -j4 
cd  ../../  # at ./extensions/csa/msa-examples
```
To run executables generated for BMv2, install BMv2.
```bash
cd {$UP4ROOT}/extensions/csa/msa-examples/bmv2
bash ./install_deps.sh
./autogen.sh
./configure 'CXXFLAGS=-O0 -g' --enable-debugger    # Mandatory for μP4, because I will need logs in error scenarios. :)
make
[sudo] make install  # if you need to install bmv2
sudo ldconfig # for linux
```
#### Install Barefoot's SDE for Tofino 
μP4C can generate P4 source specific Barefoot's Tofino architecture(TNA). It is recommended to install Barefoot SDE 9.0.0. at [extensions/csa/msa-examples](https://github.com/cornell-netlab/MicroP4/tree/master/extensions/csa/msa-examples).


### 3. How to Write μP4 Programs
Every μP4 Program must implemet at least one of the interfaces defined as a part of 
μPA in [extensions/csa/p4include/msa.p4](https://github.com/cornell-netlab/MicroP4/blob/master/extensions/csa/p4include/msa.p4). 
μPA provides 3 interfaces, Unicast, Multicast and Orchestration. By implementing 
a μPA interface, a user-defined package type can be created. 

#### A Quick Intro to μP4 Program Skeleton
```
// In the following example, MyProg is a user-defined package type.
// cpackage is a keyword to indicate MyProg is a composable package 
// with in-built `apply` method.
// h_t, M_t, i_t, o_t, io_t are user-defined concrete types supplied to 
// specialized H, M, I, O, and IO generic types in Unicast interface

cpackage MyProg : implements Unicast<h_t, m_t, i_t, o_t, io_t> {

  // extractor, emitter, pkt, im_t are declared in μPA (msa.p4)
  
  parser micro_parser(extractor ex, pkt p, im_t im, out h_t hdr,          
                      inout m_t meta, in i_t ia, inout io_t ioa) {
    // usual P4-16 parser block code goes here
  }
  
  control micro_control(pkt p, im_t im, inout h_t hdr, inout m_t m,   
                        in i_t ia, out o_t oa, inout io_t ioa) {
    // usual P4-16 control block code goes here
  }
  
  control micro_deparser(emitter em, pkt p, in H h) {
    // Deparser code
    // a sequence of em.emit(...) calls
  }
  
  // in-built apply BlockStatement.
  apply {
    micro_parser.apply(...);
    micro_control.apply(...);
    micro_deparser.apply(...);
  }
}
```

How to instantiate cpackage types
   1. Instantiating MyProg in micro_control block
      ```
      MyProg() inst_my_prog; // () is constructor parameter for future designs.
      ```
   2. Instantiating as main at file scope.
      ```
      MyProg() main; 
      ```

How to Invoke an instance of cpackage type

   1. Invoking MyProg using 5 runtime parameters. 
      First two are instances of of concrete types declared in μPA.
      The last three are instances of user-defined types used 
      to specialize generic types I, O and IO. 
      ```
      inst_my_prog.apply(p, im, i, o, io); 
      ```

   2. main instances can not be invoked explicitly.

#### An example
There are example programs at `extensions/csa/msa-examples` path.
For more details, have a look at
   1. `lib-src/ipv4.up4` a very simple IPv4 cpackage
   2. `main-programs/routerv4_main.up4` the `main` cpackage that uses IPv4 cpackage


### 4. How to Use μP4C
   1. Creating Libraries
      ```
      ./build/p4c-msa -o <<lib-name.json>> <<μp4 source file>>
      ```
      ##### An example
      ipv4.p4 contains μp4 program
      ```
      ./build/p4c-msa -o ipv4.json ./extensions/csa/msa-examples/lib-src/ipv4.up4
      ```

   2. Generating Target Source
      ```
      ./build/p4c-msa --target-arch  <<target>> -I <<path to target's .p4>>  \
                      -l <<lib-name.json>> <<main μp4 source file>>
      ```
      ##### An example
      This will generate routerv4_main_v1model.p4
      ```
      ./build/p4c-msa --target-arch  v1model -I ./build/p4include/ -l ipv4.json \
                      ./extensions/csa/msa-examples/main-programs/routerv4_main.up4
      ```
## Running Examples
There are more examples at [./extensions/csa/msa-examples](https://github.com/cornell-netlab/MicroP4/tree/master/extensions/csa/msa-examples) along with p4c and BMv2 submodules.
`./extensions/csa/msa-examples` also contains PTF tests for Barefoot's Tofino target. 

