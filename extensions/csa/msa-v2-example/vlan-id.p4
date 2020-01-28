/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024

struct vlanid_meta_t {
}

struct vlanid_hdr_t{}

cpackage VlanID : implements Unicast<vlanid_hdr_t, empty_t, 
                                     empty_t, empty_t, vlan_inout_t> {

  parser micro_parser(extractor ex, pkt p, im_t im, out vlanid_hdr_t hdr, inout vlanid_meta_t meta,
                        in empty_t ia, inout vlan_inout_t ethInfo) {
    state start {
      	transition accept;
    }
  }
  
  control micro_control(pkt p, im_t im, inout vlanid_hdr_t hdr, inout vlanid_meta_t m,
                        in empty_t ia, out empty_t oa, inout vlan_inout_t vlanInfo) {
                        
    
    action set_invlan(bit<16> tci) {
    	vlanInfo.invlan = tci;
    }
    
    table identify_invlan {
	  key = {
		im.get_in_port() : exact @name("ingress_port");
  	  }
      actions = {
        set_invlan;
      }
      const entries = {
      	(3): set_invlan(20); // from access ports
      }
    }
  
    action set_outvlan(bit<16> tci) {
    	vlanInfo.outvlan = tci;
    }
 	table identify_outvlan {
	  key = {
		im.get_out_port() : exact @name("egress_port");
  	  }
      actions = {
        set_outvlan;
      }
      const entries = {
      	(4): set_outvlan(20); 
      }
    }
    apply {
           identify_invlan.apply();
           identify_outvlan.apply();
     }
  }
  
  control micro_deparser(emitter em, pkt p, in vlanid_hdr_t hdr) {
    apply { 
    }
  }
}

