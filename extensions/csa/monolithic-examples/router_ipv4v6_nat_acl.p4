/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */
#include <core.p4>
#include <v1model.p4>

#define MAC_TABLE_SIZE 32


struct router_nat_acl_meta_t { 
  bit<8> if_index;
  bit<16> next_hop;
  bit<1> drop_flag;
  bit<16> sp;
  bit<16> dp;
}
 
header ethernet_h {
  bit<48> dmac;
  bit<48> smac;
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
  bit<16> checksum;
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

header tcp_nat_acl_h {
  bit<16> srcPort;
  bit<16> dstPort;
  bit<96> unused;
  bit<16> checksum;
  bit<16> urgentPointer;
}

header udp_nat_acl_h {
  bit<16> srcPort;
  bit<16> dstPort;
  bit<16> len;
  bit<16> checksum;
}

struct router_nat_acl_hdr_t {
  ethernet_h eth;
  ipv4_h ipv4;
  ipv6_h ipv6;
  tcp_nat_acl_h tcpnf;
  udp_nat_acl_h udpnf;
}

struct ipv4_nat_acl_meta_t {
  bit<16> sp;
  bit<16> dp;
}


parser ParserImpl (packet_in pin, out router_nat_acl_hdr_t parsed_hdr, 
                inout router_nat_acl_meta_t meta, 
                inout standard_metadata_t standard_metadata) {
 state start {
	   meta.if_index = (bit<8>)standard_metadata.ingress_port;
      transition parse_ethernet;
    }
    
    state parse_ethernet {
      pin.extract(parsed_hdr.eth);
      transition select(parsed_hdr.eth.etherType){
        0x0800: parse_ipv4;
        0x86DD: parse_ipv6;
        _ : accept;
      }
    }
    
    state parse_ipv4 {
      pin.extract(parsed_hdr.ipv4);
      transition select (parsed_hdr.ipv4.protocol) {
        8w0x17 : parse_udp;
        8w0x06 : parse_tcp;
        _ : accept;
      }
    }
    
    state parse_tcp {
      pin.extract(parsed_hdr.tcpnf);
      meta.sp = parsed_hdr.tcpnf.srcPort;
      meta.dp = parsed_hdr.tcpnf.dstPort;
      transition accept;
    }
    state parse_udp {
      pin.extract(parsed_hdr.udpnf);
      meta.sp = parsed_hdr.udpnf.srcPort;
      meta.dp = parsed_hdr.udpnf.dstPort;
      transition accept;
    }
    
    state parse_ipv6 {
      pin.extract(parsed_hdr.ipv6);
      transition accept;
    }
  
}

control egress(inout router_nat_acl_hdr_t parsed_hdr, inout router_nat_acl_meta_t meta,
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
    
control ingress(inout router_nat_acl_hdr_t parsed_hdr, inout router_nat_acl_meta_t meta,
                 inout standard_metadata_t standard_metadata) {	
	bit<1> hard_drop;
	bit<1> soft_drop;
	bit<16> next_hop;
	
    action forward(bit<48> dmac, bit<48> smac, bit<9> port) {
      parsed_hdr.eth.dmac = dmac;
      parsed_hdr.eth.smac = smac;
      standard_metadata.egress_port = port;
    }
    table forward_tbl {
      key = { next_hop : exact; } 
      actions = { forward; }
    }
	
    action send_to(bit<9> port) {
       standard_metadata.egress_port = port;
    }
    table switch_tbl {
      key = { 
        parsed_hdr.eth.dmac : exact; 
        standard_metadata.egress_port : exact;
      } 
      actions = { 
        send_to();
      }
    }              
    // lpm tables
    action process(bit<16> nh) {
      parsed_hdr.ipv4.ttl = parsed_hdr.ipv4.ttl - 1;
      next_hop = nh;  // setting out param
    }
    action default_act() {
      next_hop = 0; 
    }

    table ipv4_lpm_tbl {
      key = { 
        parsed_hdr.ipv4.dstAddr : lpm;
        parsed_hdr.ipv4.diffserv : ternary;
      } 
      actions = { 
        process; 
        default_act;
      }
      default_action = default_act;
    } 
     action process_v6(bit<16> nh){
      parsed_hdr.ipv6.hoplimit = parsed_hdr.ipv6.hoplimit - 1;
      next_hop = nh;
    }
    
    table ipv6_lpm_tbl {
      key = { 
        parsed_hdr.ipv6.dstAddr : lpm;
        parsed_hdr.ipv6.class : ternary;
        parsed_hdr.ipv6.label : ternary;
      } 
      actions = {
        process_v6; 
        default_act;
      }
      default_action = default_act;
    }
    // filter tables 
    action set_hard_drop() {
      hard_drop = 1w1;
      soft_drop = 1w0;
    }
    action set_soft_drop() {
      hard_drop = 1w0;
      soft_drop = 1w1;
    }
    action allow() {
      hard_drop = 1w0;
      soft_drop = 1w0;
    }

    table ipv4_filter {	
      key = { 
        parsed_hdr.ipv4.srcAddr : ternary;
        parsed_hdr.ipv4.dstAddr : ternary;
      } 
      actions = { 
        set_hard_drop; 
        set_soft_drop;
        allow;
      }
      default_action = allow;
    }
    
    table ipv6_filter {
      key = { 
        parsed_hdr.ipv6.srcAddr : exact;
        parsed_hdr.ipv6.dstAddr : exact;
      } 
      actions = { 
        set_hard_drop; 
        set_soft_drop;
        allow;
      }
      default_action = allow;
    }  
    // natting 
     action set_ipv4_src(bit<32> is) {
      parsed_hdr.ipv4.srcAddr = is;
      parsed_hdr.ipv4.checksum = 16w0x0000;
    }
    action set_ipv4_dst(bit<32> id) {
      parsed_hdr.ipv4.dstAddr = id;
      parsed_hdr.ipv4.checksum = 16w0x0000;
    }
    action set_tcp_dst_src(bit<16> td, bit<16> ts) {
      parsed_hdr.tcpnf.dstPort = td;
      parsed_hdr.tcpnf.srcPort = ts;
      parsed_hdr.tcpnf.checksum = 16w0x0000;
    }

    action set_tcp_dst(bit<16> td) {
      parsed_hdr.tcpnf.dstPort = td;
      parsed_hdr.tcpnf.checksum = 16w0x0000;
    }
    action set_tcp_src(bit<16> ts) {
      parsed_hdr.tcpnf.srcPort = ts;
      parsed_hdr.tcpnf.checksum = 16w0x0000;
    }

    action set_udp_dst_src(bit<16> ud, bit<16> us) {
      parsed_hdr.udpnf.dstPort = ud;
      parsed_hdr.udpnf.srcPort = us;
      parsed_hdr.udpnf.checksum = 16w0x0000;
    }
    action set_udp_dst(bit<16> ud) {
      parsed_hdr.udpnf.dstPort = ud;
      parsed_hdr.udpnf.checksum = 16w0x0000;
    }
    action set_udp_src(bit<16> us) {
      parsed_hdr.udpnf.srcPort = us;
      parsed_hdr.udpnf.checksum = 16w0x0000;
    }
    action na(){}

    table ipv4_nat {
      key = { 
        parsed_hdr.ipv4.srcAddr : exact;
        parsed_hdr.ipv4.dstAddr : exact;
        parsed_hdr.ipv4.protocol : exact;
        meta.sp : exact;
        meta.dp : exact;
      } 
      actions = { 
        set_ipv4_src;
        set_ipv4_dst;
        set_tcp_src;
        set_tcp_dst;
        set_udp_dst;
        set_udp_src;
        set_tcp_dst_src;
        set_udp_dst_src;
        na;
      }
      default_action = na();
    }
     
    action set_ipv6_src(bit<128> is) {
      parsed_hdr.ipv6.srcAddr = is;
    }
    action set_ipv6_dst(bit<128> id) {
      parsed_hdr.ipv6.dstAddr = id;
    }
    
    table ipv6_nat {
      key = { 
        parsed_hdr.ipv6.srcAddr : exact;
        parsed_hdr.ipv6.dstAddr : exact;
      } 
      actions = { 
        set_ipv6_src;
        set_ipv6_dst;
        na;
      }
      default_action = na();
    }
    
	apply{
		  next_hop = 16w0;
	      hard_drop = 1w0;
	      soft_drop = 1w0;
	      if ( parsed_hdr.eth.etherType == 16w0x0800) {
	        {
	        	ipv4_nat.apply(); 
	        	if (hard_drop == 1w0)
			        ipv4_filter.apply(); 
			    }
		        ipv4_lpm_tbl.apply(); 
		    } else if (parsed_hdr.eth.etherType == 16w0x86DD) {
		        ipv6_nat.apply(); 
			    if (hard_drop == 1w0)
			        ipv6_filter.apply(); 
		        ipv6_lpm_tbl.apply(); 
		     }
	        if (hard_drop == 1w0 && soft_drop == 1w0)
	          forward_tbl.apply(); 
	        else if (next_hop == 16w0)
	          switch_tbl.apply();
	        else 
	         meta.drop_flag = 1; 
	}
}

control DeparserImpl(packet_out packet, in  router_nat_acl_hdr_t hdr) {
    apply {
        packet.emit(hdr.eth);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.ipv6);  
    }
}


control verifyChecksum(inout  router_nat_acl_hdr_t hdr, inout router_nat_acl_meta_t meta) {
    apply {
    }
}

control computeChecksum(inout  router_nat_acl_hdr_t hdr, inout router_nat_acl_meta_t meta) {
    apply {
    }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;
