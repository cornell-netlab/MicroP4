/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */
#include <core.p4>
#include <v1model.p4>

#define MAC_TABLE_SIZE 32
#define TABLE_SIZE 1024


struct routerv6_meta_t { 
  bit<8> if_index;
  bit<16> next_hop;
  bit<1> drop_flag;
}
 
header ethernet_h {
  bit<48> dstAddr;
  bit<48> srcAddr;
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


struct routerv6_hdr_t {
  ethernet_h ethernet;
  ipv6_h ipv6;
}

parser ParserImpl (packet_in pin, out routerv6_hdr_t parsed_hdr, 
                inout routerv6_meta_t meta, 
                inout standard_metadata_t standard_metadata) {
 state start {
	   meta.if_index = (bit<8>)standard_metadata.ingress_port;
      transition parse_ethernet;
    }
    
    state parse_ethernet {
      pin.extract(parsed_hdr.ethernet);
      transition select(parsed_hdr.ethernet.etherType){
        0x86DD: parse_ipv6;
        _ : accept;
      }
    }
    
    state parse_ipv6 {
      pin.extract(parsed_hdr.ipv6);
      transition accept;
    }
  
}

control egress(inout routerv6_hdr_t parsed_hdr, inout routerv6_meta_t meta,
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
            
            const entries = {
                19w64 : drop_action();
            }
           
            size = MAC_TABLE_SIZE;
            default_action = NoAction;
        }	
    
	apply{
        drop_table.apply();
	}
}
    
control ingress(inout routerv6_hdr_t parsed_hdr, inout routerv6_meta_t meta,
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
                16w15 : set_dmac(0x000000000002, 9w2);
                16w32 : set_dmac(0x000000000003, 9w3);
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
 
      
    action process(bit<16> nexthop, bit<9> port){
	      parsed_hdr.ipv6.hoplimit = parsed_hdr.ipv6.hoplimit - 1;
	      meta.next_hop = nexthop;
	      standard_metadata.egress_port = port;
    }
    action default_act() {
      meta.next_hop = 0; 
    }
     
    table ipv6_lpm_tbl {
      key = { 
      	parsed_hdr.ipv6.dstAddr : lpm ;
        parsed_hdr.ipv6.class : ternary;
        parsed_hdr.ipv6.label : ternary;
        } 
      actions = { 
	      process; 
	      default_act;
	   }
	  default_action = default_act;    
      
    }
    
 
	
	apply{
	 ipv6_lpm_tbl.apply();
	 dmac.apply(); 
     smac.apply();
	}
}

control DeparserImpl(packet_out packet, in  routerv6_hdr_t hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv6); 
    }
}


control verifyChecksum(inout  routerv6_hdr_t hdr, inout routerv6_meta_t meta) {
    apply {
    }
}

control computeChecksum(inout  routerv6_hdr_t hdr, inout routerv6_meta_t meta) {
    apply {
    }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;
