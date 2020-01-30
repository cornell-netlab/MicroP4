/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */
#include <core.p4>
#include <v1model.p4>

#define MAC_TABLE_SIZE 32
#define VXLAN_TTL 128
#define VXLAN_UDP_DPORT 4789
#define LOCAL_VTEP_IN_MAC 0x000000000002
#define LOCAL_VTEP_OUT_MAC 0x000000000004
#define LOCAL_VTEP_IP 0x0a002036


struct vxlan_meta_t { 
  bit<8> if_index;
  bit<16> next_hop;
  bit<1> drop_flag;
}
 
header eth_h {
  bit<48> smac;
  bit<48> dmac;
  bit<16> ethType;
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


header vlan_h {
  bit<3> pcp;
  bit<1> dei;
  bit<12> vid;
  bit<16> ethType;
}

header udp_h {
  bit<16> sport; 
  bit<16> dport; 
  bit<16> len;
  bit<16> checksum;
}

header vxlan_h {
  bit<8> flags;
  bit<24> reserved1;
  bit<24> vni;
  bit<8> reserved2;
}

struct vxlan_hdr_t {
  eth_h outer_eth;
  ipv4_h outer_ipv4;
  udp_h outer_udp;
  vxlan_h vxlan;
  eth_h inner_eth;
  vlan_h vlan;
}

parser ParserImpl (packet_in pin, out vxlan_hdr_t parsed_hdr, 
                inout vxlan_meta_t meta, 
                inout standard_metadata_t standard_metadata) {
 state start {
	   meta.if_index = (bit<8>)standard_metadata.ingress_port;
      transition parse_ethernet;
    }
    
    state parse_ethernet {
      pin.extract(parsed_hdr.outer_eth);
      transition select(parsed_hdr.outer_eth.ethType){
        0x8100: parse_vlan;
        _ : accept;
      }
    }

	state parse_vlan{
      pin.extract(parsed_hdr.vlan);
      transition select(parsed_hdr.vlan.ethType){
      	0x0800: parse_outer_ipv4;
      	_ : accept;
      }
    }
    
    state parse_outer_ipv4{
    	pin.extract(parsed_hdr.outer_ipv4);
    	transition select(parsed_hdr.outer_ipv4.protocol){
    		0x11: parse_udp;
    		_ : accept;
    	}
    }
    
    state parse_udp{
    	pin.extract(parsed_hdr.outer_udp);
    	transition select(parsed_hdr.outer_udp.dport){
    		4789: parse_vxlan;
    		_ : accept;
    	}
    }
    
    state parse_vxlan{
    	pin.extract(parsed_hdr.vxlan);
		transition accept;
    }  
  
}

control egress(inout vxlan_hdr_t parsed_hdr, inout vxlan_meta_t meta,
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
    
control ingress(inout vxlan_hdr_t parsed_hdr, inout vxlan_meta_t meta,
                 inout standard_metadata_t standard_metadata) {	
      action set_dmac(bit<48> dmac, bit<9> port) {
          // P4Runtime error...
            standard_metadata.egress_port = port;
            parsed_hdr.outer_eth.dmac = dmac;
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
            parsed_hdr.outer_eth.smac = smac;
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
	  action send_to(bit<9> port) {
	      standard_metadata.egress_port = port;
	    }
	    table switch_tbl {
	      key = { 
	        parsed_hdr.outer_eth.dmac : exact; 
	        standard_metadata.ingress_port :ternary @name("ingress_port");
	      } 
	      actions = { 
	        send_to();
	      }
	    }
      
    action process_v4(bit<16> nexthop, bit<9> port){
      parsed_hdr.outer_ipv4.ttl = parsed_hdr.outer_ipv4.ttl - 1;
      meta.next_hop = nexthop;
      standard_metadata.egress_port = port;
    }
    
    action default_act() {
    	meta.next_hop = 0;
    }
    table ipv4_lpm_tbl {
      key = { 
	      parsed_hdr.outer_ipv4.dstAddr : lpm;
	      parsed_hdr.outer_ipv4.diffserv : ternary;
      } 
      actions = { 
	      process_v4; 
	      default_act;
      }
      default_action = default_act;
    }
    
     action encap( bit<32> vtep_dst_ip, bit<24> vni, bit<16> sport) {
    	  
    	   parsed_hdr.vlan.setInvalid();
    	   parsed_hdr.inner_eth.setValid();
    	   parsed_hdr.inner_eth.dmac = parsed_hdr.outer_eth.dmac;
    	   parsed_hdr.inner_eth.smac = parsed_hdr.outer_eth.smac;
    	   parsed_hdr.inner_eth.ethType = parsed_hdr.vlan.ethType;
           parsed_hdr.vxlan.setValid();
           parsed_hdr.vxlan.flags = 1;
           parsed_hdr.vxlan.reserved1 = 0;
           parsed_hdr.vxlan.vni = vni ;
           parsed_hdr.vxlan.reserved2 = 0;
           parsed_hdr.outer_udp.setValid();
           parsed_hdr.outer_udp.sport = sport;
           parsed_hdr.outer_udp.dport = VXLAN_UDP_DPORT;
           parsed_hdr.outer_udp.len =  0 ; // to set correctly
           parsed_hdr.outer_udp.checksum = 0;
           parsed_hdr.outer_ipv4.setValid();
           parsed_hdr.outer_ipv4.version = 4;
  		   parsed_hdr.outer_ipv4.ihl = 5; // to set correctly
		   parsed_hdr.outer_ipv4.diffserv = 3 ; 
		   parsed_hdr.outer_ipv4.totalLen = 54; // to set correctly
		   parsed_hdr.outer_ipv4.identification = 34; // to set correctly
		   parsed_hdr.outer_ipv4.flags = 1; 
		   parsed_hdr.outer_ipv4.fragOffset = 00; 
		   parsed_hdr.outer_ipv4.ttl = VXLAN_TTL;
  		   parsed_hdr.outer_ipv4.protocol = 0x11;
  		   parsed_hdr.outer_ipv4.hdrChecksum = 0; 
  		   
  		   parsed_hdr.outer_ipv4.srcAddr = LOCAL_VTEP_IP;
  		   parsed_hdr.outer_ipv4.dstAddr = vtep_dst_ip; 

           parsed_hdr.outer_eth.smac = LOCAL_VTEP_OUT_MAC; 
           parsed_hdr.outer_eth.ethType = parsed_hdr.vlan.ethType; 
           
       }
   table vxlan_encap_tbl{
    	key = {
    		parsed_hdr.outer_eth.dmac : exact;
    		parsed_hdr.vlan.vid: exact; 
    	}
    	actions = {
    		encap;
    	}
    	const entries = {
    	     (0x000000000002, 100): encap(0x0a000206, 1000, 49152);
       	}
    }
    
    action decap(bit<12> vid) {
    	parsed_hdr.outer_eth.ethType = 0x8100;
		parsed_hdr.outer_eth.dmac = parsed_hdr.inner_eth.dmac;
    	parsed_hdr.outer_eth.smac = parsed_hdr.inner_eth.smac;
	    parsed_hdr.vxlan.setInvalid();
	    parsed_hdr.outer_udp.setInvalid();
	    parsed_hdr.outer_ipv4.setInvalid();
	    parsed_hdr.inner_eth.setInvalid();
	    parsed_hdr.vlan.setValid();
	    parsed_hdr.vlan.pcp = 3;
	    parsed_hdr.vlan.dei = 0;
	    parsed_hdr.vlan.vid = vid;
	    parsed_hdr.vlan.ethType = parsed_hdr.inner_eth.ethType;
    }
 
    
     table vxlan_decap_tbl{
    	key = {
    		parsed_hdr.outer_eth.dmac : exact;
    		parsed_hdr.vxlan.vni: exact; 
    	}
    	actions = {
    		decap;
    	}
    	const entries = {
    	     (LOCAL_VTEP_IN_MAC, 864): decap(100);
       	}
    }
	apply{
		meta.next_hop = 16w0;
		if(parsed_hdr.vxlan.isValid())
	  		vxlan_decap_tbl.apply();
	  	else 
	  		vxlan_encap_tbl.apply(); 
		
		if(parsed_hdr.outer_eth.ethType == 0x0800)
			ipv4_lpm_tbl.apply();
	   	if (meta.next_hop == 16w0)	
			switch_tbl.apply();
		 dmac.apply(); 
	     smac.apply();
	}
}

control DeparserImpl(packet_out packet, in  vxlan_hdr_t hdr) {
    apply {
        packet.emit(hdr.outer_eth);
    	packet.emit(hdr.vxlan);
      	packet.emit(hdr.outer_udp);
      	packet.emit(hdr.outer_ipv4);
      	packet.emit(hdr.vlan);
      	packet.emit(hdr.inner_eth);

    }
}


control verifyChecksum(inout  vxlan_hdr_t hdr, inout vxlan_meta_t meta) {
    apply {
    }
}

control computeChecksum(inout  vxlan_hdr_t hdr, inout vxlan_meta_t meta) {
    apply {
    }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;
