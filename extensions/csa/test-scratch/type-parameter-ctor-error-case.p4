#include <core.p4>
#include <csa.p4>
#include "l2switch.ip4"

cpackage Router : implements CSASwitch {

  header Ethernet_h {
    bit<96> unused;
    bit<16> etherType;
  }

  struct parsed_headers_t {
    @name("ethernet")
    Ethernet_h ethernet;
  }

  struct router_metadata_t {
    bit<8> if_index;
    bit<32> next_hop;
  }

  // Declarations for programmable blocks of basic switch cpackage type
  parser Parser(packet_in pin, out parsed_headers_t parsed_hdr, 
                  inout router_metadata_t meta, 
                  inout standard_metadata_t standard_metadata, 
                  in empty_t program_scope_metadata) {
    state start {
      transition accept;
    }
  }
  
  control Pipe(inout parsed_headers_t parsed_hdr, inout router_metadata_t meta,
               inout standard_metadata_t standard_metadata,
               egress_spec es) {

    external_meta_t external_meta;
    empty_t empty1;
    empty_t empty2;
    empty_t empty;

    // instantiation
    Layer2Switch() l2_switch_inst;
    Layer2Switch() l2_switch_inst_1;

    ExecuteSwitch(l2_switch_inst)  exec_l2;
    ExecuteSwitch(l2_switch_inst_1)  exec_l2_1;


    apply {
      
      // invoking layer 2 switch
      exec_l2.apply(empty1, external_meta, empty2,
                    parsed_hdr, meta, standard_metadata);

      exec_l2_1.apply(empty1, external_meta, empty2,
                      parsed_hdr, standard_metadata, standard_metadata);
    }
  }
 
  control Deparser(packet_out po, in parsed_headers_t parsed_hdr,
                   out empty_t program_scope_metadata) {
    apply {
    }
  }
}
