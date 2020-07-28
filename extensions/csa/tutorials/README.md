# μP4 Tutorials

Welcome to μP4 tutorials! This is a step by step tutorial that teach you modular approach for dataplane programming.

Our goal is to make you Chopin of Dataplane Programming.

### Exercise 1: Composing μP4 Module
TODO: 
We provide all the code around main Router and  ipv4 μP4 module.
We ask programmers to perform three steps
1. Compile current code and see packets are dropped.
2. add one line `ipv4.apply(...)`. Here, we explain how to declare module signatures in a common file or in the main file.
   Explanation of runtime parameters and in/out args.
3. We ask them to add `-l` parameter to link module. 
4. runt the program and see packets are forwarded.

### Exercise 2: Writing new μP4 Modules
1. We ask programmers to develop write ipv6 module that returns  nexthop.
2. at this point explain parser, deparser and control block at high level.
3. Introduce them to `-o` flag of `p4c-msa` and compile ipv6 module.

### Exercise 3: Composing Dataplane program using your μP4 Modules
plug ipv6 in router's main.
pass both ipv4 and ipv6 packets.
bravo! They have developed a modular router and completed Chopin 1O1 tutorial.

We need to rearrange text from the below description to above 3 exercises.



## Introduction 

To help you better understand the language we will refer to the examples found at [extensions/csa/msa-examples](https://github.com/cornell-netlab/MicroP4/tree/master/extensions/csa/msa-examples).


  1. μP4 modules [extensions/csa/msa-examples/lib-src](https://github.com/cornell-netlab/MicroP4/tree/master/extensions/csa/msa-examples/lib-src).
     a. How to create μP4 modules 
     b. How to transfer data between modules 

  2. μP4 programs 
     a. Simple IPv4/IPv6 router 
     b. Router with source routing
     c. Router with segment routing 
     d. Firewall 
     e. Tunneling 

  3. Compiling μP4 programs to a given target architecture 
     a. Compiling to v1model 
     b. Compiling to TNA 
     
     


### Defining the Modules Structure 

To create a μP4 module we need first to create a .upv4 file (e.g.  [extensions/csa/msa-examples/lib-src/common.upv4](https://github.com/cornell-netlab/MicroP4/tree/master/extensions/csa/msa-examples/lib-src/comomn.upv4)) that will hold all μP4 modules structures that are used to transfer data between different modules and μP4 module global syntax format. 

For example to create IPv4 module that takes a packet as input and returns the next hop address we need to add the cpackage IPv4 module interface description to "common.upv4" and the input and output metadata description.

```
struct empty_t { }
cpackage IPv4(pkt p, im_t im, in empty_t ia, out bit<16> nh, inout empty_t ioa);
```

Using the above code snippet we 

  1. create an empty structure that can be used by any defined μP4 module
  2. defined an IPv4 module that takes a packet (pkt), μP4 structure (im_t), the defined empty structure as input ( in empty_t) outputs a 16 bit nexthop address (out bit<16>) and modifies an empty structure (inout empty_t) 

To define an IPv4 and IPv6 ACL modules that takes as input the source and destination address and modifies the packet processing decision ( to drop the packet or not) we need to add a structure that will hold the input data and another that will modify the data processing decision and the IPv4ACL and IPv6ACL modules syntax definition. 

```
struct ipv4_acl_in_t {
  bit<32> sa;
  bit<32> da;
} 
struct ipv6_acl_in_t {
  bit<128> sa;
  bit<128> da;
}
struct acl_result_t {
  bit<1> hard_drop;
  bit<1> soft_drop;
}
package IPv4ACL(pkt p, im_t im, in ipv4_acl_in_t ia, out empty_t oa, inout acl_result_t ioa);

cpackage IPv6ACL(pkt p, im_t im, in ipv6_acl_in_t ia, out empty_t oa, inout acl_result_t ioa);
```


### Creating the Module

Each μP4 module is defined in an independent "*.upv4" file. The "*.upv4" file contains 4 sections. 
   1. The included libraries 
     a. All μP4 modules should include μP4 architecture definition file "msa.up4" 
     b. μP4 modules should include the μP4 functions and global metadata definition file "common.up4"
   2. Headers to be extracted 
   3. Structure to be used to hold 
     a. Headers 
     b. Inner metadata 
   4. The module cpackage details

For example to create a μP4 module structure that parses the IPv4 header and outputs the nexthop address we create the following module structure that includes the required dependency files, defines the separate headers to be extracted and the header list to be used in this module (ipv4_hdr_t) [see extensions/csa/msa-examples/lib-src/ipv4.upv4](https://github.com/cornell-netlab/MicroP4/tree/master/extensions/csa/msa-examples/lib-src/ipv4.upv4). 
```
#include"msa.up4"
#include"common.up4"

header ipv4_h {
  // bit<4> version;
  // bit<4> ihl;
  bit<8> ihl_version;
  bit<8> diffserv;
  bit<16> totalLen;
  bit<16> identification;
  bit<3> flags;
  bit<13> fragOffset;
  bit<8> ttl;
  bit<8> protocol;
  bit<16> hdrChecksum;
  bit<32> srcAddr;
  bit<32> dstAddr; 
}

struct ipv4_hdr_t {
  ipv4_h ipv4;
}

cpackage IPv4 : implements Unicast<ipv4_hdr_t, empty_t, empty_t, bit<16>, empty_t> { 

  ...

}
```

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

#### Micro_Control

#### Micro_Deparser 




## μP4 Programs
