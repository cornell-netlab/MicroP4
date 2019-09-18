/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"csa.p4"
#include"common.p4"

#define TABLE_SIZE 1024

header ethernet_h {
  bit<48> dstAddr;
  bit<48> srcAddr;
  bit<16> etherType;
}

struct hdr_t {
  ethernet_h eth;
}

struct l2_meta_t { 
}


cpackage l2 : implements CSASwitch<external_meta_t, empty_t, empty_t, 
									hdr_t, l2_meta_t, empty_t> {

  parser csa_parser(packet_in pin, out hdr_t parsed_hdr, 
                inout l2_meta_t meta, 
                inout csa_standard_metadata_t standard_metadata){
	    state start {
	      transition parse_ethernet;
	    }
	    
	    state parse_ethernet {
	      pin.extract(parsed_hdr.eth);
	      transition accept;
	    }
  }

  control csa_pipe(inout hdr_t parsed_hdr, inout l2_meta_t meta,
                 inout csa_standard_metadata_t standard_metadata, egress_spec es) {
            
    action forward(bit<48> dmac, bit<48> smac, bit<9> port) {
        parsed_hdr.eth.dstAddr = dmac;
        parsed_hdr.eth.srcAddr = smac;
        es.set_egress_port(port);    
    }
    table forward_tbl {
      key = { } 
      actions = { forward;}
    }
    apply {
      forward_tbl.apply(); 
    }
  }

 control csa_deparser(packet_out po, in hdr_t parsed_hdr) {
    apply {
      po.emit(parsed_hdr.eth); 
    }
  }

}
