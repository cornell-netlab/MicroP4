/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */
#include <core.p4>
#include <v1model.p4>

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32
#define ROUTER_IP 0x0a000256
#define N1 0x0a000256
#define N2 0x0a000256


struct routerv46_ipsrv4ipv6_meta_t { 
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

header option_h {
	bit<8> useless;
	bit<8> option_num;
	bit<8> len;
	bit<8> data_pointer; 
}

header sr4_h {
	bit<32> addr1;
	bit<32> addr2;
	bit<32> addr3;
	bit<32> addr4;
	bit<32> addr5;
	bit<32> addr6;
}

struct routerv46_ipsrv4ipv6_hdr_t {
  ethernet_h ethernet;
  ipv4_h ipv4;
  option_h option;
  sr4_h	sr;
  ipv6_h ipv6;
}

parser ParserImpl (packet_in pin, out routerv46_ipsrv4ipv6_hdr_t parsed_hdr, 
                inout routerv46_ipsrv4ipv6_meta_t meta, 
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
      transition select(parsed_hdr.ipv4.ihl){
      		4w0x05 : accept;
      		4w0x04 : accept;
      		4w0 &&& 4w0x0c : accept; // match all ihl < 4
      		_ :  accept; // TODO match ihl more than 4w0x05
      }
    }
    
    state parse_option {
    	pin.extract(parsed_hdr.option);
    	transition select (parsed_hdr.option.option_num){
    		8w0x03: parse_src_routing; // loose 
    		8w0x09: parse_src_routing; //strict
    	}
    }
    
    state parse_src_routing {
	      pin.extract(parsed_hdr.sr);
	      transition accept;
    }
    
    state parse_ipv6 {
      pin.extract(parsed_hdr.ipv6);
      transition accept;
    }
  
}

control egress(inout routerv46_ipsrv4ipv6_hdr_t parsed_hdr, inout routerv46_ipsrv4ipv6_meta_t meta,
                 inout standard_metadata_t standard_metadata) {	
                 /*
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
        */
    
	apply{
        // drop_table.apply();
	}
}
    
control ingress(inout routerv46_ipsrv4ipv6_hdr_t parsed_hdr, inout routerv46_ipsrv4ipv6_meta_t meta,
                 inout standard_metadata_t standard_metadata) {	
      bit<32> neighbour = 32w0;
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
            /*
            const entries = {
                16w15 : set_dmac(0x000000000002, 9w2);
                16w32 : set_dmac(0x000000000003, 9w3);
            }
            */
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

    action set_nexthop(bit<32> nextHopAddr) {
      neighbour = nextHopAddr;
    }
    action set_nexthop_addr2() {
      neighbour = parsed_hdr.sr.addr2;
    }
    action set_nexthop_addr3() {
      neighbour = parsed_hdr.sr.addr3;
    }
    action set_nexthop_addr4() {
      neighbour = parsed_hdr.sr.addr4;
    }
    action set_nexthop_addr5() {
      neighbour = parsed_hdr.sr.addr5;
    }
    action set_nexthop_addr6() {
      neighbour = parsed_hdr.sr.addr6;
    }
    /*
    action find_nexthop() {
    //TODO
    }
    */
    table sr4_tbl{
    	key = {
        parsed_hdr.option.option_num: exact;
        parsed_hdr.sr.addr1: exact;
        parsed_hdr.sr.addr2: exact;
        parsed_hdr.sr.addr3: exact;
        parsed_hdr.sr.addr4: exact;
        parsed_hdr.sr.addr5: exact;
        parsed_hdr.sr.addr6: exact;
    	}
    	actions = {
    		drop_action;
        set_nexthop_addr2;
        set_nexthop_addr3;
        set_nexthop_addr4;
        set_nexthop_addr5;
        set_nexthop_addr6;
        set_nexthop;
    	}
      /*
    	const entries = {
    	   (8w0x03, ROUTER_IP,_, _ , _, _,_): set_nexthop_addr2();
    	   (8w0x03, _,ROUTER_IP, _ , _, _,_): set_nexthop_addr3();
    	   (8w0x03, _,_,ROUTER_IP, _, _,_): set_nexthop_addr4();
    	   (8w0x03,_,_,_,ROUTER_IP, _,_): set_nexthop_addr5();
    	   (8w0x03,_,_,_,_, ROUTER_IP,_): set_nexthop_addr6();

    	   (8w0x03, N1,_, _ , _, _,_): set_nexthop(N1);
    	   (8w0x03, _,N1, _ , _, _,_): set_nexthop(N1);
    	   (8w0x03, _,_, N1 , _, _,_): set_nexthop(N1); 
         // skipped other 6 permutation for N1
    	   (8w0x03, N2,_, _ , _, _,_): set_nexthop(N2);
    	   (8w0x03, _,N2, _ , _, _,_): set_nexthop(N2);
    	   (8w0x03, _,_, N2 , _, _,_): set_nexthop(N2);
    	   // (8w0x03, _,_, _ , _, _,_,_,_,_): find_nexthop();
        
    	   (8w0x09, ROUTER_IP,_, _ , _, _,_): set_nexthop_addr2();
    	   (8w0x09, _,ROUTER_IP, _ , _, _,_): set_nexthop_addr3();
    	   (8w0x09, _,_,ROUTER_IP, _, _,_): set_nexthop_addr4();
    	   (8w0x09,_,_,_,ROUTER_IP, _,_): set_nexthop_addr5();
    	   (8w0x09,_,_,_,_, ROUTER_IP,_): set_nexthop_addr6();
    	   (8w0x09, _,_, _ , _, _,_): drop_action();
    	}
      */
    }
    
    action set_out_arg(bit<16> n) {
       meta.next_hop = n; 
    }
     table set_out_nh_tbl{
    	key = {
    	  neighbour: exact;
    	}
    	actions = {
    		set_out_arg;
      }
    }
    
	apply{
	if(parsed_hdr.ethernet.etherType == 0x0800){
		if (parsed_hdr.ipv4.ihl != 4w0x05){
			sr4_tbl.apply();
      set_out_nh_tbl.apply(); // this table
		}
    else {
		  ipv4_lpm_tbl.apply();
    }
    
	}
	else if (parsed_hdr.ethernet.etherType == 0x86DD) {
		ipv6_lpm_tbl.apply();
	}
	 dmac.apply(); 
   smac.apply();
  }
}

control DeparserImpl(packet_out packet, in  routerv46_ipsrv4ipv6_hdr_t hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.option); 
        packet.emit(hdr.sr);
        packet.emit(hdr.ipv6);  
    }
}


control verifyChecksum(inout  routerv46_ipsrv4ipv6_hdr_t hdr, inout routerv46_ipsrv4ipv6_meta_t meta) {
    apply {
    }
}

control computeChecksum(inout  routerv46_ipsrv4ipv6_hdr_t hdr, inout routerv46_ipsrv4ipv6_meta_t meta) {
    apply {
    }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;
