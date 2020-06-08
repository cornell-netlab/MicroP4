/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include"msa.p4"
#include"common.p4"

struct no_hdr_t {}
cpackage IPv6ACL : implements Unicast<no_hdr_t, empty_t, 
                                  ipv6_acl_in_t, empty_t, acl_result_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out no_hdr_t hdr, 
                      inout empty_t meta, 
                      in ipv6_acl_in_t ia, inout acl_result_t ioa) {
    state start {
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout no_hdr_t hdr, inout empty_t m,
                          in ipv6_acl_in_t ia, out empty_t oa, 
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
      if (ioa.hard_drop == 1w0)
        ipv6_filter.apply(); 
    }
  }

  control micro_deparser(emitter em, pkt p, in no_hdr_t h) {
    apply { 
    }
  }
}
