
# PROGRAMS = ROUTINGV4 ROUTINGV6 ROUTINGV46 ROUTINGV46LRX ROUTINGV46SRV4 ROUTINGV46SRV6 ROUTINGV46NATACL 
PROGRAMS = ROUTINGV4  ROUTINGV6 ROUTINGV46
comma:=,
empty:=
space:= $(empty) $(empty)
MSA=../../../build/p4c-msa
P4C_BMV2=../../p4c/build/p4c
COMPILE_SUBMODULE= -o
TARGET=  v1model
TARGET_ARG= --target-arch 
TARGET_P4_ARG:= --target-arch-p4 
TARGET_P4:=none
LIB_SRC_DIR := ./lib-src/

INCLUDE_FLAGS= -I ./p4include/ 
ifeq "$(origin INCLUDE_PATH)" "command line"
INCLUDE_FLAGS+= -I $(INCLUDE_PATH) 
endif
COMPILE_MAIN_FLAGS:= $(TARGET_ARG) $(TARGET)

ifeq "$(origin TARGET_P4)" "command line"
COMPILE_MAIN_FLAGS += $(TARGET_P4_ARG) $(TARGET_P4)
endif
COMPILE_MAIN_FLAGS += $(INCLUDE_FLAGS) -l

ROUTINGV4_DEPS=$(addprefix $(LIB_SRC_DIR), ipv4.up4)
ROUTINGV6_DEPS=$(addprefix $(LIB_SRC_DIR), ipv6.up4)
ROUTINGV46_DEPS=$(addprefix $(LIB_SRC_DIR),   ipv4.up4 ipv6.up4)
ROUTINGV46LRX_DEPS=$(addprefix $(LIB_SRC_DIR), ipv4.up4 ipv6.up4 mpls-lr-x.up4)
ROUTINGV46SRV4_DEPS=$(addprefix $(LIB_SRC_DIR), srv4.up4 ip-sr-v4.up4 ipv6.up4)
ROUTINGV46SRV6_DEPS=$(addprefix $(LIB_SRC_DIR), ipv4.up4 ipv6.up4 srv6-simple.up4)
ROUTINGV46NATACL_DEPS=$(addprefix $(LIB_SRC_DIR), ipv4.up4 ipv6.up4 ipv4-acl.up4 \
	                        ipv4-nat-acl.up4 ipv6-acl.up4 ipv6-nat-acl.up4 l3.up4)
ROUTINGV46LSRX_DEPS=$(addprefix $(LIB_SRC_DIR),ipv4.up4 ipv6.up4  mpls-lsr-x.up4)

ROUTINGV4_MAIN=main-programs/routerv4_main.up4
ROUTINGV6_MAIN=main-programs/routerv6_main.up4
ROUTINGV46_MAIN=main-programs/routerv46_main.up4
ROUTINGV46LRX_MAIN=main-programs/routerv46lrx_main.up4
ROUTINGV46SRV4_MAIN=main-programs/router_ipv4srv4ipv6_main.up4
ROUTINGV46SRV6_MAIN=main-programs/router_ipv4v6srv6_main.up4
ROUTINGV46NATACL_MAIN=main-programs/router_ipv4v6_nat_acl.up4

.PHONY: all clean
all: $(PROGRAMS)

%.json: %.up4
	$(MSA) $(COMPILE_SUBMODULE) $@ $<

define p4c_msa_compile =

$(eval $(1)_OBJS=$($(1)_DEPS:.up4=.json))
$(1)_UP4=$(notdir $($(1)_MAIN))
$(1)_TARGET_P4=$$($(1)_UP4:%.up4=%_$(strip $(2)).p4)
$(eval $(1)_OBJS_LIST = $(subst $(space),$(comma),$($(1)_OBJS)))

ALL_OBJS+=$($(1)_OBJS)

$(1)_BASENAME=$$(basename $$($(1)_TARGET_P4))
$(1)_BUILD=build/$$($(1)_BASENAME)/$$($(1)_TARGET_P4)
$(1)_BUILD_DIR=build/$$($(1)_BASENAME)

$$($(1)_BUILD) : $$($(1)_OBJS) $$($(1)_MAIN)
	mkdir -p $$($(1)_BUILD_DIR)
	$(MSA) $(COMPILE_MAIN_FLAGS) $$($(1)_OBJS_LIST)  $$($(1)_MAIN)
	mv $$($(1)_TARGET_P4) $$($(1)_BUILD_DIR)/

$(1) : $$($(1)_BUILD)

endef
$(foreach prog,$(PROGRAMS),$(eval $(call p4c_msa_compile,$(prog),$(TARGET))))

define p4c_bmv2_compile =

$(1)_BMV2_BUILD=$$(addprefix $$($(1)_BUILD_DIR), $$($(1)_BASENAME).json)
$$($(1)_BMV2_BUILD) : $$($(1)_BUILD)
	cd $$($(1)_BUILD_DIR) &&  \
		$(P4C_BMV2) --target bmv2 --arch v1model \
		--p4runtime-file  $$($(1)_BASENAME).p4rt \
		--p4runtime-format json --std p4-16 $$($(1)_TARGET_P4) \
		&& cd -

$(1) : $$($(1)_BMV2_BUILD)

endef

ifeq "$(strip $(TARGET))" "v1model"
$(foreach prog,$(PROGRAMS),$(eval $(call p4c_bmv2_compile,$(prog))))
endif

define p4c_tna_compile =
$(1)_TNA_MAKEFILE=$$($(1)_BUILD_DIR)/Makefile 
$(1)_TNA_BIN=$$($(1)_BUILD_DIR)/tofino/$$($(1)_BASENAME)/pipe/tofino.bin
$(1)_TNA_CONTEXT_JSON=$$($(1)_BUILD_DIR)/tofino/$$($(1)_BASENAME)/pipe/context.json

$(1)_TNA_SDE_PTF_DIR=$$(SDE)/pkgsrc/p4-examples/p4_16_programs/
$(1)_TNA_SDE_PTF=$$($(1)_TNA_SDE_PTF_DIR)/$$($(1)_BASENAME)/test.py
$(1)_TNA_REPO_PTF_DIR=./tofino-ptf/$$($(1)_BASENAME)

$$($(1)_TNA_MAKEFILE) :  | $$($(1)_BUILD)
	cd $$($(1)_BUILD_DIR) && \
		$$(SDE)/pkgsrc/p4-build/configure --with-tofino --with-p4c=p4c \
		--prefix=$$(SDE_INSTALL) --bindir=$$(SDE_INSTALL)/bin P4_NAME=$$($(1)_BASENAME) \
		P4_PATH=$$(PWD)/$$($(1)_BUILD) P4_VERSION=p4-16 P4_ARCHITECTURE=tna \
		LDFLAGS="-L$$(SDE_INSTALL)/lib" && \
		cd -

$$($(1)_TNA_CONTEXT_JSON) $$($(1)_TNA_BIN) $&:  $$($(1)_BUILD) | $$($(1)_TNA_MAKEFILE)
	cd $$($(1)_BUILD_DIR) && make && make install && cd -

$$($(1)_TNA_SDE_PTF) : | $$($(1)_TNA_REPO_PTF)
	cp -r $$($(1)_TNA_REPO_PTF_DIR) $$($(1)_TNA_SDE_PTF_DIR)

$(1) : $$($(1)_TNA_SDE_PTF) 

$(1) :  $$($(1)_TNA_CONTEXT_JSON) $$($(1)_TNA_BIN) 

endef

ifeq "$(strip $(TARGET))" "tna"
$(foreach prog,$(PROGRAMS),$(eval $(call p4c_tna_compile,$(prog))))
endif


clean:
	rm -rf ./build $(ALL_OBJS)
