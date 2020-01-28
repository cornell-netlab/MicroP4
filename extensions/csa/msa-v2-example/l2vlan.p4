/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024



struct l2vlan_hdr_t{}

cpackage L2Vlan : implements Unicast<l2vlan_hdr_t, empty_t, 
                                     empty_t, empty_t, vlan_inout_t> {

  parser micro_parser(extractor ex, pkt p, im_t im, out l2vlan_hdr_t hdr, inout empty_t meta,
                        in empty_t ia, inout vlan_inout_t ethInfo) {
    state start {
      	transition accept;
    }
  }
  
  control micro_control(pkt p, im_t im, inout l2vlan_hdr_t hdr, inout empty_t m,
                        in empty_t ia, out empty_t oa, inout vlan_inout_t ethInfo) {
	VlanID() vlanid;
	                        
    action drop_action() {
      im.drop();
    }
    
	
	table drop_table {
	  key = {}
	  actions = {drop_action;}
	  default_action = drop_action;
	}
	
	
	action send_to(PortId_t port) {
      im.set_out_port(port);
    }
    table switch_tbl {
      key = { 
        ethInfo.dstAddr : exact; 
        im.get_in_port() :ternary @name("ingress_port");
      } 
      actions = { 
        send_to;
      }
      const entries = {
      	(0x0045090abc103, 5): send_to(6);
      }
    }

    apply {
           switch_tbl.apply();
           vlanid.apply(p, im, ia, oa, ethInfo);
           if (ethInfo.invlan != ethInfo.outvlan)
             drop_table.apply();
   	 }
  }
  
  control micro_deparser(emitter em, pkt p, in l2vlan_hdr_t hdr) {
    apply { 
    }
  }
}

