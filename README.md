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
μP4C is developed by extending a fork repo `https://github.com/hksoni/p4c.git` of 
P4-16 prototype compiler `https://github.com/p4lang/p4c.git`

### 1. Install Dependencies
Follow the instructions listed at `https://github.com/hksoni/p4c#dependencies`.

### 2. Install μP4C
```bash
git clone --recursive https://github.com/hksoni/microp4.git microp4
cd microp4
mkdir build
cmake ..  or cmake .. -DCMAKE_BUILD_TYPE=DEBUG 
make -j4   // This should create p4c-msa executable in build directory 
```

### 3. How to Write μP4 Programs
Every μP4 Program must implemet at least one of the interfaces defined in μPA. 
μPA provides 3 interfaces, Unicast, Multicast and Orchestration. By implementing 
a μPA interface, a user-defined package type can be created. 

#### A quick Intro to μP4 Program  skeleton
```
// MyProg is user-defined package type.
// cpackage is a keyword to indicate MyProg is a composable package 
// with in-built `apply` method.
// h_t, M_t, i_t, o_t, io_t are user-defined concrete types 
// supplied to specialized H, M, I, O, and IO generic types in Unicast interface
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
   1. `lib-src/ipv4.p4` a very simple IPv4 cpackage
   2. `main-programs/routerv4-main.p4` a Main cpackage that uses IPv4 cpackage


### 4. How to Use μP4C
   1. Creating Libraries
   ```
   ./build/p4c-msa -o <<lib-name.json>> <<μp4 source file>>
   ./build/p4c-msa -o ipv4.json ./extensions/csa/msa-examples/lib-src/ipv4.p4  
   // ipv4.p4 contains μp4 program
   ```

   2. Generating Target Source
   ```
   ./build/p4c-msa --target-arch  <<target>> -I <<path to target's .p4>>  \
                   -l <<lib-name.json>> <<main μp4 source file>>
   // An example
   ./build/p4c-msa --target-arch  v1model -I ./build/p4include/ -l ipv4.json \
                   ./extensions/csa/msa-examples/main-programs/routerv4-main.p4
   // This will generate routerv4-main-v1model.p4
   ```

