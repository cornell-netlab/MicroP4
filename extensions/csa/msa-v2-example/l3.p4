/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include"msa.p4"
#include"common.p4"

struct l3_hdr_t {
}

cpackage L3 : implements Unicast<l3_hdr_t, empty_t, empty_t, empty_t, l3_inout_t> {

  parser micro_parser(extractor ex, pkt p, im_t im, out l3_hdr_t hdr, 
                      inout empty_t meta, in empty_t ia, inout l3_inout_t ioa) {
    state start {
      transition select(ioa.eth_type) {
        16w0x0800 : accept;
        16w0x86DD : accept;
        16w0x8847 : accept;
      }
    }
  }

  control micro_control(pkt p, im_t im, inout l3_hdr_t hdr, inout empty_t m,
                          in empty_t ia, out empty_t oa, inout l3_inout_t ioa) {
    
    /*
    L3v4() l3v4_i;
    L3v6() l3v6_i;
    MplsLR() mpls_i;
    */

    IPv4() ipv4_i;
    IPv4NatACL() ipv4_nat_acl_i;
    empty_t e;
    apply { 
      if (ioa.eth_type == 16w0x0800) {
        ipv4_nat_acl_i.apply(p, im, ia, oa, ioa.acl);
        ipv4_i.apply(p, im, ia, ioa.next_hop, e);
      }
      else if (ioa.eth_type == 16w0x86DD) {
      }
      
      if (ioa.eth_type == 16w0x8847) {
      }
      
    }
  }

  control micro_deparser(emitter em, pkt p, in l3_hdr_t h) {
    apply { 
    }
  }
}

 
