default_target: all

.PHONY : default_target

MSA=build/p4c-msa
COMPILE_SUBMODULE= -o
COMPILE_MODEL= --arch=v1model -l
EXAMPLES_FOLDER= extensions/csa/msa-v2-example

Filter_L4.json:
	$(MSA) $(COMPILE_SUBMODULE) $(EXAMPLES_FOLDER)/Filter_L4.json $(EXAMPLES_FOLDER)/Filter_L4.p4

Nat_L4.json:
	$(MSA) $(COMPILE_SUBMODULE) $(EXAMPLES_FOLDER)/Nat_L4.json $(EXAMPLES_FOLDER)/Nat_L4.p4

Nat_L3.json:
	$(MSA) $(COMPILE_SUBMODULE) $(EXAMPLES_FOLDER)/Nat_L3.json $(EXAMPLES_FOLDER)/Nat_L3.p4

Nat_L3_model:
	$(MSA) $(COMPILE_MODEL) $(EXAMPLES_FOLDER)/Nat_L4.json $(EXAMPLES_FOLDER)/Nat_L3.p4

L3v4.json:
	$(MSA) $(COMPILE_SUBMODULE) $(EXAMPLES_FOLDER)/l3v4.json $(EXAMPLES_FOLDER)/l3v4.p4

L3v6.json:
	$(MSA) $(COMPILE_SUBMODULE) $(EXAMPLES_FOLDER)/l3v6.json $(EXAMPLES_FOLDER)/l3v6.p4

ECNv4.json:
	$(MSA) $(COMPILE_SUBMODULE) $(EXAMPLES_FOLDER)/ecnv4.json $(EXAMPLES_FOLDER)/ecnv4.p4

ECNv6.json: 	
	$(MSA) $(COMPILE_SUBMODULE) $(EXAMPLES_FOLDER)/ecnv6.json $(EXAMPLES_FOLDER)/ecnv6.p4

filter: Filter_L4.json L3v4.json
	$(MSA) $(COMPILE_MODEL) $(EXAMPLES_FOLDER)/Filter_L4.json,$(EXAMPLES_FOLDER)/l3v4.json $(EXAMPLES_FOLDER)/modular-firewall.p4

nat: Nat_L4.json Nat_L3.json Nat_L3_model 
	$(MSA) $(COMPILE_MODEL) $(EXAMPLES_FOLDER)/Nat_L3.json $(EXAMPLES_FOLDER)/modular-nat.p4

qosv4: L3v4.json ECNv4.json
	$(MSA) $(COMPILE_MODEL) $(EXAMPLES_FOLDER)/ecnv4.json,$(EXAMPLES_FOLDER)/l3v4.json $(EXAMPLES_FOLDER)/modular-qosrouterv4.p4

qosv6: L3v6.json ECNv6.json
	$(MSA) $(COMPILE_MODEL) $(EXAMPLES_FOLDER)/ecnv6.json,$(EXAMPLES_FOLDER)/l3v6.json $(EXAMPLES_FOLDER)/modular-qosrouterv6.p4 

routingv4: L3v4.json
	$(MSA) $(COMPILE_MODEL) $(EXAMPLES_FOLDER)/l3v4.json $(EXAMPLES_FOLDER)/modular-routerv4.p4

routingv6: L3v6.json
	$(MSA) $(COMPILE_MODEL) $(EXAMPLES_FOLDER)/l3v6.json $(EXAMPLES_FOLDER)/modular-routerv6.p4

multifunction: Filter_L4.json  Nat_L4.json Nat_L3.json Nat_L3_model ECNv4.json L3v4.json
	$(MSA) $(COMPILE_MODEL) $(EXAMPLES_FOLDER)/Filter_L4.json,$(EXAMPLES_FOLDER)/Nat_L3.json,$(EXAMPLES_FOLDER)/ecnv4.json,$(EXAMPLES_FOLDER)/l3v4.json $(EXAMPLES_FOLDER)/multi-function.p4

all: filter nat qosv4 qosv6 routingv4 routingv6 multifunction

clean: rm -f $(EXAMPLES_FOLDER)/*json
