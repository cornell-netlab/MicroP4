# Monolithic Examples 
This directory contains the set of monolithic examples discussed in "Composing Dataplane Programs with μP4" - SIGCOMM '20
Instructions to reproduce results published in the paper titled "Composing Dataplane Programs with μP4".
## How to Compile Examples
### 0. Prerequisites
Barefoot SDE 9.0.0. is required. 
```bash
export SDE=<The path to the SDE>
export SDE_INSTALL=<The path to the installation directory of the SDE>
```

### 1. Makefile
There are two targets in the Makefile
1. all - This will compile `P1` to `P6` and store required information in the `build`
   directory.
2. P7 - P7 - It will try to compile the P7 program mentioned in the below table
   with Barefoot SDE. The compilation will not terminate. You are recommended to
   press `ctrl+c` at your convenient time. You can notice massive consumption 
   of storage by `./build/router_ipv4srv4ipv6_main.tofino` directory using 
   `du -sh ./build/router_ipv4srv4ipv6_main.tofino` 

### 2. Compile
The two steps in the compilation process can be invoked together using a single command show below.
Note that this will build all the seven programs mentioned in the paper:

| Program in paper | Monolithic Example | Functions                 | 
|------------------|-----------------------------|---------------------------|
| P1 | routerv6_main.p4           | Eth + IPv6                |
| P2 | routerv46lrx_main.p4       | Eth + IPv4 + IPv6 + MPLS  |
| P3 | router_ipv4v6srv6_main.p4  | Eth + IPv4 + IPv6 + SRv6  |
| P4 | routerv46_main.p4          | Eth + IPv4 + IPv6         |
| P5 | routerv4_main.p4           | Eth + IPv4                |
| P6 | router_ipv4v6_nat_acl.p4   | Eth + IPv4 + IPv6 + NAT + NPT6 + ACL |
| P7 | router_ipv4srv4ipv6_main.p4 | Eth + IPv4 + IPv6 + SRv4 |
