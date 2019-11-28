/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"csa.p4"
#include"common.p4"

#define TABLE_SIZE 1024

struct ecn_meta_t { }

header ethernet_h {
    bit<96> unused;
    bit<16> etherType;
}


header ipv6_h {
  bit<4> version;
  bit<8> ecn;
  bit<20> label;
  bit<16> totalLen;
  bit<8> nexthdr;
  bit<8> hoplimit;
  bit<128> srcAddr;
  bit<128> dstAddr;  
}

struct ecn_hdr_t {
  ethernet_h ethernet;
  ipv6_h ipv6;
}

cpackage ecnv6 : implements CSASwitch<empty_t, external_meta_t, empty_t, 
									ecn_hdr_t, ecn_meta_t, empty_t> {
									
  parser csa_parser(packet_in pin, out ecn_hdr_t parsed_hdr, 
                inout ecn_meta_t meta, 
                inout csa_standard_metadata_t standard_metadata){
    state start {
      transition parse_ethernet;
    }
    
    state parse_ethernet {
      pin.extract(parsed_hdr.ethernet);
      transition select(parsed_hdr.ethernet.etherType){
        0x0800: parse_ipv6;
      }
    }
    
    state parse_ipv6 {
      pin.extract(parsed_hdr.ipv6);
      transition accept;
    }
  }

  control csa_pipe(inout ecn_hdr_t parsed_hdr, inout ecn_meta_t meta,
                 inout csa_standard_metadata_t standard_metadata, egress_spec es) {
   
    action set_ecn() {
    	parsed_hdr.ipv6.ecn = 3;
    }
    table ecn_tbl{
    	key = {
    		parsed_hdr.ipv4.ecn : exact;
    	}
    	actions = {
    		set_ecn;
    	}
    	const entries = {
    	    8w0o1: set_ecn();
    	    8w0o2: set_ecn();
    	}
    }
    
    apply {
      		ecn_tbl.apply();
    }
  }

  control csa_deparser(packet_out po, in ecn_hdr_t parsed_hdr) {
    apply {
      po.emit(parsed_hdr.ethernet); 
      po.emit(parsed_hdr.ipv6); 
    }
  }
}

