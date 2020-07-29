.PHONY: all clean ipv46srv4 P7 P1_P6

P4C_TNA=bin/bf-p4c -b tofino -a v1model --verbose 3 -g --create-graphs 
PROGRAMS = routerv4_main.p4 \
					 routerv6_main.p4 \
					 routerv46_main.p4 \
					 routerv46lrx_main.p4 \
					 router_ipv4v6srv6_main.p4 \
					 router_ipv4v6_nat_acl.p4

IPv46SRv4 = router_ipv4srv4ipv6_main.p4

PROGRAMS_TOFINO_DIR=$(PROGRAMS:%.p4=./build/%.tofino)
IPv46SRv4_TOFINO_DIR=$(IPv46SRv4:%.p4=./build/%.tofino)

all: $(PROGRAMS_TOFINO_DIR)

ipv46srv4: $(IPv46SRv4_TOFINO_DIR)

rmipv46srv4:
	rm -rf $(IPv46SRv4_TOFINO_DIR)

P7: rmipv46srv4 ipv46srv4
P1_P6: all

$(PROGRAMS_TOFINO_DIR): ./build/%.tofino: %.p4
	mkdir -p build && \
		cd build &&	\
		$(SDE_INSTALL)/$(P4C_TNA) ../$< && \
		cd ..

$(IPv46SRv4_TOFINO_DIR): ./build/%.tofino: %.p4
	mkdir -p build && \
		cd build &&	\
		$(SDE_INSTALL)/$(P4C_TNA) ../$< && \
		cd ..

clean:
	rm -rf ./build
