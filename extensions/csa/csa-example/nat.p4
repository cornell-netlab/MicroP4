/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"csa.p4"
#include"common.p4"

#define TABLE_SIZE 1024

struct nat_meta_t { bit<1> change; }

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
struct nat_hdr_t {
  ethernet_h ethernet;
  ipv4_h ipv4;
  tcp_h tcp;
}

cpackage nat : implements CSASwitch<empty_t, external_meta_t, empty_t, 
                                       nat_hdr_t, 
                                       nat_meta_t, empty_t> {
									
  parser csa_parser(packet_in pin, out nat_hdr_t parsed_hdr, 
                inout nat_meta_t meta, 
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

  control csa_pipe(inout nat_hdr_t parsed_hdr, inout nat_meta_t meta,
                 inout csa_standard_metadata_t standard_metadata, egress_spec es) {
   action change_srcAddr() {
            meta.change = 1;
       }
   table srcAddr_tbl{
    	key = {
    		parsed_hdr.ipv4.srcAddr : lpm;
    	}
    	actions = {
    		change_srcAddr;
    	}
    	const entries = {
    	     0x0a000200 &&& 0xffffff00: change_srcAddr();
    	}
   }
   action change_srcport(bit<16> srcPort) {
            parsed_hdr.tcp.srcPort = srcPort;
       }
    table srcPort_tbl{
    	key = {
    		meta.change: exact;
    	}
    	actions = {
    		change_srcport;
    	}
    	const entries = {
    	     1w0b1: change_srcport(16w0x1F90);
    	}
    }
    
    apply {
    		srcAddr_tbl.apply();
      		srcPort_tbl.apply();
    }
  }

  control csa_deparser(packet_out po, in nat_hdr_t parsed_hdr) {
    apply {
      po.emit(parsed_hdr.ethernet); 
      po.emit(parsed_hdr.ipv4);
      po.emit(parsed_hdr.tcp);  
    }
  }
}

