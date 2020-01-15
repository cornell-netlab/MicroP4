/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include"msa.p4"
#include"common.p4"

struct l3_meta_t { }


header ipv6_h {
  bit<4> version;
  bit<8> class;
  bit<20> label;
  bit<16> totalLen;
  bit<8> nexthdr;
  bit<8> hoplimit;
  bit<128> srcAddr;
  bit<128> dstAddr;  
}

struct l3v6_hdr_t {
  ipv6_h ipv6;
}

cpackage L3v6 : implements Unicast<l3v6_hdr_t, l3_meta_t, empty_t, bit<16>, empty_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out l3v6_hdr_t hdr, inout l3_meta_t meta,  
                        in empty_t ia, inout empty_t ioa) { //inout arg
    state start {
      ex.extract(p, hdr.ipv6);
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout l3v6_hdr_t hdr, inout l3_meta_t m,
                          in empty_t e, out bit<16> nexthop, 
                          inout empty_t ioa) { // nexthop out arg
	action process(bit<16> nh){
      hdr.ipv6.hoplimit = hdr.ipv6.hoplimit - 1;
      nexthop = nh;
    }
    action default_act() {
      nexthop = 0; 
    }
    table ipv6_lpm_tbl {
      key = { 
        hdr.ipv6.dstAddr : lpm;
        hdr.ipv6.class : ternary;
        hdr.ipv6.label : ternary;
      } 
      actions = {
        process; 
        default_act;
      }
      default_action = default_act;
    }
    apply {
      ipv6_lpm_tbl.apply(); 
    }
  }

  control micro_deparser(emitter em, pkt p, in l3v6_hdr_t h) {
    apply { 
      em.emit(p, h.ipv6); 
    }
  }
}

 
