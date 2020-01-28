/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */
#include <core.p4>
#include <v1model.p4>

#define MAC_TABLE_SIZE 32
#define TABLE_SIZE 1024


header ethernet_h {
  bit<48> dmac;
  bit<48> smac;
  bit<16> ethType; 
}

header vlan_h {
  bit<16> tci;
  bit<16> ethType;
}


header ipv6_h {
  bit<4> version;
  bit<8> class;
  bit<20> label;
  // bit<32> ver_class_lbl;
  bit<16> totalLen;
  bit<8> nexthdr;
  bit<8> hoplimit;
  bit<128> srcAddr;
  bit<128> dstAddr;  
}


header ipv4_h {
  // bit<4> version;
  // bit<4> ihl;
  bit<8> ihl_version;
  bit<8> diffserv;
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

struct vlan_meta_t{
	bit<16> ethType;
	bit<16> invlan;
	bit<16> outvlan;
	bit<1> drop_flag;
}
struct vlan_hdr_t {
  ethernet_h eth;
  vlan_h vlan;
  ipv4_h ipv4;
  ipv6_h ipv6;
}


parser ParserImpl (packet_in pin, out vlan_hdr_t parsed_hdr, 
                inout vlan_meta_t meta, 
                inout standard_metadata_t standard_metadata) {
 state start {
      transition parse_ethernet;
    }
    
    state parse_ethernet {
      pin.extract(parsed_hdr.eth);
      meta.ethType = parsed_hdr.eth.ethType;
      transition select(parsed_hdr.eth.ethType){
	        0x8100: parse_vlan;
	        _: accept;
      }
     } 
      state parse_vlan{
	      pin.extract(parsed_hdr.vlan);
	      meta.ethType = parsed_hdr.vlan.ethType;
	      meta.invlan = parsed_hdr.vlan.tci;
	      meta.ethType = parsed_hdr.vlan.ethType;
	      transition select(parsed_hdr.vlan.ethType){
	      	0x0800: parse_ipv4;
	      	0x86DD: parse_ipv6;
	      	_: accept;
	      }
    }
    
    state parse_ipv6 {
      	pin.extract(parsed_hdr.ipv6);
      	transition accept;
    }
  
 	state parse_ipv4 {
      	pin.extract(parsed_hdr.ipv4);
      	transition accept;
    }
  
}

control egress(inout vlan_hdr_t parsed_hdr, inout vlan_meta_t meta,
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
    
control ingress(inout vlan_hdr_t parsed_hdr, inout vlan_meta_t meta,
                 inout standard_metadata_t standard_metadata) {	
    bit<16> nexthop;
    bit<1> is_l3_int;
    
    action forward(bit<48> dmac, bit<48> smac,  bit<9> port) {
      parsed_hdr.eth.dmac = dmac;
      parsed_hdr.eth.smac = smac;
      parsed_hdr.eth.ethType = meta.ethType;
	  standard_metadata.egress_port = port;
    }
    table forward_tbl {
      key = { nexthop : exact; } 
      actions = { forward; }
    }              
     
                        
    action drop_out_action() {
     meta.drop_flag = 1;
    }
    
    action vlan_tag(bit<16> tci) {
    	parsed_hdr.vlan.setValid();
    	parsed_hdr.vlan.tci = tci;
    	parsed_hdr.vlan.ethType = meta.ethType;
    	meta.ethType = 0x8100;
    }
    
    action vlan_untag() {
    	parsed_hdr.vlan.setInvalid();
    	meta.ethType = parsed_hdr.vlan.ethType;
    }
    
   table configure_outvlan {
	  key = {
		standard_metadata.egress_port : exact @name("egress_port");
		standard_metadata.ingress_port : exact @name("ingress_port");
  	  }
      actions = {
        vlan_tag;
        vlan_untag;
        drop_out_action;
      }
      const entries = {
      	(3,4): vlan_tag(21); // from access ports to trunk
      	(4,3): vlan_untag(); // from trunk ports to access 
      	(3,5): drop_out_action(); // no l3 routing  configured between in and out ports   
      }
    }
	
	table drop_out_table {
	  key = {}
	  actions = {drop_out_action;}
	  default_action = drop_out_action;
	}
    
    
     action processv4(bit<16> nh) {
      parsed_hdr.ipv4.ttl = parsed_hdr.ipv4.ttl - 1;
      nexthop = nh;  // setting out param
    }
    action default_act() {
      nexthop = 0; 
    }

    table ipv4_lpm_tbl {
      key = { 
        parsed_hdr.ipv4.dstAddr : lpm;
        parsed_hdr.ipv4.diffserv : ternary;
      } 
      actions = { 
        processv4; 
        default_act;
      }
      default_action = default_act;
    }
    
    action processv6(bit<16> nh){
      parsed_hdr.ipv6.hoplimit = parsed_hdr.ipv6.hoplimit - 1;
      nexthop = nh;
    }

    table ipv6_lpm_tbl {
      key = { 
        parsed_hdr.ipv6.dstAddr : lpm;
        parsed_hdr.ipv6.class : ternary;
        parsed_hdr.ipv6.label : ternary;
      } 
      actions = {
        processv6; 
        default_act;
      }
      default_action = default_act;
    }
	
	table drop_table {
	  key = {}
	  actions = {drop_out_action;}
	  default_action = drop_out_action;
	}
	
	
	action send_to(bit<9> port) {
      standard_metadata.egress_port = port;
    }
    table switch_tbl {
      key = { 
        parsed_hdr.eth.dmac : exact; 
        standard_metadata.ingress_port :ternary @name("ingress_port");
      } 
      actions = { 
        send_to;
      }
      const entries = {
      	(0x0045090abc103, 5): send_to(6);
      }
    }
    
    action is_l3() {
		is_l3_int = 1;
	}
	
	table check_in_port_lvl {
 	  key = {
 	    standard_metadata.ingress_port: exact @name("ingress_port"); 
 	    
 	  }
 	  actions = {
 	    is_l3;
 	  }
 	  const entries = {
 	    (6) : is_l3();
 	  }
	}
	
	action set_ivr(bit<48> dstAddr){
		parsed_hdr.eth.dmac = dstAddr; 
	}
	table set_vlan_ivr{
		key = {
			meta.invlan: exact;
		}
		actions = {
			set_ivr;
		}
		const entries = {
			(3): set_ivr(0x0045090abc1a0);
		}
	}
	
	  
    action set_invlan(bit<16> tci) {
    	meta.invlan = tci;
    }
    
    table identify_invlan {
	  key = {
		standard_metadata.ingress_port : exact @name("ingress_port");
  	  }
      actions = {
        set_invlan;
      }
      const entries = {
      	(3): set_invlan(20); // from access ports
      }
    }
  
    action set_outvlan(bit<16> tci) {
    	meta.outvlan = tci;
    }
 	table identify_outvlan {
	  key = {
		standard_metadata.egress_port : exact @name("egress_port");
  	  }
      actions = {
        set_outvlan;
      }
      const entries = {
      	(4): set_outvlan(20); 
      }
    }
	apply{

	    nexthop = 16w0;
  		
		if (meta.ethType==0x0800)
  		    ipv4_lpm_tbl.apply(); 
    	else if (meta.ethType==0x86DD) 
      		ipv6_lpm_tbl.apply(); 
      	
      	if (nexthop == 16w0){
      	   switch_tbl.apply();
           identify_invlan.apply();
           identify_outvlan.apply();
           if (meta.invlan != meta.outvlan)
             drop_out_table.apply();
		}else{
		 check_in_port_lvl.apply();
           if (is_l3_int == 1){
	           	identify_invlan.apply();
	            identify_outvlan.apply();	
           }else 
        		set_vlan_ivr.apply();
		}
        
        configure_outvlan.apply();
	    
	    forward_tbl.apply(); 
	    
	}
}

control DeparserImpl(packet_out packet, in  vlan_hdr_t hdr) {
    apply {
        packet.emit(hdr.eth);
        packet.emit(hdr.vlan); 
        packet.emit(hdr.ipv4);
        packet.emit(hdr.ipv6); 
    }
}


control verifyChecksum(inout  vlan_hdr_t hdr, inout vlan_meta_t meta) {
    apply {
    }
}

control computeChecksum(inout  vlan_hdr_t hdr, inout vlan_meta_t meta) {
    apply {
    }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;
