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
  
  control Pipe(inout parsed_headers_t parsed_hdr, inout standard_metadata_t meta,
               inout router_metadata_t standard_metadata,
               egress_spec es) {
    apply {
    }
  }
 
  control Deparser(packet_out po, in parsed_headers_t parsed_hdr,
                   out empty_t program_scope_metadata) {
    apply {
    }
  }
}
