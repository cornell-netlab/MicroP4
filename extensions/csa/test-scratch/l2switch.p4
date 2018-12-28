#include <core.p4>
#include <csa.p4>
#include "l2switch.ip4"

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32

struct headers_t {}
struct data_t {}
struct e_t {}
  parser UnusedParser(packet_in pin, out headers_t parsed_hdr, 
                  inout data_t meta, 
                  inout standard_metadata_t standard_metadata, 
                  in e_t program_scope_metadata) {

    state start {
      transition accept;
    }
  }

cpackage Layer2Switch : implements CSASwitch {

  header Ethernet_h {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
  }

  struct parsed_headers_t {
    @name("ethernet")
    Ethernet_h ethernet;
  }

  struct my_metadata_t {
    bit<8> if_index;
    bit<32> next_hop;
  }

  // Declarations for programmable blocks of basic switch package type
  parser Parser(packet_in pin, out parsed_headers_t parsed_hdr, 
                  inout my_metadata_t meta, 
                  inout standard_metadata_t standard_metadata, 
                  in empty_t program_scope_metadata) {

    state start {
      // This is a sample metadata update.
      meta.if_index = (bit<8>)standard_metadata.ingress_port;
      transition parse_ethernet;
    }

    state parse_ethernet {
      pin.extract(parsed_hdr.ethernet);
      transition accept;
    }
  }
  
  control Import(in external_meta_t in_meta, inout empty_t inout_meta, 
                 in parsed_headers_t parsed_hdr, inout my_metadata_t meta, 
                 inout standard_metadata_t standard_metadata, egress_spec es) {

    action set_input_parameters () {
      meta.next_hop = in_meta.next_hop;
    }

    apply {
      set_input_parameters();
    }
  }
 
  control Pipe(inout parsed_headers_t parsed_hdr, inout my_metadata_t meta,
               inout standard_metadata_t standard_metadata, egress_spec es) {

    action set_dmac(bit<48> dmac) {
      parsed_hdr.ethernet.dstAddr = dmac;
    }

    action drop_action() {
      standard_metadata.drop_flag = true;
    }
 
    table dmac {
      key = { meta.next_hop: exact; }
      actions = {
        drop_action;
        set_dmac;
      }
      size = TABLE_SIZE;
      default_action = drop_action;
    }
 
    action set_smac(bit<48> smac) {
      parsed_hdr.ethernet.srcAddr = smac;
    }
 
    table smac {
      key = {  es.get_egress_port() : exact 
                @name("egress_port"); }
      actions = {
        drop_action;
        set_smac;
      }
      size = MAC_TABLE_SIZE;
      default_action = drop_action;
    }
 
    apply {
      dmac.apply();
      smac.apply();
    }
  }

 
  control Deparser(packet_out po, in parsed_headers_t parsed_hdr, 
                   out empty_t program_scope_metadata) {
    apply {
      po.emit(parsed_hdr.ethernet);
    }
  }
}

// Layer2Switch() main;
