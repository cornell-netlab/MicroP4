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

header ipv4_h {
  bit<4> version;
  bit<4> ihl;
  bit<6> diffserv;
  bit<8> ecn;
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

struct ecn_hdr_t {
  ethernet_h ethernet;
  ipv4_h ipv4;
}

cpackage ecn : implements CSASwitch<empty_t, external_meta_t, empty_t, 
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
        0x0800: parse_ipv4;
      }
    }
    
    state parse_ipv4 {
      pin.extract(parsed_hdr.ipv4);
      transition accept;
    }
  }

  control csa_pipe(inout ecn_hdr_t parsed_hdr, inout ecn_meta_t meta,
                 inout csa_standard_metadata_t standard_metadata, egress_spec es) {
   
    action set_ecn() {
    	parsed_hdr.ipv4.ecn = 3;
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
      po.emit(parsed_hdr.ipv4); 
    }
  }
}

