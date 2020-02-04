/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */
#include <core.p4>
#include <v1model.p4>

#define MAC_TABLE_SIZE 32
#define TABLE_SIZE 1024
#define MAX_SEG_LEFT 256
#define SEG_LEN 128
#define ROUTER_FUNC 0 // 0 for SR domain entry point , 1 for SR transit node
#define FIRST_SEG 0x02560a0b0c025660a0b0f5670dbbfe03
#define ROUTER_IP 0x20010a0b0c025660a0b0f5670dbbfe01
#define LOCAL_SRV6_SID 0x025603a1cc025660000000000000000
#define LOCAL_INT 0x02560a0b0c0256600000000000000000


struct routerv46SRv6_meta_t { 
  bit<8> if_index;
  bit<16> next_hop;
  bit<1> drop_flag;
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

header routing_ext_h {
	bit<8> nexthdr;
	bit<8> hdr_ext_len; // gives the length of the routing extension header in octets
	bit<8> routing_type;
}

// Here we consider that we do not have any options configured in the TLV
header sr6_h {
	bit<8> seg_left;
	bit<8> last_entry;  // index of the last element of the segment list zero based
	bit<8> flags; // 0 flag --> unused 
	bit<16> tag; // 0 if unused , not used when processsing the sid in 4.3.1
}
header seg1_h {
	bit<128> seg;
}
header seg2_h {
	bit<128> seg;
}
header seg3_h {
	bit<128> seg;
}
header seg4_h {
	bit<128> seg;
}

struct routerv46SRv6_hdr_t {
  ethernet_h ethernet;
  ipv4_h ipv4;
  ipv6_h ipv6;
  routing_ext_h routing_ext0;
  sr6_h sr6;
  seg1_h seg1;
  seg2_h seg2;
  // seg3_h seg3;
  // seg4_h seg4;
}

parser ParserImpl (packet_in pin, out routerv46SRv6_hdr_t parsed_hdr, 
                inout routerv46SRv6_meta_t meta, 
                inout standard_metadata_t standard_metadata) {
 state start {
	   meta.if_index = (bit<8>)standard_metadata.ingress_port;
      transition parse_ethernet;
    }
    
    state parse_ethernet {
      pin.extract(parsed_hdr.ethernet);
      transition select(parsed_hdr.ethernet.etherType){
        0x0800: parse_ipv4;
        0x86DD: parse_ipv6;
        _ : accept;
      }
    }
    
    state parse_ipv4 {
      pin.extract(parsed_hdr.ipv4);
      transition accept;
    }
    
    state parse_ipv6 {
      pin.extract(parsed_hdr.ipv6);
      transition select(parsed_hdr.ipv6.nexthdr) {
        43: parse_routing_ext;
        _ : accept;
      }
    }

    state parse_routing_ext {
      pin.extract(parsed_hdr.routing_ext0);
      transition select(parsed_hdr.routing_ext0.routing_type){
      	4: check_seg_routing; 
      	_ : accept;
      }
    }
  
    state check_seg_routing {
      transition select(parsed_hdr.ipv6.dstAddr){
        ROUTER_IP : parse_seg_routing;
        _ : accept;
      }
    }
    
    state parse_seg_routing {
      pin.extract(parsed_hdr.sr6);
      transition select(parsed_hdr.sr6.seg_left) {
        1: parse_seg1;
        2: parse_seg2;
        _ : accept;
    		// 3: parse_seg3;
    		// 4: parse_seg4;
      }
	  }
	
    state parse_seg1 {
      pin.extract(parsed_hdr.seg1);
      transition accept;
    }
	
    state parse_seg2 {
      pin.extract(parsed_hdr.seg1);
      pin.extract(parsed_hdr.seg2);
      transition accept;
    }
	
  /*
    state parse_seg3 {
      pin.extract(parsed_hdr.seg1);
      pin.extract(parsed_hdr.seg2);
      pin.extract(parsed_hdr.seg3);
      transition accept;
    }
    state parse_seg4 {
      pin.extract(parsed_hdr.seg1);
      pin.extract(parsed_hdr.seg2);
      pin.extract(parsed_hdr.seg3);
      pin.extract(parsed_hdr.seg4);
      transition accept;
    }
    */
  
}

control egress(inout routerv46SRv6_hdr_t parsed_hdr, inout routerv46SRv6_meta_t meta,
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
    
control ingress(inout routerv46SRv6_hdr_t parsed_hdr, inout routerv46SRv6_meta_t meta,
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
 
      
    action process_v4(bit<16> nexthop, bit<9> port){
      parsed_hdr.ipv4.ttl = parsed_hdr.ipv4.ttl - 1;
      meta.next_hop = nexthop;
      standard_metadata.egress_port = port;
    }
    
    action default_act() {
    	meta.next_hop = 0;
    }
    table ipv4_lpm_tbl {
      key = { 
	      parsed_hdr.ipv4.dstAddr : lpm;
	      parsed_hdr.ipv4.diffserv : ternary;
      } 
      actions = { 
	      process_v4; 
	      default_act;
      }
      default_action = default_act;
    }

   
    action process_v6(bit<16> nexthop, bit<9> port){
	      parsed_hdr.ipv6.hoplimit = parsed_hdr.ipv6.hoplimit - 1;
	      meta.next_hop = nexthop;
	      standard_metadata.egress_port = port;
    }
     
    table ipv6_lpm_tbl {
      key = { 
      	parsed_hdr.ipv6.dstAddr : lpm ;
        parsed_hdr.ipv6.class : ternary;
        parsed_hdr.ipv6.label : ternary;
        } 
      actions = { 
	      process_v6; 
	      default_act;
	   }
	  default_action = default_act;    
    }
    
    action copy_frm_first_seg(){
      parsed_hdr.ipv6.dstAddr = parsed_hdr.seg1.seg;
      parsed_hdr.sr6.seg_left = parsed_hdr.sr6.seg_left -1;
    }
    action copy_frm_second_seg(){
      parsed_hdr.ipv6.dstAddr = parsed_hdr.seg2.seg;
      parsed_hdr.sr6.seg_left = parsed_hdr.sr6.seg_left -1;
    }
    /*
    action copy_frm_third_seg(){
      parsed_hdr.ipv6.dstAddr = parsed_hdr.seg3.seg;
      parsed_hdr.sr6.seg_left = parsed_hdr.sr6.seg_left -1;
    }
    action copy_frm_fourth_seg(){
      parsed_hdr.ipv6.dstAddr = parsed_hdr.seg4.seg;
      parsed_hdr.sr6.seg_left = parsed_hdr.sr6.seg_left -1;
    }
    */
    table srv6_table {
    	key = {
	    	 parsed_hdr.routing_ext0.routing_type: exact;
	    	 parsed_hdr.sr6.last_entry: ternary; 
	    	 parsed_hdr.sr6.seg_left: ternary; 
    	}
    	actions = {
    		drop_action; 
        copy_frm_first_seg();
        copy_frm_second_seg();
        // copy_frm_third_seg();
        // copy_frm_fourth_seg();
    	}
    }	
    
	apply{
	if(parsed_hdr.ethernet.etherType == 0x0800)
		ipv4_lpm_tbl.apply();
	else if (parsed_hdr.ethernet.etherType == 0x86DD){
		ipv6_lpm_tbl.apply();
		srv6_table.apply();
	}
	 dmac.apply(); 
     smac.apply();
	}
}

control DeparserImpl(packet_out packet, in  routerv46SRv6_hdr_t hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.ipv6);  
    }
}


control verifyChecksum(inout  routerv46SRv6_hdr_t hdr, inout routerv46SRv6_meta_t meta) {
    apply {
    }
}

control computeChecksum(inout  routerv46SRv6_hdr_t hdr, inout routerv46SRv6_meta_t meta) {
    apply {
    }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;
