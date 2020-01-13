/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024

struct vlan_meta_t {
	bit<16> ethType;
}

header vlan_h {
  bit<3> pcp;
  bit<1> dei;
  bit<12> vid;
  bit<16> ethType;
}

struct vlan_hdr_t {
  vlan_h vlan;
}


cpackage Vlan : implements Unicast<vlan_hdr_t, vlan_meta_t, 
                                     empty_t, empty_t, bit<16>> {
  parser micro_parser(extractor ex, pkt p, im_t im, out vlan_hdr_t hdr, inout vlan_meta_t meta,
                        in empty_t ia, inout bit<16> ethType) {
    state start {
    transition select(ethType){
        0x8100: parse_vlan;
      }
    }
    state parse_vlan{
      ex.extract(p, hdr.vlan);
      transition accept;
    }
  }
  
control micro_control(pkt p, im_t im, inout vlan_hdr_t hdr, inout vlan_meta_t m,
                          in empty_t ia, out empty_t oa, inout bit<16> ethType) {
    
    action drop_action() {
            im.drop(); // Drop packet
       }
       
    action forward_action( PortId_t port) {
            im.set_out_port(port); // Drop packet
       }
    action modify_action() {
           hdr.vlan.pcp = 3;
       }
    action untag_vlan() {
		    m.ethType = hdr.vlan.ethType;
		    hdr.vlan.setInvalid();
		    im.set_out_port(0x15); 
    }
    table vlan_tbl{
    	key = {
    		hdr.vlan.dei : exact;
    		hdr.vlan.vid : exact;
    	}
    	actions = {
    		modify_action;
    		untag_vlan;
    		forward_action;
    		drop_action;
    	}
    	const entries = {
    	     (1, _): drop_action();
    	     (0, 20): modify_action();
    	     (0,25): untag_vlan();
    	     (0,30): forward_action(0x10);
       	}
    }
    
    apply {
      vlan_tbl.apply();
    }
  }
  
  control micro_deparser(emitter em, pkt p, in vlan_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.vlan);
    }
  }
}

