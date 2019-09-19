/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"csa.p4"
#include"common.p4"

#define TABLE_SIZE 1024

struct filter_meta_t { }

header ethernet_h {
    bit<96> unused;
    bit<16> etherType;
}

header ipv4_h {
  bit<4> version;
  bit<4> ihl;
  bit<8> diffserv;
  bit<8> ecn;
  bit<16> totalLen;
  bit<16> identification;
  bit<3> flags;
  bit<13> fragOffset;
  bit<8> ttl;
  bit<8> protocol;
  bit<16> hdrChecksum;
  bit<32> srcAddr;
  bit<32> dstAddr; 
}

header tcp_h {
  bit<16> srcPort;
  bit<16> dstPort;
  bit<128> unused;
}
struct filter_hdr_t {
  ethernet_h ethernet;
  ipv4_h ipv4;
  tcp_h tcp;
}

cpackage filter : implements CSASwitch<empty_t, external_meta_t, empty_t, 
									filter_hdr_t, filter_meta_t, empty_t> {
									
  parser csa_parser(packet_in pin, out filter_hdr_t parsed_hdr, 
                inout filter_meta_t meta, 
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
       transition select(parsed_hdr.ipv4.protocol) {
                0b0110: parse_tcp;
                _ : accept;
            }
    }
	state parse_tcp {
      pin.extract(parsed_hdr.tcp);
       transition accept;
    }    
  }

  control csa_pipe(inout filter_hdr_t parsed_hdr, inout filter_meta_t meta,
                 inout csa_standard_metadata_t standard_metadata, egress_spec es) {
   
   action drop_action() {
            standard_metadata.drop_flag = true;
       }
    table filter_tbl{
    	key = {
    		parsed_hdr.tcp.srcPort : exact;
    	}
    	actions = {
    		drop_action;
    	}
    	const entries = {
    	     16w0x0050: drop_action();
    	     16w0x1F90: drop_action();
    	}
    }
    
    apply {
      		filter_tbl.apply();
    }
  }

  control csa_deparser(packet_out po, in filter_hdr_t parsed_hdr) {
    apply {
      po.emit(parsed_hdr.ethernet); 
      po.emit(parsed_hdr.ipv4);
      po.emit(parsed_hdr.tcp);  
    }
  }
}

