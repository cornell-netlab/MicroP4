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
    
    IPv4() ipv4_i;
    IPv4NatACL() ipv4_nat_acl_i;
    IPv6() ipv6_i;
    IPv6NatACL() ipv6_nat_acl_i;
    // MplsLR() mpls_i;
    // mplslr_inout_t mplsio;
    empty_t e;
    apply { 
      if (ioa.eth_type == 16w0x0800) {
        ipv4_nat_acl_i.apply(p, im, ia, oa, ioa.acl);
        ipv4_i.apply(p, im, ia, ioa.next_hop, e);
      }
      else if (ioa.eth_type == 16w0x86DD) {
        ipv6_nat_acl_i.apply(p, im, ia, oa, ioa.acl);
        ipv6_i.apply(p, im, ia, ioa.next_hop, e);
      }
      
      /*
      mplsio.eth_type = ioa.eth_type;
      mplsio.next_hop = ioa.next_hop;
      if (ioa.next_hop == 16w0)
        mpls_i.apply(p, im, ia, oa, mplsio);
      ioa.eth_type = mplsio.eth_type;
      ioa.next_hop = mplsio.next_hop;
      */
      
    }
  }

  control micro_deparser(emitter em, pkt p, in l3_hdr_t h) {
    apply { 
    }
  }
}

 
