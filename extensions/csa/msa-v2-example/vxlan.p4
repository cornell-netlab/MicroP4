/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024
#define VXLAN_TTL 128
#define VXLAN_UDP_DPORT 4789
#define LOCAL_VTEP_IN_MAC 0x000000000002
#define LOCAL_VTEP_OUT_MAC 0x000000000004
#define LOCAL_VTEP_IP 0x0a002036


header eth_h {
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
  ipv4_h outer_ipv4;
  udp_h outer_udp;
  vxlan_h vxlan;
  eth_h inner_eth;
  vlan_h vlan;
}


cpackage VXlan : implements Unicast<vxlan_hdr_t, empty_t, 
                                     empty_t, empty_t, vxlan_inout_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out vxlan_hdr_t hdr, inout empty_t meta,
                        in empty_t ia, inout vxlan_inout_t outer_ethhdr) {
    state start {
    transition select(outer_ethhdr.ethType){
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
    	ex.extract(p, hdr.outer_ipv4);
    	transition select(hdr.outer_ipv4.protocol){
    		0x11: parse_udp;
    	}
    }
    
    state parse_udp{
    	ex.extract(p, hdr.outer_udp);
    	transition select(hdr.outer_udp.dport){
    		4789: parse_vxlan;
    	}
    }
    
    state parse_vxlan{
    	ex.extract(p, hdr.vxlan);
		transition accept;
    }
  }
  
control micro_control(pkt p, im_t im, inout vxlan_hdr_t hdr, inout empty_t m,
                          in empty_t ia, out empty_t oa, inout vxlan_inout_t outer_ethhdr) {
       
    action encap( bit<32> vtep_dst_ip, bit<24> vni, bit<16> sport) {
    	  
    	   hdr.vlan.setInvalid();
    	   hdr.inner_eth.setValid();
    	   hdr.inner_eth.dmac = outer_ethhdr.dmac;
    	   hdr.inner_eth.smac = outer_ethhdr.smac;
    	   hdr.inner_eth.ethType = hdr.vlan.ethType;
           hdr.vxlan.setValid();
           hdr.vxlan.flags = 1;
           hdr.vxlan.reserved1 = 0;
           hdr.vxlan.vni = vni ;
           hdr.vxlan.reserved2 = 0;
           hdr.outer_udp.setValid();
           hdr.outer_udp.sport = sport;
           hdr.outer_udp.dport = VXLAN_UDP_DPORT;
           hdr.outer_udp.len =  0 ; // to set correctly
           hdr.outer_udp.checksum = 0;
           hdr.outer_ipv4.setValid();
           hdr.outer_ipv4.version = 4;
  		   hdr.outer_ipv4.ihl = 5; // to set correctly
		   hdr.outer_ipv4.diffserv = 3 ; 
		   hdr.outer_ipv4.totalLen = 54; // to set correctly
		   hdr.outer_ipv4.identification = 34; // to set correctly
		   hdr.outer_ipv4.flags = 1; 
		   hdr.outer_ipv4.fragOffset = 00; 
		   hdr.outer_ipv4.ttl = VXLAN_TTL;
  		   hdr.outer_ipv4.protocol = 0x11;
  		   hdr.outer_ipv4.hdrChecksum = 0; 
  		   
  		   hdr.outer_ipv4.srcAddr = LOCAL_VTEP_IP;
  		   hdr.outer_ipv4.dstAddr = vtep_dst_ip; 

           outer_ethhdr.smac = LOCAL_VTEP_OUT_MAC; 
           outer_ethhdr.ethType = hdr.vlan.ethType; 
           
       }
   table vxlan_encap_tbl{
    	key = {
    		outer_ethhdr.dmac : exact;
    		hdr.vlan.vid: exact; 
    	}
    	actions = {
    		encap;
    	}
    	const entries = {
    	     (0x000000000002, 100): encap(0x0a000206, 1000, 49152);
       	}
    }
    
    action decap(bit<12> vid) {
    	outer_ethhdr.ethType = 0x8100;
		outer_ethhdr.dmac = hdr.inner_eth.dmac;
    	outer_ethhdr.smac = hdr.inner_eth.smac;
	    hdr.vxlan.setInvalid();
	    hdr.outer_udp.setInvalid();
	    hdr.outer_ipv4.setInvalid();
	    hdr.inner_eth.setInvalid();
	    hdr.vlan.setValid();
	    hdr.vlan.pcp = 3;
	    hdr.vlan.dei = 0;
	    hdr.vlan.vid = vid;
	    hdr.vlan.ethType = hdr.inner_eth.ethType;
    }
 
    
     table vxlan_decap_tbl{
    	key = {
    		outer_ethhdr.dmac : exact;
    		hdr.vxlan.vni: exact; 
    	}
    	actions = {
    		decap;
    	}
    	const entries = {
    	     (LOCAL_VTEP_IN_MAC, 864): decap(100);
       	}
    }
    apply {
    	if(hdr.vxlan.isValid())
      		vxlan_decap_tbl.apply();
      	else 
      		vxlan_encap_tbl.apply(); 
    }
  }
  
  control micro_deparser(emitter em, pkt p, in vxlan_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.vxlan);
      em.emit(p, hdr.outer_udp);
      em.emit(p, hdr.outer_ipv4);
      em.emit(p, hdr.vlan);
      em.emit(p, hdr.inner_eth);
    }
  }
}

