/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024
#define VNI 1000
#define SWITCH_ID 0x6789
#define INGRESS_PORT 0x0010

struct vxlan_int_meta_t {

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



cpackage INT : implements Unicast<vxlan_int_hdr_t, vxlan_int_meta_t, 
                                     empty_t, empty_t, empty_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out vxlan_int_hdr_t hdr, inout vxlan_int_meta_t meta,
                        in empty_t ia, inout empty_t ioa) {
                        
    state start {
	    ex.extract(p, hdr.vxlan_main);
	    transition select(hdr.vxlan_main.p){
	    	1: parse_vxlan_gpe;
	    }
    }
    
    state parse_vxlan_gpe{
    	ex.extract(p, hdr.vxlan_gpe);
    	transition select(hdr.vxlan_gpe.next_protocol){
    		0x05: parse_int_shim;
    	}
    } 
    
    state parse_int_shim {
    	ex.extract(p, hdr.int_shim);
    	transition select(hdr.int_shim.length){
    		8w04: parse_int;
    		8w05: parse_int;
    		8w06: parse_int;
    		8w07: parse_int;
    	}
    }
    
    state parse_int {
    	ex.extract(p, hdr.int_main);
    	transition select(hdr.int_main.instr){
    		0xC0000000: parse_switch_ingress0;
    	}
    }
    state parse_switch_ingress0 {
    	ex.extract(p, hdr.switch_id0);
    	ex.extract(p, hdr.ingress_port0);
    	transition select(hdr.int_shim.length){
    		8w05: parse_switch_ingress1;
    		8w06: parse_switch_ingress1;
    		8w07: parse_switch_ingress1;
    	}
    }
    state parse_switch_ingress1 {
    	ex.extract(p, hdr.switch_id1);
    	ex.extract(p, hdr.ingress_port1);
    	transition select(hdr.int_shim.length){
    		8w06: parse_switch_ingress2;
    		8w07: parse_switch_ingress2;
    	}
    }
    
    state parse_switch_ingress2 {
    	ex.extract(p, hdr.switch_id2);
    	ex.extract(p, hdr.ingress_port2);
    	transition select(hdr.int_shim.length){
    		8w07: parse_switch_ingress3;
    	}
    }
    state parse_switch_ingress3 {
    	ex.extract(p, hdr.switch_id3);
    	ex.extract(p, hdr.ingress_port3);
    	transition accept;
    }
  }
  
  
  control micro_control(pkt p, im_t im, inout vxlan_int_hdr_t hdr, inout vxlan_int_meta_t m,
                          in empty_t ia, out empty_t oa, inout empty_t ioa) {
	
	action set_int(){
		hdr.vxlan_gpe.setValid();
		hdr.vxlan_gpe.next_protocol = 0x05;
		hdr.vxlan_gpe.vni = VNI;
		hdr.int_shim.setValid();
		hdr.int_shim.type = 2; //hop by hop type
		hdr.int_shim.length = 4;
		hdr.int_shim.next_protocol = 0x05;
		hdr.int_main.setValid();
		hdr.int_main.ver = 0;
		hdr.int_main.rep = 0;
		hdr.int_main.c = 0;
		hdr.int_main.e = 0;
		hdr.int_main.r = 0;
		hdr.int_main.inst_cnt = 2;
		hdr.int_main.max_hop_cnt = 2;
		hdr.int_main.total_hop_cnt = 0;
		hdr.int_main.instr = 0xc000;
		hdr.int_main.reserved = 0;
		hdr.switch_id1.setValid();
		hdr.switch_id1.bos = 1;
		hdr.switch_id1.switch_id = SWITCH_ID;
		hdr.ingress_port1.setValid();
		hdr.ingress_port1.bos = 1; 
		hdr.ingress_port1.ingress = INGRESS_PORT;
	}
	
	action process(){
		hdr.int_main.total_hop_cnt  = hdr.int_main.total_hop_cnt + 1;
		hdr.switch_id1.bos = 0;
		hdr.switch_id2.setValid();
		hdr.switch_id2.bos = 1;
		hdr.switch_id2.switch_id = SWITCH_ID;
		hdr.ingress_port1.bos = 0; 
		hdr.ingress_port2.setValid();
		hdr.ingress_port2.bos = 1;
		hdr.ingress_port2.ingress = INGRESS_PORT; 
	}
	
	table src_int{
		key = {
			hdr.vxlan_main.p: exact;
			hdr.int_main.instr: exact;
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

    apply {
    	src_int.apply();
    }
  }
  control micro_deparser(emitter em, pkt p, in vxlan_int_hdr_t hdr) {
    apply {
    	em.emit(p, hdr.vxlan_main);
    	em.emit(p, hdr.vxlan_gpe);
    	em.emit(p, hdr.int_shim);
    	em.emit(p, hdr.int_main); 
    }
  }
}

