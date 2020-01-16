default_target: all

.PHONY : default_target

MSA=../../../build/p4c-msa
COMPILE_SUBMODULE= -o
COMPILE_MODEL= -I ./p4include/ -l # used for tofino compilation
#COMPILE_MODEL= --arch=v1model -l  used for v1model compilation
#EXAMPLES_FOLDER= extensions/csa/msa-v2-example


L3v4.json:
	$(MSA) $(COMPILE_SUBMODULE) l3v4.json l3v4.p4

L3v6.json:
	$(MSA) $(COMPILE_SUBMODULE) l3v6.json l3v6.p4

mpls-lsr.json:
	$(MSA) $(COMPILE_SUBMODULE) mpls-lsr.json mpls-lsr.p4

MPLS-LSR-X.json:
	$(MSA) $(COMPILE_SUBMODULE) mpls-lsr-x.json mpls-lsr-x.p4

MPLS-LR-X.json:
	$(MSA) $(COMPILE_SUBMODULE) mpls-lr-x.json mpls-lr-x.p4

routingv4: L3v4.json
	$(MSA) $(COMPILE_MODEL) l3v4.json routerv4-main.p4

routingv6: L3v6.json
	$(MSA) $(COMPILE_MODEL) l3v6.json routerv6-main.p4

routingv46: L3v4.json L3v6.json
	$(MSA) $(COMPILE_MODEL) l3v4.json,l3v6.json routerv46-main.p4

routingv46lsrx: L3v4.json L3v6.json MPLS-LSR-X.json 
	$(MSA) $(COMPILE_MODEL) l3v4.json,l3v6.json,mpls-lsr-x.json routerv46lsrx-main.p4

routingv46lrx: L3v4.json L3v6.json MPLS-LR-X.json 
	$(MSA) $(COMPILE_MODEL) l3v4.json,l3v6.json,mpls-lr-x.json routerv46lrx-main.p4

SRv4.json:
	$(MSA) $(COMPILE_SUBMODULE) srv4.json srv4.p4

L3SRv4.json:
	$(MSA) $(COMPILE_SUBMODULE) l3-sr-v4.json l3-sr-v4.p4

routingl3srv4l3v6: SRv4.json L3SRv4.json L3v6.json
	$(MSA) $(COMPILE_MODEL) srv4.json,l3-sr-v4.json,l3v6.json routerl3srv4l3v6-main.p4

all: routingv4 routingv6 routingv46 routingv46lsrx routingv46lrx

clean: rm -f *json
