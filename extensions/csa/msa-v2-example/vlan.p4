/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024

struct vlan_meta_t{
bit<16> ethType;
}
header vlan_h {
  bit<16> tci;
  bit<16> ethType;
}

struct vlan_hdr_t {
  vlan_h vlan;
}

cpackage Vlan : implements Unicast<vlan_hdr_t, vlan_meta_t, 
                                     empty_t, empty_t, vlan_inout_t> {

  parser micro_parser(extractor ex, pkt p, im_t im, out vlan_hdr_t hdr, inout vlan_meta_t meta,
                        in empty_t ia, inout vlan_inout_t ethInfo) {
    state start {
    meta.ethType = ethInfo.ethType;
    transition select(ethInfo.ethType){
        0x8100: parse_vlan;
      }
    }
    
    state parse_vlan{
      ex.extract(p, hdr.vlan);
      ethInfo.invlan = hdr.vlan.tci;
      meta.ethType = hdr.vlan.ethType;
      transition accept;
    }
  }
  
  control micro_control(pkt p, im_t im, inout vlan_hdr_t hdr, inout vlan_meta_t m,
                        in empty_t ia, out empty_t oa, inout vlan_inout_t ethInfo) {
    IPv4() l3v4_i;
    IPv6() l3v6_i; 
    L2Vlan() l2vlan;
    L3Vlan() l3vlan;

    bit<16> nh;
    bit<1> is_l3_int;
    empty_t e;

                        
    action drop_action() {
      im.drop();
    }
    
    action vlan_tag(bit<16> tci) {
    	hdr.vlan.setValid();
    	hdr.vlan.tci = tci;
    	hdr.vlan.ethType = ethInfo.ethType;
    	ethInfo.ethType = 0x8100;
    }
    
    action vlan_untag() {
    	hdr.vlan.setInvalid();
    	ethInfo.ethType = hdr.vlan.ethType;
    }
    
   table configure_outvlan {
	  key = {
		im.get_out_port() : exact @name("egress_port");
		im.get_in_port() : exact @name("ingress_port");
  	  }
      actions = {
        vlan_tag;
        vlan_untag;
        drop_action;
      }
      const entries = {
      	(3,4): vlan_tag(21); // from access ports to trunk
      	(4,3): vlan_untag(); // from trunk ports to access 
      	(3,5): drop_action(); // no l3 routing  configured between in and out ports   
      }
    }
	
	table drop_table {
	  key = {}
	  actions = {drop_action;}
	  default_action = drop_action;
	}

    apply {
  		nh = 16w0;
  		
		if (m.ethType==0x0800)
  		    l3v4_i.apply(p, im, ia, nh, e);
    	else if (m.ethType==0x86DD) 
      		l3v6_i.apply(p, im, ia, nh, e);
      	
      	if (nh == 16w0)
           l2vlan.apply(p, im, ia, oa, ethInfo);
		else
           l3vlan.apply(p, im, ia, oa, ethInfo);
        
        configure_outvlan.apply();
   	 }
  }
  
  control micro_deparser(emitter em, pkt p, in vlan_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.vlan);
    }
  }
}

