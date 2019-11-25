/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

struct meta_t { 
	bit<8> l4proto;
}


header ethernet_h {
    bit<96> unused;
    bit<16> etherType;
}

header ipv4_h {
  bit<4> version;
  bit<4> ihl;
  bit<8> diffserv;
  bit<8> ecn;
  bit<16> totalLen;
  bit<16> identification;
  bit<3> flags;
  bit<13> fragOffset;
  bit<8> ttl;
  bit<8> protocol;
  bit<16> hdrChecksum;
  bit<32> srcAddr;
  bit<32> dstAddr; 
}

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

struct hdr_t {
  ethernet_h eth;
  ipv4_h ipv4;
  ipv6_h ipv6;
}

cpackage ModularFirewall : implements Unicast<hdr_t, meta_t, 
                                            empty_t, empty_t, empty_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out hdr_t hdr, inout meta_t m,
                        in empty_t ia, inout empty_t ioa) {

    state start {
      ex.extract(p, hdr.eth);
      transition select(hdr.eth.etherType) {
        0x0800: parse_ipv4;
        0x86DD: parse_ipv6;
      }
    }

    state parse_ipv4 {
      ex.extract(p, hdr.ipv4);
      m.l4proto = hdr.ipv4.protocol;
      transition accept;
    }

    state parse_ipv6 {
      ex.extract(p, hdr.ipv6);
      m.l4proto = hdr.ipv6.nexthdr;
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout hdr_t hdr, inout meta_t m,
                          in empty_t ia, out empty_t oa, inout empty_t ioa) {
    Filter_L4() filter;
     bit<16> nh;
    Nat_L3() nat3_i;
    action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
      hdr.eth.dmac = dmac;
      hdr.eth.smac = smac;
      im.set_out_port(port);
    }
    table forward_tbl {
      key = { nh : lpm; } 
      actions = { forward; }
    }
    apply { 
      filter.apply(p, im, ia, oa, m.l4proto);
      forward_tbl.apply(); 
    }
  }

  control micro_deparser(emitter em, pkt p, in hdr_t hdr) {
    apply { 
      em.emit(p, hdr.eth); 
    }
  }
}

ModularFirewall() main;


 
