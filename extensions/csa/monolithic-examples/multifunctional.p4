/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */
#include <core.p4>
#include <v1model.p4>

#define MAC_TABLE_SIZE 32


struct multifunctional_meta_t { 
  bit<8> if_index;
  bit<32> next_hop;
  bit<1> drop_flag;
  bit<1> change;
}
 
header ethernet_h {
  bit<48> dstAddr;
  bit<48> srcAddr;
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

struct multifunctional_hdr_t {
  ethernet_h ethernet;
  ipv4_h ipv4;
  tcp_h tcp;
}

parser ParserImpl (packet_in pin, out multifunctional_hdr_t parsed_hdr, 
                inout multifunctional_meta_t meta, 
                inout standard_metadata_t standard_metadata) {
 state start {
	   meta.if_index = (bit<8>)standard_metadata.ingress_port;
      transition parse_ethernet;
    }
    
    state parse_ethernet {
      pin.extract(parsed_hdr.ethernet);
      transition select(parsed_hdr.ethernet.etherType){
        0x0800: parse_ipv4;
        _ : accept;
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

control ingress(inout multifunctional_hdr_t parsed_hdr, inout multifunctional_meta_t meta,
                 inout standard_metadata_t standard_metadata) {	
                         action drop_action() {
            meta.drop_flag = 1;
        }
 
      table drop_table{
            key = { 
                standard_metadata.deq_qdepth
                  : exact ;
            }
            actions = {
                drop_action;
                NoAction;
            }
            /*
            const entries = {
                16w5 : drop_action();
            }
            */
            size = MAC_TABLE_SIZE;
            default_action = NoAction;
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

	apply{
		filter_tbl.apply();
        drop_table.apply();
        ecn_tbl.apply();
	}
}
    
control egress(inout multifunctional_hdr_t parsed_hdr, inout multifunctional_meta_t meta,
                 inout standard_metadata_t standard_metadata) {	
      action set_dmac(bit<48> dmac, bit<9> port) {
          // P4Runtime error...
            standard_metadata.egress_port = port;
            parsed_hdr.ethernet.dstAddr = dmac;
        }

        action drop_action() {
            meta.drop_flag = 1;
        }
 
        table dmac {
            key = { meta.next_hop: exact; }
            actions = {
                drop_action;
                set_dmac;
            }
            const entries = {
                0x0a000201 : set_dmac(0x000000000002, 9w2);
                0x0a000301 : set_dmac(0x000000000003, 9w3);
            }
            default_action = drop_action;
            // size = TABLE_SIZE;
        }
 
        action set_smac(bit<48> smac) {
            parsed_hdr.ethernet.srcAddr = smac;
        }
 
        table smac {
            key = {  standard_metadata.egress_port : exact ; }
            actions = {
                drop_action;
                set_smac;
            }
            default_action = drop_action;
            const entries = {
                9w2 : set_smac(0x000000000020);
                9w3 : set_smac(0x000000000030);
            }
            // size = MAC_TABLE_SIZE;
        }
 
      
    action process(bit<32> nexthop_ipv4_addr, bit<9> port){
      parsed_hdr.ipv4.ttl = parsed_hdr.ipv4.ttl - 1;
      meta.next_hop = nexthop_ipv4_addr;
      standard_metadata.egress_port = port;
    }
    table ipv4_lpm_tbl {
      key = { parsed_hdr.ipv4.dstAddr : lpm ;} 
      actions = { process; }
    }
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
 
	
	apply{
	 srcAddr_tbl.apply();
	 srcPort_tbl.apply();
	 ipv4_lpm_tbl.apply();
	 dmac.apply(); 
     smac.apply();
	 
	
	}
}

control DeparserImpl(packet_out packet, in  multifunctional_hdr_t hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.tcp);  
    }
}


control verifyChecksum(inout  multifunctional_hdr_t hdr, inout multifunctional_meta_t meta) {
    apply {
    }
}

control computeChecksum(inout  multifunctional_hdr_t hdr, inout multifunctional_meta_t meta) {
    apply {
    }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;
