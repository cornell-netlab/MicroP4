.PHONY : JSONS all clean
.DEFAULT_GOAL := all

MSA=../../../build/p4c-msa
COMPILE_SUBMODULE= -o
TARGET=  v1model
TARGET_ARG= --target-arch 
TARGET_P4_ARG:= --target-arch-p4 
TARGET_P4:=none
INCLUDE_FLAGS:= -I ./p4include/ 
COMPILE_MAIN_FLAGS:= $(TARGET_ARG) $(TARGET)

ifeq "$(origin TARGET_P4)" "command line"
COMPILE_MAIN_FLAGS += $(TARGET_P4_ARG) $(TARGET_P4)
endif
COMPILE_MAIN_FLAGS += $(INCLUDE_FLAGS) -l

LIB_SRC_DIR := ./lib-src/

comma:=,
empty:=
space:= $(empty) $(empty)

MICRO_PROGRAMS := ipv4.p4 ipv6.p4
MICRO_PROGRAMS += mpls-lsr.p4 mpls-lsr-x.p4 mpls-lr-x.p4 
MICRO_PROGRAMS += srv4.p4  ip-sr-v4.p4 
MICRO_PROGRAMS += ipv4-acl.p4 ipv4-nat-acl.p4
MICRO_PROGRAMS += ipv6-acl.p4 ipv6-nat-acl.p4
MICRO_PROGRAMS += srv6-simple.p4 l3.p4

MICRO_PROGRAMS_PATHS := $(addprefix $(LIB_SRC_DIR), $(MICRO_PROGRAMS))

ROUTINGV4_OBJS := ipv4.json
ROUTINGV6_OBJS := ipv6.json
ROUTINGV46_OBJS := $(ROUTINGV4_OBJS) $(ROUTINGV6_OBJS)
ROUTINGV46LRX_OBJS := $(ROUTINGV46_OBJS) mpls-lr-x.json
ROUTINGV46SRV4_OBJS :=  srv4.json ip-sr-v4.json $(ROUTINGV6_OBJS)
ROUTINGV46SRV6_OBJS := $(ROUTINGV46_OBJS) srv6-simple.json
ROUTINGV46NATACL_OBJS := $(ROUTINGV46_OBJS) 
ROUTINGV46NATACL_OBJS += ipv4-acl.json ipv4-nat-acl.json 
ROUTINGV46NATACL_OBJS += ipv6-acl.json ipv6-nat-acl.json 
ROUTINGV46NATACL_OBJS += l3.json

ROUTINGV46LSRX_OBJS := $(ROUTINGV46_OBJS) mpls-lsr-x.json

ROUTINGV4_OBJS_PATHS := $(addprefix $(LIB_SRC_DIR), $(strip $(ROUTINGV4_OBJS)))
ROUTINGV6_OBJS_PATHS := $(addprefix $(LIB_SRC_DIR), $(strip $(ROUTINGV6_OBJS)))
ROUTINGV46_OBJS_PATHS := $(addprefix $(LIB_SRC_DIR), $(strip $(ROUTINGV46_OBJS)))
ROUTINGV46LRX_OBJS_PATHS := $(addprefix $(LIB_SRC_DIR), $(strip $(ROUTINGV46LRX_OBJS)))
ROUTINGV46SRV4_OBJS_PATHS := $(addprefix $(LIB_SRC_DIR), $(strip $(ROUTINGV46SRV4_OBJS)))
ROUTINGV46SRV6_OBJS_PATHS := $(addprefix $(LIB_SRC_DIR), $(strip $(ROUTINGV46SRV6_OBJS)))
ROUTINGV46NATACL_OBJS_PATHS := $(addprefix $(LIB_SRC_DIR), $(strip $(ROUTINGV46NATACL_OBJS)))

MICRO_P4_JSONS = $(MICRO_PROGRAMS_PATHS:.p4=.json) 
JSONS : $(MICRO_P4_JSONS)

$(MICRO_P4_JSONS): %.json: %.p4
	$(MSA) $(COMPILE_SUBMODULE) $@ $<

############## main program

routingv4: $(ROUTINGV4_OBJS_PATHS)
	$(MSA) $(COMPILE_MAIN_FLAGS) $(ROUTINGV4_OBJS_PATHS) main-programs/routerv4-main.p4

routingv6: $(ROUTINGV6_OBJS_PATHS)
	$(MSA) $(COMPILE_MAIN_FLAGS) $(ROUTINGV6_OBJS_PATHS) main-programs/routerv6-main.p4

routingv46: $(ROUTINGV46_OBJS_PATHS)
	$(eval OBJS_LIST := $(subst $(space),$(comma),$(ROUTINGV46_OBJS_PATHS)))
	$(MSA) $(COMPILE_MAIN_FLAGS) $(OBJS_LIST) main-programs/routerv46-main.p4

routingv46lrx: $(ROUTINGV46LRX_OBJS_PATHS)
	$(eval OBJS_LIST := $(subst $(space),$(comma),$(ROUTINGV46LRX_OBJS_PATHS)))
	$(MSA) $(COMPILE_MAIN_FLAGS) $(OBJS_LIST) main-programs/routerv46lrx-main.p4

routingv46srv4: $(ROUTINGV46SRV4_OBJS_PATHS)
	$(eval OBJS_LIST := $(subst $(space),$(comma),$(ROUTINGV46SRV4_OBJS_PATHS)))
	$(MSA) $(COMPILE_MAIN_FLAGS) $(OBJS_LIST) main-programs/router-ipv4srv4ipv6-main.p4

routingv46srv6: $(ROUTINGV46SRV6_OBJS_PATHS)
	$(eval OBJS_LIST := $(subst $(space),$(comma),$(ROUTINGV46SRV6_OBJS_PATHS)))
	$(MSA) $(COMPILE_MAIN_FLAGS) $(OBJS_LIST) main-programs/router-ipv4v6srv6-main.p4

routingv46natacl: $(ROUTINGV46NATACL_OBJS_PATHS)
	$(eval OBJS_LIST := $(subst $(space),$(comma),$(ROUTINGV46NATACL_OBJS_PATHS)))
	$(MSA) $(COMPILE_MAIN_FLAGS) $(OBJS_LIST) main-programs/router-ipv4v6-nat-acl.p4

all: routingv4 routingv6 routingv46 routingv46lrx routingv46srv4 routingv46srv6 routingv46natacl

clean: 
	rm -f $(LIB_SRC_DIR)*json  *-tofino.p4 *-v1model.p4 *-tna.p4


# TODO:
# x-main-tofino.p4 string should be automatically constructed. then following
# 3) file modification after compilation
# sed '5,7 d' x-tofino.p4
# cat tofino-multi-arch-include.txt x-main-tofino.p4 > temp ; 
# mv temp x-main-tofino.p4 ; 
# rm temp 
