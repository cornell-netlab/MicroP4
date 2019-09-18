/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"csa.p4"
#include"common.p4"

struct ecn_meta_t { }
struct empty_t { }

const bit<19> ECN_THRESHOLD = 10;

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

cpackage ecn : implements CSASwitch<external_meta_t, empty_t, empty_t, 
									ecn_hdr_t, ecn_meta_t, empty_t> {
									
  parser csa_parser(packet_in pin, out ecn_hdr_t parsed_hdr, 
                inout ecn_meta_t meta, 
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

  control csa_pipe(inout ecn_hdr_t parsed_hdr, inout ecn_meta_t meta,
                 inout csa_standard_metadata_t standard_metadata, egress_spec es) {
   
    action set_ecn{
    	hdr.ipv4.ecn = 3;
    }
    table ecn_tbl{
    	key = {
    		hdr.ipv4.ecn : exact;
    		standard_metadata.enq_qdepth: ternary;
    	}
    	action = {
    		set_ecn;
    	}
    	entries = {
    	8w0o1: set_ecn();
    	8w0o2: set_ecn();
    	}
    }
    
    apply {
  		if (standard_metadata.enq_qdepth >= ECN_THRESHOLD){
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

