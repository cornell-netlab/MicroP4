default_target: all

.PHONY : default_target

MSA=../../../build/p4c-msa
COMPILE_SUBMODULE= -o
COMPILE_MODEL= -I ./p4include/ -l # used for tofino compilation
#COMPILE_MODEL= --arch=v1model -l  used for v1model compilation
#EXAMPLES_FOLDER= extensions/csa/msa-v2-example

Filter_L4.json:
	$(MSA) $(COMPILE_SUBMODULE) filter_l4.json filter_l4.p4

Nat_L4.json:
	$(MSA) $(COMPILE_SUBMODULE) nat_l4.json nat_l4.p4

Nat_L3.json:
	$(MSA) $(COMPILE_SUBMODULE) nat_l3.json nat_l3.p4

Nat_L3_model:
	$(MSA) $(COMPILE_MODEL) nat_l4.json nat_l3.p4

L3v4.json:
	$(MSA) $(COMPILE_SUBMODULE) l3v4.json l3v4.p4

L3v6.json:
	$(MSA) $(COMPILE_SUBMODULE) l3v6.json l3v6.p4

ECNv4.json:
	$(MSA) $(COMPILE_SUBMODULE) ecnv4.json ecnv4.p4

ECNv6.json: 	
	$(MSA) $(COMPILE_SUBMODULE) ecnv6.json ecnv6.p4

vlan.json:
	$(MSA) $(COMPILE_SUBMODULE) vlan.json vlan.p4

mpls.json:
	$(MSA) $(COMPILE_SUBMODULE) mpls.json mpls.p4

filter: Filter_L4.json L3v4.json
	$(MSA) $(COMPILE_MODEL) filter_l4.json,l3v4.json firewall-main.p4

nat: Nat_L4.json Nat_L3.json Nat_L3_model 
	$(MSA) $(COMPILE_MODEL) nat_l3.json nat-main.p4

qosv4: L3v4.json ECNv4.json
	$(MSA) $(COMPILE_MODEL) ecnv4.json,l3v4.json qosrouterv4-main.p4

qosv6: L3v6.json ECNv6.json
	$(MSA) $(COMPILE_MODEL) ecnv6.json,l3v6.json qosrouterv6-main.p4 

routingv4: L3v4.json
	$(MSA) $(COMPILE_MODEL) l3v4.json routerv4-main.p4

routingv6: L3v6.json
	$(MSA) $(COMPILE_MODEL) l3v6.json routerv6-main.p4

routingv46: L3v4.json L3v6.json
	$(MSA) $(COMPILE_MODEL) l3v4.json,l3v6.json routerv46-main.p4

mprouting: L3v4.json L3v6.json mpls.json
	$(MSA) $(COMPILE_MODEL) l3v4.json,l3v6.json,mpls.json mprouter-main.p4

vlan: vlan.json L3v4.json L3v6.json
	$(MSA) $(COMPILE_MODEL) vlan.json,l3v4.json,l3v6.json vlan-main.p4
	
mpls: mpls.json
	$(MSA) $(COMPILE_MODEL) mpls.json mpls-main.p4

multifunction: Filter_L4.json  Nat_L4.json Nat_L3.json Nat_L3_model ECNv4.json L3v4.json
	$(MSA) $(COMPILE_MODEL) filter_l4.json,nat_l3.json,ecnv4.json,l3v4.json multi-function-main.p4

all: filter  qosv6 routingv4 routingv6 vlan mpls # qosv4 nat multifunction

clean: rm -f *json
