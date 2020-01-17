default_target: all

.PHONY : default_target

MSA=../../../build/p4c-msa
COMPILE_SUBMODULE= -o
COMPILE_MODEL= -I ./p4include/ -l # used for tofino compilation
#COMPILE_MODEL= --arch=v1model -l  used for v1model compilation
#EXAMPLES_FOLDER= extensions/csa/msa-v2-example


ipv4.json:
	$(MSA) $(COMPILE_SUBMODULE) ipv4.json ipv4.p4

ipv6.json:
	$(MSA) $(COMPILE_SUBMODULE) ipv6.json ipv6.p4

mpls-lsr.json:
	$(MSA) $(COMPILE_SUBMODULE) mpls-lsr.json mpls-lsr.p4

MPLS-LSR-X.json:
	$(MSA) $(COMPILE_SUBMODULE) mpls-lsr-x.json mpls-lsr-x.p4

MPLS-LR-X.json:
	$(MSA) $(COMPILE_SUBMODULE) mpls-lr-x.json mpls-lr-x.p4

routingv4: ipv4.json
	$(MSA) $(COMPILE_MODEL) ipv4.json routerv4-main.p4

routingv6: ipv6.json
	$(MSA) $(COMPILE_MODEL) ipv6.json routerv6-main.p4

routingv46: ipv4.json ipv6.json
	$(MSA) $(COMPILE_MODEL) ipv4.json,ipv6.json routerv46-main.p4

routingv46lsrx: ipv4.json ipv6.json MPLS-LSR-X.json 
	$(MSA) $(COMPILE_MODEL) ipv4.json,ipv6.json,mpls-lsr-x.json routerv46lsrx-main.p4

routingv46lrx: ipv4.json ipv6.json MPLS-LR-X.json 
	$(MSA) $(COMPILE_MODEL) ipv4.json,ipv6.json,mpls-lr-x.json routerv46lrx-main.p4

SRv4.json:
	$(MSA) $(COMPILE_SUBMODULE) srv4.json srv4.p4

IPSRv4.json:
	$(MSA) $(COMPILE_SUBMODULE) ip-sr-v4.json ip-sr-v4.p4

routingl3srv4ipv6: SRv4.json IPSRv4.json ipv6.json
	$(MSA) $(COMPILE_MODEL) srv4.json,ip-sr-v4.json,ipv6.json router-ipsrv4ipv6-main.p4

all: routingv4 routingv6 routingv46 routingv46lsrx routingv46lrx routingl3srv4ipv6

clean: rm -f *json
