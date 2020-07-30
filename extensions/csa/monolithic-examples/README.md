# Monolithic Examples 
This directory contains the set of monolithic examples and instructions to reproduce results discussed in the paper "Composing Dataplane Programs with μP4" - SIGCOMM '20.

## How to Compile Examples
### 0. Prerequisites
Barefoot SDE 9.0.0. is required. 
```bash
export SDE=<The path to the SDE>
export SDE_INSTALL=<The path to the installation directory of the SDE>
```

### 1. Makefile
There are two targets in the Makefile
1. P1_P6 - This will compile `P1` to `P6` and store required information in the `build`
   directory.
```bash
make P1_P6
```
2. P7 - It will try to compile the P7 program mentioned in the below table
   with Barefoot SDE. The compilation will not terminate. You are recommended to
   interrupt it at your convenient time. 
```bash
make P7
// After sometime
ctrl+c
```

#### Program and Makefile Target mappings

| Program in paper | Monolithic Example | Functions                 | 
|------------------|-----------------------------|---------------------------|
| P1 | routerv6_main.p4           | Eth + IPv6                |
| P2 | routerv46lrx_main.p4       | Eth + IPv4 + IPv6 + MPLS  |
| P3 | router_ipv4v6srv6_main.p4  | Eth + IPv4 + IPv6 + SRv6  |
| P4 | routerv46_main.p4          | Eth + IPv4 + IPv6         |
| P5 | routerv4_main.p4           | Eth + IPv4                |
| P6 | router_ipv4v6_nat_acl.p4   | Eth + IPv4 + IPv6 + NAT + NPT6 + ACL |
| P7 | router_ipv4srv4ipv6_main.p4 | Eth + IPv4 + IPv6 + SRv4 |
