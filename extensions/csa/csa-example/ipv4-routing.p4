/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"csa.p4"
#include"common.p4"

struct l3_meta_t { }
struct empty_t { }

header ethernet_h {
    bit<96> unused;
    bit<16> etherType;
}

header ipv4_h {
  bit<4> version;
  bit<4> ihl;
  bit<8> diffserv;
  bit<16> totalLen;
  bit<16> identification;
  bit<3> flags;
  bit<13> fragOffset;
  bit<8> ttl;
  bit<8> protocol;
  bit<16> hdrChecksum;
  bit<16> srcAddr;
  bit<16> dstAddr; 
}

struct l3_hdr_t {
  ethernet_h ethernet;
  ipv4_h ipv4;
}

cpackage l3 : implements <external_meta_t, empty_t, empty_t, 
									l3_hdr_t, ecn_meta_t, empty_t> {

	parser csa_parser(packet_in pin, out l3_hdr_t parsed_hdr, 
                inout l3_meta_t meta, 
                inout csa_standard_metadata_t standard_metadata){
	    state start {
	      // This is a sample metadata update.
	      meta.if_index = (bit<8>)standard_metadata.ingress_port;
	      transition parse_ethernet;
	    }
	    
	    state parse_ethernet {
	      pin.extract(parsed_hdr.ethernet);
	      transition select(parsed_hdr.ethernet.etherType){
	        0x0800: parse_ipv4;
	      }
	    }
	    
	    state parse_ipv4 {
	      pin.extract(parsed_hdr.ipv4);
	      transition accept;
	    }
  }


  control csa_pipe(inout L3_parsed_headers_t parsed_hdr, inout L3_router_metadata_t meta,
                 inout csa_standard_metadata_t standard_metadata, egress_spec es) {
=
    action process(bit<32> nexthop_ipv4_addr, bit<9> port){
      parsed_hdr.ipv4.ttl = parsed_hdr.ipv4 - 1;
      meta.next_hop = nexthop_ipv4_addr;
      es.set_egress_port(port);
    }
    table ipv4_lpm_tbl {
      key = { parsed_hdr.ipv4.dstAddr : lpm } 
      actions = { process; }
      
    }
    apply { ipv4_lpm_tbl.apply(); }
  }

  control csa_export(out external_meta_t out_meta, inout empty_t inout_meta, 
                   in l3_hdr_t parsed_hdr, in l3_meta_t meta,
                   in csa_standard_metadata_t standard_metadata, egress_spec es) {
        action set_return_parameters() {
            out_meta.next_hop = meta.next_hop;
        }
        apply {
            set_return_parameters();
        }
    }
    
   control csa_deparser(packet_out po, in ecn_hdr_t parsed_hdr) {
    apply {
      po.emit(parsed_hdr.ethernet); 
      po.emit(parsed_hdr.ipv4); 
    }
  }
}

 
