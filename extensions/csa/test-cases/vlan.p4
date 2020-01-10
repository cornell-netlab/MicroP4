/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common-vlan.p4"

#define TABLE_SIZE 1024


header vlan_h {
//  bit<16> tpid;
  bit<3> pcp;
  bit<1> dei;
  bit<12> vid;
  bit<16> ethType;
}

struct vlan_hdr_t {
  vlan_h vlan0;
  vlan_h vlan1;
  vlan_h vlan2;
}


cpackage Vlan : implements Unicast<vlan_hdr_t, empty_t, 
                                     empty_t, empty_t, bit<16>> {
  parser micro_parser(extractor ex, pkt p, im_t im, out vlan_hdr_t hdr, inout empty_t meta,
                        in empty_t ia, inout bit<16> ethType) {
    state start {
    transition select(ethType){
        0x8100: parse_vlan;
      }
    }
    state parse_vlan{
      ex.extract(p, hdr.vlan0);
      transition accept;
    }
  }
  
control micro_control(pkt p, im_t im, inout vlan_hdr_t hdr, inout empty_t m,
                          in empty_t ia, out empty_t oa, inout bit<16> ethType) {
    
    action drop_action() {
            im.drop(); // Drop packet
       }
       
    action forward_action( PortId_t port) {
            im.set_out_port(port); 
       }
    action modify_action() {
           hdr.vlan0.pcp = 3;
		    hdr.vlan1.setValid();
		    hdr.vlan2.setValid();

       }
    action untag_vlan() {
		    ethType = hdr.vlan0.ethType;
		    hdr.vlan0.setInvalid();
		    im.set_out_port(0x15); 
    }
    table vlan_tbl{
    	key = {
    		hdr.vlan0.dei : exact;
    		hdr.vlan0.vid : exact;
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
      em.emit(p, hdr.vlan0);
      em.emit(p, hdr.vlan1);
      em.emit(p, hdr.vlan2);
    }
  }
}


