/*
 * Author: Hardik Soni, Myriana Rifai
 * Email: hks57@cornell.edu, myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

struct meta_t { 
  bit<16> ethType; 
}

header ethernet_h {
  bit<48> dmac;
  bit<48> smac;
  bit<16> ethType; 
}
/*
header vlan_h {
  /*
  bit<3> pcp;
  bit<1> dei;
  bit<12> vid;
  
  bit<16> tci;
  bit<16> ethType;
}*/

struct hdr_t {
  ethernet_h eth;
//  vlan_h vlan;
}

cpackage MicroP4Switch : implements Unicast<hdr_t, meta_t, 
                                            empty_t, empty_t, empty_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out hdr_t hdr, inout meta_t m,
                        in empty_t ia, inout empty_t ioa) {
    state start {
      ex.extract(p, hdr.eth);
      transition accept;
    }
/*
    state start {
      ex.extract(p, hdr.eth);
      m.ethType = hdr.eth.ethType;
      transition select(hdr.eth.ethType){
        0x8100: parse_vlan;
        _ : accept;
      }
    }

    state parse_vlan{
      ex.extract(p, hdr.vlan);
      m.ethType = hdr.vlan.ethType;
      transition accept;
    }
*/
  }


  control micro_control(pkt p, im_t im, inout hdr_t hdr, inout meta_t m,
                          in empty_t ia, out empty_t oa, inout empty_t ioa) {
    L3() l3_i;
    l3_inout_t l3ioa;

    bit<16> vlan_tci;
    action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
      hdr.eth.dmac = dmac;
      hdr.eth.smac = smac;
      im.set_out_port(port);
    }
    table forward_tbl {
      key = { l3ioa.next_hop : exact; } 
      actions = { forward; }
    }

/*
    action untagged_port_to_vlan(bit<16> tci) {
      vlan_tci = tci;
    }
    table identify_vlan {
    	key = {
    		im.get_out_port() : exact;
    	}
      actions = {
        untagged_port_to_vlan(bit<16> tci);
      }
    }

    action tag_port() {
    }
    table validate_tagged_ports_vlan {
    	key = {
    		im.get_in_port() : exact;
    		hdr.vlan.vid : exact;
    	}
      actions = {
        tag_port;
      }
    }
    */


    action send_to(PortId_t port) {
      im.set_out_port(port);
    }
    table switch_tbl {
      key = { 
        hdr.eth.dmac : exact; 
        im.get_in_port() :ternary @name("ingress_port");
      } 
      actions = { 
        send_to();
      }
    }

    apply { 
      l3ioa.next_hop = 16w0;
      l3ioa.eth_type = m.ethType;
      l3ioa.acl.hard_drop = 1w0;
      l3ioa.acl.soft_drop = 1w0;
      if (l3ioa.eth_type == 0x0800) {
        l3_i.apply(p, im, ia, oa, l3ioa);
        if (l3ioa.acl.hard_drop == 1w0 && l3ioa.acl.soft_drop == 1w0)
          forward_tbl.apply(); 
        else if (l3ioa.next_hop == 16w0)
          switch_tbl.apply();
        else 
          im.drop();
      } 
      /*
      if (im.get_value(metadata_fields_t.QUEUE_DEPTH_AT_DEQUEUE) == (bit<32>)64) {
          im.drop();
      }
      */
    }
  }

  control micro_deparser(emitter em, pkt p, in hdr_t hdr) {
    apply { 
      em.emit(p, hdr.eth); 
   //   em.emit(p, hdr.vlan); 
    }
  }
}

MicroP4Switch() main;


 
