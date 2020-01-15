/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024
#define VXLAN_TTL 128
#define VXLAN_VLAN_ID 20
#define VXLAN_VNI  24w2020
#define LOCAL_VTEP_MAC 0x000000000002

struct vxlan_meta_t {
	bit<16> ethType;
}


header ethernet_h {
  bit<48> dmac;
  bit<48> smac;
  bit<16> ethType; 
}

header vlan_h {
  bit<3> pcp;
  bit<1> dei;
  bit<12> vid;
  bit<16> ethType;
}

header ipv4_h {
  bit<4> version;
  bit<4> ihl;
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
  vxlan_h vxlan;
  udp_h udp;
  ipv4_h ipv4;
  vlan_h vlan;
  eth_h eth;
}


cpackage VXlan : implements Unicast<vxlan_hdr_t, vxlan_meta_t, 
                                     empty_t, empty_t, eth_meta_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out vxlan_hdr_t hdr, inout vxlan_meta_t meta,
                        in empty_t ia, inout eth_meta_t ethhdr) {
    state start {
    transition select(ethhdr.ethType){
        0x8100: parse_vlan;
      }
    }
    state parse_vlan{
      ex.extract(p, hdr.vlan);
      transition select(hdr.vlan.ethType){
      	0x0800: parse_ip;
      }
    }
    
    state parse_ip{
    	ex.extract(p, hdr.ipv4);
    	transition select(hdr.ipv4.protocol){
    		0x11: parse_udp;
    	}
    }
    
    state parse_udp{
    	ex.extract(p, hdr.udp);
    	transition select(hdr.udp.dport){
    		4789: parse_vxlan;
    	}
    }
    
    state parse_vxlan{
    	ex.extract(p, hdr.vxlan);
		transition accept;
    }
  }
  
control micro_control(pkt p, im_t im, inout vxlan_hdr_t hdr, inout vxlan_meta_t m,
                          in empty_t ia, out empty_t oa, inout eth_meta_t ethhdr) {
    
    action drop_action() {
            im.drop(); // Drop packet
       }
       
    action forward_action( PortId_t port) {
            im.set_out_port(port); 
       }
    action encap(bit<32> vtep_src_ip, bit<32> vtep_dst_ip, bit<48> vtep_src_mac, bit<48> vtep_dst_mac ) {
    	   //copy eth information 
    	   hdr.eth.dmac = ethhdr.dmac;
    	   hdr.eth.smac = ethhdr.smac;
    	   hdr.eth.ethType = ethhdr.ethType;
           hdr.vxlan.setValid();
           hdr.vxlan.flags = 1;
           hdr.vxlan.reserved1 = 0;
           hdr.vxlan.vni = VNI;
           hdr.vxlan.reserved2 = 0;
           hdr.udp.setValid();
           hdr.udp.sport = 49152;
           hdr.udp.dport = 4789;
           hdr.udp.len = inner_pkt_len + 54 ; // TODO get inner_pkt_len
           hdr.udp.checksum = 0;
           hdr.ipv4.setValid();
           hdr.ipv4.version = 4;
  		   hdr.ipv4.ihl = 5;
		   hdr.ipv4.diffserv = 3 ; 
		   hdr.ipv4.totalLen = ; //TODO
		   hdr.ipv4.identification = ; //TODO 
		   hdr.ipv4.flags = 1; 
		   hdr.ipv4.fragOffset = 00; 
		   hdr.ipv4.ttl = VXLAN_TTL;
  		   hdr.ipv4.protocol = 0x11;
  		   hdr.ipv4.hdrChecksum = ; //TODO
  		   hdr.srcAddr = vtep_src_ip;
  		   hdr.dstAddr = vtep_dst_ip; 
  		   hdr.vlan.setValid();
  		   hdr.vlan.pcp = 3;
  		   hdr.vlan.dei = 0;
  		   hdr.vlan.vid = VXLAN_VLAN_ID;
  		   hdr.vlan.ethType = 0x0800;
           hdr.eth.setValid();
           hdr.eth.dmac = vtep_dst_mac; 
           hdr.eth.smac = vtep_src_mac; 
           hdr.eth.ethType = 0x8100;
       }
    action decap() {
		    m.ethType = hdr.vlan.ethType;
		    hdr.vxlan.setInvalid();
		    hdr.udp.setInvalid();
		    hdr.ipv4.setInvalid();
		    hdr.eth.setInvalid();
		    im.set_out_port(0x15); 
    }
    table vxlan_tbl{
    	key = {
    		hdr.eth.dmac : exact;
    	}
    	actions = {
    		encap;
    		decap;
    		forward_action;
    		drop_action;
    	}
    	const entries = {
    	//TODO 
    	     (): drop_action();
    	     (): forward_action();
    	     (LOCAL_VTEP_MAC): decap();
    	     (0x000000000002): encap(0x0a002036, 0x0a000206 0x000000000004, 0x000000000005);
       	}
    }
    
    apply {
      vxlan_tbl.apply();
    }
  }
  
  control micro_deparser(emitter em, pkt p, in vxlan_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.vxlan);
      em.emit(p, hdr.udp);
      em.emit(p, hdr.ipv4);
      em.emit(p, hdr.vlan);
      em.emit(p, hdr.eth);
    }
  }
}

