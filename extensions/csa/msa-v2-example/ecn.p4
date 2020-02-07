/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include"msa.p4"
#include"common.p4"

#define CONGESTED_QDEPTH 32

header ipv4_ecn_h {
  bit<12> unused;
  bit<2> ecn;
}

struct ecn_hdr_t {
  ipv4_ecn_h ipv4;
}

cpackage ECN : implements Unicast<ecn_hdr_t, empty_t, empty_t, empty_t, empty_t> {

  parser micro_parser(extractor ex, pkt p, im_t im, out ecn_hdr_t hdr, 
                      inout empty_t meta, in empty_t ia, inout empty_t ioa) {
    state start {
      ex.extract(p, hdr.ipv4);
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout ecn_hdr_t hdr, inout empty_t m,
                          in empty_t e, out empty_t oa,
                          inout empty_t ioa) { // nexthop out arg

    apply { 
      if (im.get_value(metadata_fields_t.QUEUE_DEPTH_AT_DEQUEUE) > (bit<32>)CONGESTED_QDEPTH
          && (hdr.ipv4.ecn == 1 || hdr.ipv4.ecn == 2)) {
         hdr.ipv4.ecn = 3;
      }
    }
  }

  control micro_deparser(emitter em, pkt p, in ecn_hdr_t h) {
    apply { 
      em.emit(p, h.ipv4); 
    }
  }
}
