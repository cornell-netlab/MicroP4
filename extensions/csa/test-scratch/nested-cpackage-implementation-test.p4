#include <core.p4>
#include <csa.p4>
#include "l2switch.ip4"

cpackage CSASwitchImpl : implements CSASwitch {

  header Ethernet_h {
    bit<96> unused;
    bit<16> etherType;
  }

  struct parsed_headers_t {
    @name("ethernet")
    Ethernet_h ethernet;
  }

  struct csa_switch_impl_metadata_t {
    bit<8> if_index;
    bit<32> next_hop;
  }

  struct program_scope_metadata_t {
    bit<32> invariant; // invariant field across execution of Parallel & Execute
                       // packages and recirculate calls
  }

  // Declarations for programmable blocks of basic switch cpackage type
  parser Parser(packet_in pin, out parsed_headers_t parsed_hdr, 
                  inout csa_switch_impl_metadata_t meta, 
                  inout standard_metadata_t standard_metadata, 
                  in program_scope_metadata_t program_scope_metadata) {
    state start {
      transition accept;
    }
  }
  
  control Pipe(inout parsed_headers_t parsed_hdr, inout csa_switch_impl_metadata_t meta,
               inout standard_metadata_t standard_metadata,
               egress_spec es) {
    apply {
    }
  }
 
  control Deparser(packet_out po, in parsed_headers_t parsed_hdr,
                   out program_scope_metadata_t program_scope_metadata) {
    apply {
    }
  }


  cpackage ParallelImpl : implements ParallelSwitch {
  
    control ResultPipe(in empty_t in_meta, out empty_t out_meta, inout empty_t inout_meta, 
                       inout parsed_headers_t hdr, inout csa_switch_impl_metadata_t meta, 
                       inout standard_metadata_t sm, egress_spec es, 
                       inout program_scope_metadata_t program_scope_meta,
                       in callee_context_t ctx) {
      apply {
      }
    }
 
  }

}
