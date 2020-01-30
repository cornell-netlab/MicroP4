/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"


header ethernet_h {
  bit<48> dmac;
  bit<48> smac;
  bit<16> ethType; 
}

struct hdr_t {
  ethernet_h eth;
}

cpackage ModularVXlan: implements Unicast<hdr_t, empty_t, 
                                            empty_t, empty_t, empty_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out hdr_t hdr, inout empty_t m,
                        in empty_t ia, inout empty_t ioa) {
    state start {
      ex.extract(p, hdr.eth);
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout hdr_t hdr, inout empty_t m,
                          in empty_t ia, out empty_t oa, inout empty_t ioa) {
    VXlan() vxlan;
    IPv4() ipv4_i;
    IPv6() ipv6_i;
    vxlan_inout_t vxlan_meta;
    bit<16> nh;
    action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
      hdr.eth.dmac = dmac;
      hdr.eth.smac = smac;
      im.set_out_port(port);
    }
    table forward_tbl {
      key = { nh : exact; } 
      actions = { forward; }
    }
    
    
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
     	nh = 16w10;
     	vxlan_meta.dmac = hdr.eth.dmac;
      	vxlan_meta.smac = hdr.eth.smac;
      	vxlan_meta.ethType = hdr.eth.ethType;
      	
	    vxlan.apply(p, im, ia, oa, vxlan_meta);
	    
	    hdr.eth.ethType = vxlan_meta.ethType;
	    hdr.eth.dmac = vxlan_meta.smac;
	    hdr.eth.smac = vxlan_meta.dmac;
	    
	    if (hdr.eth.ethType == 0x0800)
        	ipv4_i.apply(p, im, ia, nh, ioa);
      	else if (hdr.eth.ethType == 0x86DD)
        	ipv6_i.apply(p, im, ia, nh, ioa);
        if (nh == 16w0)
        	switch_tbl.apply();
	    forward_tbl.apply(); 
    }
  }

  control micro_deparser(emitter em, pkt p, in hdr_t hdr) {
    apply { 
      em.emit(p, hdr.eth); 
    }
  }
}

ModularVXlan() main;


 
