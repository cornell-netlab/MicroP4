# μP4 Tutorials

Welcome to μP4 tutorials! This is a step by step tutorial that teach you the art of composing network dataplane programs.
Our goal is to make you [Chopin](https://en.wikipedia.org/wiki/Fr%C3%A9d%C3%A9ric_Chopin) of Dataplane Programming.

### Scenario
TODO: explain modular router with diagrams.

### Exercise 1: Composing μP4 Module
In this exercise, you will learn how to compose μP4 Modules. 
You are given all the required code for two μP4 Modules. However, they are not composed together. 
Concretely, μP4 module
1. Router - is going to be considered as the main module
2. ipv4 - is an independent one that processes IPv4 headers. 
As a part of this exercise, you need to complete the implementaion of [./exercise-1/Router.up4](https://github.com/cornell-netlab/MicroP4/blob/master/extensions/csa/tutorials/exercise-1/Router.up4).

#### Step 1: Compile & Run
##### Compile with μP4
```bash
cd ${UP4ROOT}/extensions/csa/tutorials/exercise-1;
${UP4ROOT}/build/p4c-msa  --target-arch v1model -I ${UP4ROOT}/p4include Router.up4
```
This will generate `Router_v1model.p4` that is required to compile with p4c.
##### Compile with P4

##### Run
BMv2 scripts

Given [./exercise-1/Router.up4](https://github.com/cornell-netlab/MicroP4/blob/master/extensions/csa/tutorials/exercise-1/Router.up4) doe not route packets.
You need to compose it with a μP4 module implementing a routing protocol. 
We have given implementation of IPv4 in [./exercise-1/ipv4.up4](https://github.com/cornell-netlab/MicroP4/blob/master/extensions/csa/tutorials/exercise-1/ipv4.up4). 

#### Step 2: Compose
To compose μP4 modules, their interfaces should be used. Interfaces provide 
information of μP4 modules' runtime behaviour without exposing their implementation detail.
Every μP4 module can either take 
1. one packet as input and retuen one packet - Unicast
2. one packet as input and return multiple packets - Multicast
3. multiple packets as inout and return multiple packets - Orchestration
In this example, it is required to identify interface implemented by the IPv4 module 
in [ipv4.up4](https://github.com/cornell-netlab/MicroP4/blob/master/extensions/csa/tutorials/exercise-1/ipv4.up4).
`cpackage IPv4 : implements Unicast<ipv4_hdr_t, empty_t, empty_t, bit<16>, empty_t>` specifies that 
the module implements `Unicast` interface by specializing its generic runtime parameters `H, M, I, O, IO`.
```
                               //|---------------------- runtime parametes  -------------------------|                     
cpackage Unicast<H, M, I, O, IO>(pkt p, im_t im, in I in_param, out O out_param, inout IO inout_param) {
  ...
} 
```
H = ipv4_hdr_t, M, I, IO = empty_t, O = bit<16>.
The type of runtime parameters of Ipv4 module are `(pkt, im_t, empty_t, bit<16>, empty_t)`.
##### Declare
Every μP4 module needs to be declared within the same scope it is used.
To use `IPv4` without its definition, it can be declared as a user-defined type using `cpackage` keyword and
 its runtime parameters, as shown below.
```
cpackage IPv4(pkt p, im_t im, in empty_t ia, out bit<16> nh, inout empty_t ioa);
```
##### Instantiate
μP4 modules declaration provide sufficient information to use them or instantiate them using.
```P4
IPv4() ipv4_i; // () is constructor params, must be empty for current version of μP4 Framework.
```
##### Invoke
Every μP4 module instance can be invoked by using its built-in method `apply`.
The `apply` method takes arguments for runtime parameters of the module.
```P4
ipv4_i.apply(...); // args for pkt p, im_t im, in empty_t ia, out bit<16> nh, inout empty_t ioa
```

#### Step 3: Re-compile & Run
```bash
cd ${UP4ROOT}/extensions/csa/tutorials/exercise-1
// compiles module as a library
${UP4ROOT}/build/p4c-msa -I ${UP4ROOT}/build/p4include -o ipv4.json ipv4.up4 
${UP4ROOT}/build/p4c-msa --target-arch v1model -I ${UP4ROOT}/build/p4include -l ipv4.json Router.up4
```
##### Run

### Exercise 2: Writing new μP4 Modules
In this exercise, you will learn to write your own μP4 Module. You need to implement a routing protocol like IPv4.
The module should have `bit<16> nh` as a part of its `out` arguments. 
#### Step 1: Write a μP4 Module to process IPv6 header
The boilerplate code to develop the module is given at [./exercise-2/ipv6.up4](https://github.com/cornell-netlab/MicroP4/tree/master/extensions/csa/tutorials/exercise-2).
IPv6 should implement `Unicast` interface by providing implementation for `micro_parser`, `micro_control` and `micro_deparser`.
To implement these constructs, you can use sub-lanuages of [P4](https://p4.org/p4-spec/docs/P4-16-v1.2.1.html) described in 
[12](https://p4.org/p4-spec/docs/P4-16-v1.2.1.html#sec-packet-parsing) & [13](https://p4.org/p4-spec/docs/P4-16-v1.2.1.html#sec-control).
Compared to P4, μP4 provides `extractor` and `emitter` for packet parsing and reassembly. You can look at [./exercise-1/ipv4.up4](https://github.com/cornell-netlab/MicroP4/blob/master/extensions/csa/tutorials/exercise-1/ipv4.up4) for their example usage.
To know more about `extractor` and `emitter` of μP4 Architecture, 
you can look at [msa.up4](https://github.com/cornell-netlab/MicroP4/blob/master/extensions/csa/p4include/msa.up4)

#### Step 2: Compile IPv6 μP4 Module
```bash
cd ${UP4ROOT}/extensions/csa/tutorials/exercise-2
// compiles IPv6 module as a library
${UP4ROOT}/build/p4c-msa -I ${UP4ROOT}/build/p4include -o ipv6.json ipv6.up4 
```

### Exercise 3: Composing Dataplane program using your μP4 Modules
#### Step 1: Modify `Router.up4`
#### Step 2: Compile `Router.up4`
#### Step 3: Pass IPv4 and IPv6 pings

bravo! They have developed a modular router and completed Chopin 1O1 tutorial.

We need to rearrange text from the below description to above 3 exercises.


### Creating the Module

Each μP4 module is defined in an independent "*.up4" file. The "*.up4" file contains 4 sections. 
   1. The included libraries 
     a. All μP4 modules should include μP4 architecture definition file "msa.up4" 
     b. μP4 modules should include the μP4 functions and global metadata definition file "common.up4"
   2. Headers to be extracted 
   3. Structure to be used to hold 
     a. Headers 
     b. Inner metadata 
   4. The module cpackage details

The module's cpackage can implement either the Unicast, Multicast or Orchestration interface. To use the Unicast interface we need to define the packet header structure to be used in this module, the msa.up4 metadata to be used and the input,output and in/out structures used by the module to communicate with other modules.

The package contains 3 main parts the micro_parser, micro_control and micro_deparser. 

#### Micro_Parser 

The parser extracts the module defined headers from the received packet, micro_parser takes as input the μP4 extrator, packet and internal metadata structures, the extracted output header structure, the metadata to be modified, the input and output data. 

To extract the modules headers we use ```ex.extract(packet, header)``` μP4 function. To process the headers, match fields and transition between states we use P4 programming language syntax. 

For example to extract the ipv4 header in ipv4.up4 module we add the following to the cpackage details: 
``` 
  parser micro_parser(extractor ex, pkt p, im_t im, out ipv4_hdr_t hdr, 
                      inout empty_t meta, in empty_t ia, inout empty_t ioa) {
    state start {
      ex.extract(p, hdr.ipv4);
      transition accept;
    }
  }
```
