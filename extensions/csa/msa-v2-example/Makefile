default_target: all

.PHONY : default_target

MSA=../../../build/p4c-msa
COMPILE_SUBMODULE= -o
COMPILE_MAIN= -I ./p4include/ -l # used for tofino compilation
#COMPILE_MAIN= --arch=v1model -l  used for v1model compilation
#EXAMPLES_FOLDER= extensions/csa/msa-v2-example


IPv4.json:
	$(MSA) $(COMPILE_SUBMODULE) ipv4.json ipv4.p4

IPv6.json:
	$(MSA) $(COMPILE_SUBMODULE) ipv6.json ipv6.p4

MPLS-LSR.json:
	$(MSA) $(COMPILE_SUBMODULE) mpls-lsr.json mpls-lsr.p4

MPLS-LSR-X.json:
	$(MSA) $(COMPILE_SUBMODULE) mpls-lsr-x.json mpls-lsr-x.p4

MPLS-LR-X.json:
	$(MSA) $(COMPILE_SUBMODULE) mpls-lr-x.json mpls-lr-x.p4

routingv4: IPv4.json
	$(MSA) $(COMPILE_MAIN) ipv4.json routerv4-main.p4

routingv6: IPv6.json
	$(MSA) $(COMPILE_MAIN) ipv6.json routerv6-main.p4

routingv46: IPv4.json IPv6.json
	$(MSA) $(COMPILE_MAIN) ipv4.json,ipv6.json routerv46-main.p4

routingv46lsrx: IPv4.json IPv6.json MPLS-LSR-X.json 
	$(MSA) $(COMPILE_MAIN) ipv4.json,ipv6.json,mpls-lsr-x.json routerv46lsrx-main.p4

routingv46lrx: IPv4.json IPv6.json MPLS-LR-X.json 
	$(MSA) $(COMPILE_MAIN) ipv4.json,ipv6.json,mpls-lr-x.json routerv46lrx-main.p4

SRv4.json:
	$(MSA) $(COMPILE_SUBMODULE) srv4.json srv4.p4

IPSRv4.json:
	$(MSA) $(COMPILE_SUBMODULE) ip-sr-v4.json ip-sr-v4.p4

routingl3srv4ipv6: SRv4.json IPSRv4.json IPv6.json
	$(MSA) $(COMPILE_MAIN) srv4.json,ip-sr-v4.json,ipv6.json router-ipsrv4ipv6-main.p4

IPv4-ACL.json:
	$(MSA) $(COMPILE_SUBMODULE) ipv4-acl.json ipv4-acl.p4

IPv4-NAT-ACL.json:
	$(MSA) $(COMPILE_SUBMODULE) ipv4-nat-acl.json ipv4-nat-acl.p4

L3.json:
	$(MSA) $(COMPILE_SUBMODULE) l3.json l3.p4

microp4-switch: IPv4.json IPv4-ACL.json IPv4-NAT-ACL.json L3.json
	$(MSA) $(COMPILE_MAIN) ipv4.json,ipv4-acl.json,ipv4-nat-acl.json,l3.json microp4-switch.p4

all: routingv4 routingv6 routingv46 routingv46lsrx routingv46lrx routingl3srv4ipv6

clean: rm -f *json
