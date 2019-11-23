/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include"msa.p4"
#include"nested-parser-common.p4"

struct caller_meta_t { 
  bit<8> l4proto;
}

header ethernet_h {
  bit<48> dmac;
  bit<48> smac;
  bit<16> ethType; 
}

header vlan_h {
  bit<16> ethType;
}

header ipv4_h {
  bit<8> protocol; 
  bit<32> src; 
  bit<32> dst; 
}

header ipv6_h {
  bit<8> nextHdr; 
  bit<128> src; 
  bit<128> dst; 
}

struct caller_hdr_t {
  ethernet_h eth;
  vlan_h vlan;
  ipv4_h ipv4;
  ipv6_h ipv6;
}

cpackage Caller : implements Unicast<caller_hdr_t, caller_meta_t, 
                                     empty_t, empty_t, empty_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out caller_hdr_t hdr, inout caller_meta_t meta,
                        in empty_t ia, inout empty_t ioa) {
    state start {
      ex.extract(p, hdr.eth);
      transition select(hdr.eth.ethType) {
        0x0800: parse_ipv4;
        0x86DD: parse_ipv6;
        0x8100: parse_vlan;
      }
    }

    state parse_vlan {
      ex.extract(p, hdr.vlan);
      transition select(hdr.vlan.ethType) {
        0x0800: parse_ipv4;
        0x86DD: parse_ipv6;
      }
    }

    state parse_ipv4 {
      ex.extract(p, hdr.ipv4);
      meta.l4proto = hdr.ipv4.protocol;
      transition accept;
    }

    state parse_ipv6 {
      ex.extract(p, hdr.ipv6);
      meta.l4proto = hdr.ipv6.nextHdr;
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout caller_hdr_t hdr, inout caller_meta_t m,
                          in empty_t ia, out empty_t oa, inout empty_t ioa) {
    Callee0() callee_i;
    apply {
      callee_i.apply(p, im, ia, oa, m.l4proto);
    }
  }

  control micro_deparser(emitter em, pkt p, in caller_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.eth); 
      em.emit(p, hdr.ipv4); 
      em.emit(p, hdr.ipv6); 
    }
  }
}

Caller() main;


 
