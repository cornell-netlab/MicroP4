/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

struct meta_t { }

header ethernet_h {
  bit<48> dmac;
  bit<48> smac;
  bit<16> ethType; 
}

struct main_hdr_t {
  ethernet_h eth;
}

cpackage ModularNat : implements Unicast<main_hdr_t, meta_t, 
                                            empty_t, empty_t, empty_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out main_hdr_t hdr, inout meta_t meta,
                        in empty_t ia, inout empty_t ioa) {
    state start {
      ex.extract(p, hdr.eth);
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout main_hdr_t hdr, inout meta_t m,
                          in empty_t ia, out empty_t oa, inout empty_t ioa) {
    bit<16> nh;
    Nat_L3() nat3_i;
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
    	if (hdr.eth.ethType==0x0800)
      		nat3_i.apply(p, im, ia, oa, hdr.eth.ethType);
      forward_tbl.apply(); 
    }
  }

  control micro_deparser(emitter em, pkt p, in main_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.eth); 
    }
  }
}

ModularNat() main;


 
