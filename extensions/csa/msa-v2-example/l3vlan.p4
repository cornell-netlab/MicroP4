/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024


struct l3vlan_hdr_t{}

cpackage L3Vlan : implements Unicast<l3vlan_hdr_t, empty_t, 
                                     empty_t, empty_t, vlan_inout_t> {

  parser micro_parser(extractor ex, pkt p, im_t im, out l3vlan_hdr_t hdr, inout  empty_t meta,
                        in empty_t ia, inout vlan_inout_t ethInfo) {
    state start {
      	transition accept;
    }
  }
  
  control micro_control(pkt p, im_t im, inout l3vlan_hdr_t hdr, inout empty_t m,
                        in empty_t ia, out empty_t oa, inout vlan_inout_t ethInfo) {
	VlanID() vlanid;
	bit<1> is_l3_int;
	action is_l3() {
		is_l3_int = 1;
	}
	
	table check_in_port_lvl {
 	  key = {
 	    im.get_in_port(): exact @name("ingress_port"); 
 	    
 	  }
 	  actions = {
 	    is_l3;
 	  }
 	  const entries = {
 	    (6) : is_l3();
 	  }
	}
	
	action set_ivr(bit<48> dstAddr){
		ethInfo.dstAddr = dstAddr; 
	}
	table set_vlan_ivr{
		key = {
			ethInfo.invlan: exact;
		}
		actions = {
			set_ivr;
		}
		const entries = {
			(3): set_ivr(0x0045090abc1a0);
		}
	}

    apply {
  		
           check_in_port_lvl.apply();
           if (is_l3_int == 1){
           		vlanid.apply(p, im, ia, oa, ethInfo);
           } else {
        		set_vlan_ivr.apply();
        }
   	 }
  }
  
  control micro_deparser(emitter em, pkt p, in l3vlan_hdr_t hdr) {
    apply { 
    }
  }
}

