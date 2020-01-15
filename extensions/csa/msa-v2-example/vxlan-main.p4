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

cpackage ModularVXlan: implements Unicast<hdr_t, meta_t, 
                                            empty_t, empty_t, eth_meta_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out hdr_t hdr, inout meta_t m,
                        in empty_t ia, inout eth_meta_t ioa) {
    state start {
      ex.extract(p, hdr.eth);
      m.dmac = hdr.eth.dmac;
      m.smac = hdr.eth.smac;
      m.ethType = hdr.eth.ethType;
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout hdr_t hdr, inout meta_t m,
                          in empty_t ia, out empty_t oa, inout eth_meta_t ioa) {
    VXlan() vxlan;
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
    apply { 
     	nh = 16w10;
	    vxlan.apply(p, im, ia, oa, ioa);
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


 
