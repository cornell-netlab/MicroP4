default_target: all


MSA=../../../build/p4c-msa
COMPILE_SUBMODULE= -o
COMPILE_MAIN= -I ./p4include/ -l # used for tofino compilation
#COMPILE_MAIN= --arch=v1model -l  used for v1model compilation
#EXAMPLES_FOLDER= extensions/csa/msa-v2-example

comma:=,
empty:=
space:= $(empty) $(empty)

MICRO_P4_MODULES := ipv4.p4 ipv6.p4
MICRO_P4_MODULES += mpls-lsr.p4 mpls-lsr-x.p4 mpls-lr-x.p4 
MICRO_P4_MODULES += srv4.p4  ip-sr-v4.p4 
MICRO_P4_MODULES += ipv4-acl.p4 ipv4-nat-acl.p4
MICRO_P4_MODULES += ipv6-acl.p4 ipv6-nat-acl.p4
MICRO_P4_MODULES += l3.p4

ROUTINGV46_DEPS := ipv4.json ipv6.json
ROUTINGV46LSRX_DEPS := $(ROUTINGV46_DEPS) mpls-lsr-x.json
ROUTINGV46LRX_DEPS := $(ROUTINGV46_DEPS) MPLS-lr-x.json
ROUTINGV46NATACL_DEPS := $(ROUTINGV46_DEPS)
ROUTINGV46NATACL_DEPS +=ipv4-acl.json ipv4-nat-acl.json
ROUTINGV46NATACL_DEPS +=ipv6-acl.json ipv6-nat-acl.json
ROUTINGV46NATACL_DEPS +=l3.json
ROUTINGV46NATACL_DEPS_FILES := $(subst $(space),$(comma),$(ROUTINGV46NATACL_DEPS_FILES))

MICRO_P4_JSONS = $(MICRO_P4_MODULES:.p4=.json) 
JSONS : $(MICRO_P4_JSONS)

.PHONY : default_target JSONS

$(MICRO_P4_JSONS): %.json: %.p4
	$(MSA) $(COMPILE_SUBMODULE) $@ $<


############## main programs ##############

routingv4: ipv4.json
	$(MSA) $(COMPILE_MAIN) ipv4.json routerv4-main.p4

routingv6: ipv6.json
	$(MSA) $(COMPILE_MAIN) ipv6.json routerv6-main.p4

routingv46: $(ROUTINGV46_DEPS)
	$(MSA) $(COMPILE_MAIN) ipv4.json,ipv6.json routerv46-main.p4

routingv46lrx: $(ROUTINGV46LRX_DEPS)
	$(MSA) $(COMPILE_MAIN) ipv4.json,ipv6.json,mpls-lr-x.json routerv46lrx-main.p4

routingl3srv4ipv6: srv4.json ip-sr-v4.json ipv6.json
	$(MSA) $(COMPILE_MAIN) srv4.json,ip-sr-v4.json,ipv6.json router-ipsrv4ipv6-main.p4

routingv46natacl: $(ROUTINGV46NATACL_DEPS)
	$(MSA) $(COMPILE_MAIN) $(ROUTINGV46NATACL_DEPS_FILES) router-ipv4v6-nat-acl.p4

#all:
	#routingv4 routingv6 routingv46 routingv46lsrx routingv46lrx routingl3srv4ipv6 routingv46natacl

clean: 
	rm -f *json  *tofino.p4


# TODO:  
# 1) use split  variables to adjust dependency in compiling main
# 2) string manipulation, such that file name should be given only once.
# x-main-tofino.p4 string should be automatically constructed. then following
# 3) file modification after compilation
# sed '5,7 d' x-tofino.p4
# cat tofino-multi-arch-include.txt x-main-tofino.p4 > temp ; 
# mv temp x-main-tofino.p4 ; 
# rm temp 
