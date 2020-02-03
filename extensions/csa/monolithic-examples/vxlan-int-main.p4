/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */
#include <core.p4>
#include <v1model.p4>

#define MAC_TABLE_SIZE 32
#define VNI 1000
#define SWITCH_ID 0x6789
#define INGRESS_PORT 0x0010

struct vxlan_int_meta_t { 
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


header udp_h {
  bit<16> sport; 
  bit<16> dport; 
  bit<16> len;
  bit<16> checksum;
}


header vxlan_main_h {
	bit<5> unused1;
	bit<1> p;
	bit<2> unused2;
	bit<16> reserved1;
}

header vxlan_gpe_h {
	bit<8> next_protocol;
	bit<24> vni;
	bit<8> reserved2;
}

header int_shim_h {
	bit<8> type;
	bit<8> reserved; 
	bit<8> length;
	bit<8> next_protocol;
}

header int_h{
	bit<2> ver;
	bit<2> rep;
	bit<1> c;
	bit<1> e;
	bit<5> r;
	bit<5> inst_cnt;
	bit<8> max_hop_cnt;
	bit<8> total_hop_cnt;
	bit<16> instr;
	bit<16> reserved;
}

header switch_id_h{
	bit<1> bos;
	bit<31> switch_id;
}

header ingress_port_h{
	bit<1> bos;
	bit<31> ingress;
}


struct vxlan_int_hdr_t {
	eth_h eth;
	ipv4_h ipv4;
	udp_h udp;
	vxlan_main_h vxlan_main;
	vxlan_gpe_h vxlan_gpe;
	int_shim_h int_shim;
	int_h int_main;
	switch_id_h switch_id0;
	ingress_port_h ingress_port0;
	switch_id_h switch_id1;
	ingress_port_h ingress_port1;
	switch_id_h switch_id2;
	ingress_port_h ingress_port2;
	switch_id_h switch_id3;
	ingress_port_h ingress_port3;
}

parser ParserImpl (packet_in pin, out vxlan_int_hdr_t parsed_hdr, 
                inout vxlan_int_meta_t meta, 
                inout standard_metadata_t standard_metadata) {
 	state start {
	   meta.if_index = (bit<8>)standard_metadata.ingress_port;
      transition parse_ethernet;
    }
    
    state parse_ethernet {
      pin.extract(parsed_hdr.eth);
      transition select(parsed_hdr.eth.ethType){
        0x8000: parse_ip;
        _: accept;
      }
    }
    
    state parse_ip{
    	pin.extract(parsed_hdr.ipv4);
    	transition select(parsed_hdr.ipv4.protocol){
    		0x11: parse_udp;
    		_: accept;
    	}
    }
    
    state parse_udp{
    	pin.extract(parsed_hdr.udp);
    	transition select(parsed_hdr.udp.dport){
    		4789: parse_vxlan;
    		_: accept;
    	}
    }
    
    state parse_vxlan{
    	pin.extract(parsed_hdr.vxlan_main);
	    transition select(parsed_hdr.vxlan_main.p){
	    	1: parse_vxlan_gpe;
	    	_: accept;
	    }
    }
    
    state parse_vxlan_gpe{
    	pin.extract(parsed_hdr.vxlan_gpe);
    	transition select(parsed_hdr.vxlan_gpe.next_protocol){
    		0x05: parse_int_shim;
    		_: accept;
    	}
    } 
    
    state parse_int_shim {
    	pin.extract(parsed_hdr.int_shim);
    	transition select(parsed_hdr.int_shim.length){
    		8w04: parse_int;
    		8w05: parse_int;
    		8w06: parse_int;
    		8w07: parse_int;
    		_: accept;
    	}
    }
    
    state parse_int {
    	pin.extract(parsed_hdr.int_main);
    	transition select(parsed_hdr.int_main.instr){
    		0xC0000000: parse_switch_ingress0;
    		_: accept;
    	}
    }
    state parse_switch_ingress0 {
    	pin.extract(parsed_hdr.switch_id0);
    	pin.extract(parsed_hdr.ingress_port0);
    	transition select(parsed_hdr.int_shim.length){
    		8w05: parse_switch_ingress1;
    		8w06: parse_switch_ingress1;
    		8w07: parse_switch_ingress1;
    		_: accept;
    	}
    }
    state parse_switch_ingress1 {
    	pin.extract(parsed_hdr.switch_id1);
    	pin.extract(parsed_hdr.ingress_port1);
    	transition select(parsed_hdr.int_shim.length){
    		8w06: parse_switch_ingress2;
    		8w07: parse_switch_ingress2;
    		_: accept;
    	}
    }
    
    state parse_switch_ingress2 {
    	pin.extract(parsed_hdr.switch_id2);
    	pin.extract(parsed_hdr.ingress_port2);
    	transition select(parsed_hdr.int_shim.length){
    		8w07: parse_switch_ingress3;
    		_: accept;
    	}
    }
    state parse_switch_ingress3 {
    	pin.extract(parsed_hdr.switch_id3);
    	pin.extract(parsed_hdr.ingress_port3);
    	transition accept;
    }
  
}

control egress(inout vxlan_int_hdr_t parsed_hdr, inout vxlan_int_meta_t meta,
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
    
control ingress(inout vxlan_int_hdr_t parsed_hdr, inout vxlan_int_meta_t meta,
                 inout standard_metadata_t standard_metadata) {	
      action set_dmac(bit<48> dmac, bit<9> port) {
          // P4Runtime error...
            standard_metadata.egress_port = port;
            parsed_hdr.eth.dmac = dmac;
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
            parsed_hdr.eth.smac = smac;
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
	        parsed_hdr.eth.dmac : exact; 
	        standard_metadata.ingress_port :ternary @name("ingress_port");
	      } 
	      actions = { 
	        send_to();
	      }
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
    
    action set_int(){
		parsed_hdr.vxlan_gpe.setValid();
		parsed_hdr.vxlan_gpe.next_protocol = 0x05;
		parsed_hdr.vxlan_gpe.vni = VNI;
		parsed_hdr.int_shim.setValid();
		parsed_hdr.int_shim.type = 2; //hop by hop type
		parsed_hdr.int_shim.length = 4;
		parsed_hdr.int_shim.next_protocol = 0x05;
		parsed_hdr.int_main.setValid();
		parsed_hdr.int_main.ver = 0;
		parsed_hdr.int_main.rep = 0;
		parsed_hdr.int_main.c = 0;
		parsed_hdr.int_main.e = 0;
		parsed_hdr.int_main.r = 0;
		parsed_hdr.int_main.inst_cnt = 2;
		parsed_hdr.int_main.max_hop_cnt = 2;
		parsed_hdr.int_main.total_hop_cnt = 0;
		parsed_hdr.int_main.instr = 0xc000;
		parsed_hdr.int_main.reserved = 0;
		parsed_hdr.switch_id1.setValid();
		parsed_hdr.switch_id1.bos = 1;
		parsed_hdr.switch_id1.switch_id = SWITCH_ID;
		parsed_hdr.ingress_port1.setValid();
		parsed_hdr.ingress_port1.bos = 1; 
		parsed_hdr.ingress_port1.ingress = INGRESS_PORT;
	}
	
	action process(){
		parsed_hdr.int_main.total_hop_cnt  = parsed_hdr.int_main.total_hop_cnt + 1;
		parsed_hdr.switch_id1.bos = 0;
		parsed_hdr.switch_id2.setValid();
		parsed_hdr.switch_id2.bos = 1;
		parsed_hdr.switch_id2.switch_id = SWITCH_ID;
		parsed_hdr.ingress_port1.bos = 0; 
		parsed_hdr.ingress_port2.setValid();
		parsed_hdr.ingress_port2.bos = 1;
		parsed_hdr.ingress_port2.ingress = INGRESS_PORT; 
	}
	
	table src_int{
		key = {
			parsed_hdr.vxlan_main.p: exact;
			parsed_hdr.int_main.instr: ternary;
			}
		actions = {
			set_int;
			process;
		}
		const entries = {
			(0, _): set_int();
			(1, 0xC000): process();
		}
		
	}
    
  	apply{
	 	  meta.next_hop = 16w0;
		  if (parsed_hdr.eth.ethType == 0x0800)
	        ipv4_lpm_tbl.apply(); 
	      if (parsed_hdr.udp.dport == 4789)
	     	src_int.apply();
		 dmac.apply(); 
	     smac.apply();
	}
}

control DeparserImpl(packet_out packet, in  vxlan_int_hdr_t hdr) {
    apply {
			packet.emit(hdr.eth);
			packet.emit(hdr.ipv4); 
			packet.emit(hdr.udp);
			packet.emit(hdr.vxlan_main);
			packet.emit(hdr.vxlan_gpe);
			packet.emit(hdr.int_shim);
			packet.emit(hdr.int_main); 
    }
}


control verifyChecksum(inout  vxlan_int_hdr_t hdr, inout vxlan_int_meta_t meta) {
    apply {
    }
}

control computeChecksum(inout  vxlan_int_hdr_t hdr, inout vxlan_int_meta_t meta) {
    apply {
    }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;
