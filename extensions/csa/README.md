# Midend and Backend for μP4 Architecture.

μP4 is implemented as an extension of P4-16 


This back-end generates IR(.json) pertaining to Micro Switch Architecture
(CSA) model. It accepts a source p4 file(.p4) and its dependencies (.json files)
for the packages referred in the source file.

It accepts only P4_16 programs written for the `msa.p4` (<root>/extensions/csa/p4include) model.

# Usage
An example compilation from build directory.
Compiling Module P4 program
```bash
./p4c-msa  -o ../extensions/csa/msa-v2-example/l3v4.json ../extensions/csa/msa-v2-example/l3v4.p4
```
Compiling P4 programs with the Main package
```bash
./p4c-msa -I ./p4include/  -l ../extensions/csa/msa-v2-example/l3v4.json ../extensions/csa/msa-v2-example/modular-routerv4-simple.p4  
```

# Dependencies
 - yet to be deternined

# Unsupported P4_16 language features

- parser value set
