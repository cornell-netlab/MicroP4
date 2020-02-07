#include "msa.p4"

struct empty_t { }

header four_t {
  bit<4> thing;
}

struct hdr_t {
  four_t four;
  four_t four_again;
}

cpackage Dummy4 : implements Unicast<hdr_t, empty_t, empty_t, empty_t, empty_t> {

  parser micro_parser(extractor ex, pkt p, im_t im, out hdr_t hdr, 
                      inout empty_t meta, in empty_t ia, inout empty_t ioa) {
    state start {
      ex.extract(p, hdr.four);
      transition select(hdr.four.thing) {
        0x1: again;
        _: accept;
      }
    }

    state again {
      ex.extract(p, hdr.four_again);
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout hdr_t hdr, inout empty_t m,
                          in empty_t e, out empty_t nexthop, 
                          inout empty_t ioa) {
    apply { 
    }
  }

  control micro_deparser(emitter em, pkt p, in hdr_t h) {
    apply { 
    }
  }
}

cpackage Dummy4Duplicate : implements Unicast<hdr_t, empty_t, empty_t, empty_t, empty_t> {

  parser micro_parser(extractor ex, pkt p, im_t im, out hdr_t hdr, 
                      inout empty_t meta, in empty_t ia, inout empty_t ioa) {
    state start {
      ex.extract(p, hdr.four);
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout hdr_t hdr, inout empty_t m,
                          in empty_t e, out empty_t nexthop, 
                          inout empty_t ioa) {
    Dummy4() dummy;
    apply { 
      dummy.apply(p, im, e, nexthop, ioa);
    }
  }

  control micro_deparser(emitter em, pkt p, in hdr_t h) {
    apply { 
    }
  }
}

Dummy4Duplicate() main;