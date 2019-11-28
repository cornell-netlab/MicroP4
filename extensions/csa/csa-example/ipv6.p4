/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"csa.p4"
#include"common.p4"

#define TABLE_SIZE 1024

struct l3_meta_t { 
 bit<128> next_hop;}

header ethernet_h {
    bit<96> unused;
    bit<16> etherType;
}

header ipv6_h {
  bit<4> version;
  bit<8> class;
  bit<20> label;
  bit<16> totalLen;
  bit<8> nexthdr;
  bit<8> hoplimit;
  bit<128> srcAddr;
  bit<128> dstAddr;  
}

struct l3_hdr_t {
  ethernet_h ethernet;
  ipv6_h ipv6;
}

cpackage ipv6l3 : implements CSASwitch<empty_t, external_meta_t, empty_t, 
                                       l3_hdr_t, 
                                       l3_meta_t, empty_t> {

	parser csa_parser(packet_in pin, out l3_hdr_t parsed_hdr, 
                inout l3_meta_t meta, 
                inout csa_standard_metadata_t standard_metadata){
	    state start {
	      transition parse_ethernet;
	    }
	    
	    state parse_ethernet {
	      pin.extract(parsed_hdr.ethernet);
	      transition select(parsed_hdr.ethernet.etherType){
	        0x86DD: parse_ipv6;
	      }
	    }
	    
	    state parse_ipv6 {
	      pin.extract(parsed_hdr.ipv6);
	      transition accept;
	    }
  }


  control csa_pipe(inout l3_hdr_t parsed_hdr, inout l3_meta_t meta,
                 inout csa_standard_metadata_t standard_metadata, egress_spec es) {

    action process(bit<128> nexthop_ipv6_addr, bit<9> port){
      hdr.ipv6.hoplimit = hdr.ipv6.hoplimit - 1;
      meta.next_hop = nexthop_ipv6_addr;
      es.set_egress_port(port);
    }
    table ipv6_lpm_tbl {
      key = { parsed_hdr.ipv6.dstAddr : lpm ;} 
      actions = { process; }
      
    }
    apply { ipv6_lpm_tbl.apply(); }
  }

  control csa_export(out external_meta_t out_meta, inout empty_t inout_meta, 
                   in l3_hdr_t parsed_hdr, in l3_meta_t meta,
                   in csa_standard_metadata_t standard_metadata, egress_spec es) {
        action set_return_parameters() {
            out_meta.next_hopv6 = meta.next_hop;
        }
        apply {
            set_return_parameters();
        }
    }
    
   control csa_deparser(packet_out po, in l3_hdr_t parsed_hdr) {
    apply {
      po.emit(parsed_hdr.ethernet); 
      po.emit(parsed_hdr.ipv6); 
    }
  }
}

 
