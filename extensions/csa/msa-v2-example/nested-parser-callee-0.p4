/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include"msa.p4"
#include"nested-parser-common.p4"

struct callee0_meta_t { 
  bit<8> l4proto;
}

header udp_h {
  bit<16> sport; 
  bit<16> dport; 
}

header tcp_h {
  bit<16> sport; 
  bit<16> dport; 
}

struct callee_hdr_t {
  tcp_h tcp;
  udp_h udp;
}

cpackage Callee0 : implements Unicast<callee_hdr_t, callee0_meta_t, 
                                     empty_t, empty_t, bit<8>> {
  parser micro_parser(extractor ex, pkt p, im_t im, out callee_hdr_t hdr, inout callee0_meta_t meta,
                        in empty_t ia, inout bit<8> l4proto) {
    state start {
      transition select(l4proto) {
        0x06: parse_tcp;
        0x17: parse_udp;
      }
    }

    state parse_tcp {
      ex.extract(p, hdr.tcp);
      transition accept;
    }

    state parse_udp {
      ex.extract(p, hdr.udp);
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout callee_hdr_t hdr, inout callee0_meta_t m,
                          in empty_t ia, out empty_t oa, inout bit<8> ioa) {
    apply { 
    }
  }

  control micro_deparser(emitter em, pkt p, in callee_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.tcp);
      em.emit(p, hdr.udp);
    }
  }
}



 
