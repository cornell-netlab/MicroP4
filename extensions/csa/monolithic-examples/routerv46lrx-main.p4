/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */
#include <core.p4>
#include <v1model.p4>

#define MAC_TABLE_SIZE 32
#define MPLS_ZONE_TTL 8w32

struct routerv46lsrx_meta_t { 
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


header mpls_h {
  bit<32> label;
  bit<16> exp;
  bit<8> bos;
  bit<8> ttl; 
}

struct routerv46lsrx_hdr_t {
  ethernet_h ethernet;
  ipv4_h ipv4;
  ipv6_h ipv6;
  mpls_h mpls0;
  mpls_h mpls1;
}

parser ParserImpl (packet_in pin, out routerv46lsrx_hdr_t parsed_hdr, 
                inout routerv46lsrx_meta_t meta, 
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
        0x8847: parse_mpls0;
        _ : accept;
      }
    }
    
    state parse_ipv4 {
      pin.extract(parsed_hdr.ipv4);
      transition accept;
    }
    
    state parse_ipv6 {
      pin.extract(parsed_hdr.ipv6);
      transition accept;
    }
    
    state parse_mpls0 {
     pin.extract(parsed_hdr.mpls0);
      transition select(parsed_hdr.mpls0.bos) {
        8w0 : parse_mpls1;
        _ : accept;
      }
     }
    
    state parse_mpls1 {
      pin.extract(parsed_hdr.mpls1);
      transition accept;
    } 
  
}

control egress(inout routerv46lsrx_hdr_t parsed_hdr, inout routerv46lsrx_meta_t meta,
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
    
control ingress(inout routerv46lsrx_hdr_t parsed_hdr, inout routerv46lsrx_meta_t meta,
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
    
    
    action encap1(){
      parsed_hdr.mpls1.setValid();
      
      parsed_hdr.mpls1.label = parsed_hdr.mpls0.label;
      parsed_hdr.mpls1.ttl = parsed_hdr.mpls0.ttl;
      parsed_hdr.mpls1.bos = parsed_hdr.mpls0.bos;
      parsed_hdr.mpls1.exp = parsed_hdr.mpls0.exp;
   		
      parsed_hdr.mpls0.label = 32w0x0400;
      parsed_hdr.mpls0.ttl = MPLS_ZONE_TTL;
      parsed_hdr.mpls1.bos = 8w0;
      meta.next_hop = 16w10;
    }

    action encap0(){
      parsed_hdr.mpls0.setValid();
      parsed_hdr.mpls0.label = 32w0x4000;
      parsed_hdr.mpls0.ttl = MPLS_ZONE_TTL;
      meta.next_hop = 16w10;
    }

    action decap(bit<16> t) {
      parsed_hdr.mpls0.setInvalid();
      meta.next_hop = 16w10;
      parsed_hdr.ethernet.etherType = t;
    }
    
    action replace() {
      // parsed_hdr.mpls0.label = 20w0x4000;
      parsed_hdr.mpls0.ttl = parsed_hdr.mpls0.ttl -1;
      meta.next_hop = 16w10;
    }
    
    table mpls_tbl{
    	key = {
    		parsed_hdr.mpls0.isValid() : exact;
    		parsed_hdr.mpls0.ttl : exact;
    		parsed_hdr.mpls0.label : exact;
        	meta.next_hop : exact;
        	parsed_hdr.ethernet.etherType : exact;
    	}
    	actions = {
    		drop_action;
    		encap0;
    		encap1;
    		decap;
    		replace;
    	}
    }
    
	apply{
	meta.next_hop = 16w0;
	 if(parsed_hdr.ethernet.etherType == 0x0800)
		ipv4_lpm_tbl.apply();
	 else if (parsed_hdr.ethernet.etherType == 0x86DD)
		ipv6_lpm_tbl.apply();
	if (meta.next_hop == 16w0)	
	 	mpls_tbl.apply();
	 dmac.apply(); 
     smac.apply();
	}
}

control DeparserImpl(packet_out packet, in  routerv46lsrx_hdr_t hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.mpls0);
      	packet.emit(hdr.mpls1);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.ipv6);  
    }
}


control verifyChecksum(inout  routerv46lsrx_hdr_t hdr, inout routerv46lsrx_meta_t meta) {
    apply {
    }
}

control computeChecksum(inout  routerv46lsrx_hdr_t hdr, inout routerv46lsrx_meta_t meta) {
    apply {
    }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;
