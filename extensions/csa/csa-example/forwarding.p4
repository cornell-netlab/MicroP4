/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"csa.p4"
#include"common.p4"

header ethernet_h {
  bit<48> dstAddr;
  bit<48> srcAddr;
  bit<16> etherType;
}

struct hdr_t {
  ethernet_h eth;
}

struct meta_t { 
}


cpackage l2 : implements implements <external_meta_t, empty_t, empty_t, 
									hdr_t, meta_t, empty_t> {

  parser csa_parser(packet_in pin, out hdr_t parsed_hdr, 
                inout l3_meta_t meta, 
                inout csa_standard_metadata_t standard_metadata){
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

  control csa_pipe(inout L3_parsed_headers_t parsed_hdr, inout L3_router_metadata_t meta,
                 inout csa_standard_metadata_t standard_metadata, egress_spec es) {
            
    action forward(bit<48> dmac, bit<48> smac, bit<8> port) {
        h.eth.dstAddr = dmac;
        h.eth.srcAddr = smac;
        sm.out_port = port;    
    }
    table forward_tbl {
      key = { } 
      actions = { forward;}
    }
    apply {
      forward_tbl.apply(); 
    }
  }

 control csa_deparser(packet_out po, in ecn_hdr_t parsed_hdr) {
    apply {
      po.emit(parsed_hdr.ethernet); 
    }
  }

}
