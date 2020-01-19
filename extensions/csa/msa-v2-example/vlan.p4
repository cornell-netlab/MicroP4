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
  /*
  bit<3> pcp;
  bit<1> dei;
  bit<12> vid;
  */
  bit<16> tci;
  bit<16> ethType;
}

struct vlan_hdr_t {
  vlan_h vlan;
}

cpackage Vlan : implements Unicast<vlan_hdr_t, vlan_meta_t, 
                                     vlan_in_t, empty_t, bit<16>> {

  parser micro_parser(extractor ex, pkt p, im_t im, out vlan_hdr_t hdr, inout vlan_meta_t meta,
                        in empty_t ia, inout bit<16> ethType) {
    state start {
    transition select(ethType){
        0x8100: parse_vlan;
        transition accept;
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
      im.drop();
    }
       
    table identify_vlan {
    	key = {
    		im.in_port() : exact;
    	}
      actions = {
        untagged_port_to_vlan(bit<16> tci);
      }
    }

    table validate_tagged_ports_vlan {
    	key = {
    		im.in_port() : exact;
    		hdr.vlan.vid : exact;
    	}
      actions = {
        tag_port;
      }
    }


    apply {
    }
  }
  
  control micro_deparser(emitter em, pkt p, in vlan_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.vlan);
    }
  }
}

