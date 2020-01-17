/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include"msa.p4"
#include"common.p4"

header ipv6filter_h {
  bit<4> version;
  bit<8> class;
  bit<20> label;
  bit<16> totalLen;
  bit<8> nexthdr;
  bit<8> hoplimit;
  bit<128> srcAddr;
  bit<128> dstAddr;  
}

struct ipv6filter_hdr_t {
  ipv6filter_h ipv6f;
}

cpackage ipv6filter : implements Unicast<l3v4_hdr_t, empty_t, 
                                      empty_t, empty_t, acl_result_t> {

  parser micro_parser(extractor ex, pkt p, im_t im, out ipv6filter_hdr_t hdr, 
                      inout empty_t meta, in empty_t ia, inout acl_result_t ioa) {
    state start {
      ex.extract(p, hdr.ipv6f);
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout ipv6filter_hdr_t hdr, inout empty_t m,
                          in empty_t ia, out empty_t oa, inout acl_result_t ioa) {
    action set_hard_drop() {
      ioa.hard_drop = 1w1;
      ioa.soft_drop = 1w0;
    }
    action set_soft_drop() {
      ioa.hard_drop = 1w0;
      ioa.soft_drop = 1w1;
    }
    action allow() {
      ioa.hard_drop = 1w0;
      ioa.soft_drop = 1w0;
    }

    table ipv6_filter {
      key = { 
        hdr.ipv6f.srcAddr : exact;
        hdr.ipv6f.dstAddr : exact;
      } 
      actions = { 
        set_hard_drop; 
        set_soft_drop;
        allow;
      }
      default_action = allow;

    }
    apply { 
      ipv6_filter.apply(); 
    }
  }

  control micro_deparser(emitter em, pkt p, in ipv6filter_hdr_t h) {
    apply { 
      em.emit(p, h.ipv6f); 
    }
  }
}

/*************** an alternative approach ***************/
/*
struct no_hdr_t {}
struct ipv6_filtertable_in_t {
  bit<128> sa;
  bit<128> da;
}
cpackage ipv6filterTable : implements Unicast<no_hdr_t, empty_t, 
                                  ipv6_filtertable_in_t, empty_t, acl_result_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out no_hdr_t hdr, 
                      inout empty_t meta, 
                      in ipv6_filtertable_in_t ia, inout acl_result_t ioa) {
    state start {
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout no_hdr_t hdr, inout empty_t m,
                          in ipv6_filtertable_in_t ia, out empty_t oa, 
                          inout acl_result_t ioa) {
    action set_hard_drop() {
      ioa.hard_drop = 1w1;
      ioa.soft_drop = 1w0;
    }
    action set_soft_drop() {
      ioa.hard_drop = 1w0;
      ioa.soft_drop = 1w1;
    }
    action allow() {
      ioa.hard_drop = 1w0;
      ioa.soft_drop = 1w0;
    }

    table ipv6_filter {
      key = { 
        ia.sa : exact;
        ia.da : exact;
      } 
      actions = { 
        set_hard_drop; 
        set_soft_drop;
        allow;
      }
      default_action = allow;

    }
    apply { 
      ipv6_filter.apply(); 
    }
  }

  control micro_deparser(emitter em, pkt p, in no_hdr_t h) {
    apply { 
    }
  }
}
*/
/*******************************************************/
