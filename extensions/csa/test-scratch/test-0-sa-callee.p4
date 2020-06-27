/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include"msa.p4"
#include"test-0-sa-common.p4"

struct callee_meta_t { 
}

header proto0_h {
  bit<8> ptype; 
}

header proto2_h {
  bit<16> sport; 
  bit<16> dport; 
}

header proto1_h {
  bit<32> sport; 
  bit<32> dport; 
}

header proto3_h {
  bit<16> d; 
}


struct callee_hdr_t {
  proto0_h p0;
  proto1_h p1;
  proto2_h p2;
  proto3_h p3;
}

cpackage Callee : implements Unicast<callee_hdr_t, callee_meta_t, 
                                     empty_t, empty_t, empty_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out callee_hdr_t hdr, inout callee_meta_t meta,
                        in empty_t ia, inout empty_t ioa) {
    state start {
      ex.extract(p, hdr.p0);
      transition select(hdr.p0.ptype) {
        0x06: parse_p1;
        0x17: parse_p2;
      }
    }

    state parse_p1 {
      ex.extract(p, hdr.p1);
      transition accept;
    }

    state parse_p2 {
      ex.extract(p, hdr.p2);
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout callee_hdr_t hdr, inout callee_meta_t m,
                          in empty_t ia, out empty_t oa, inout empty_t ioa) {
    apply { 
        if (hdr.p0.ptype == 8w0) {
            hdr.p0.setInvalid();
        } else {
            hdr.p1.setInvalid();
        }
        hdr.p3.setValid();
    }
  }

  control micro_deparser(emitter em, pkt p, in callee_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.p0);
      em.emit(p, hdr.p1);
      em.emit(p, hdr.p2);
      em.emit(p, hdr.p3);
    }
  }
}



 
