/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

struct main_meta_t { 
	bit<8> l4proto;
}


header ethernet_h {
  bit<48> dmac;
  bit<48> smac;
  bit<16> ethType; 
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

struct main_hdr_t {
  ethernet_h eth;
  ipv4_h ipv4;
  ipv6_h ipv6;
}

cpackage ModularMultiFunction : implements Unicast<main_hdr_t, main_meta_t, 
                                            empty_t, empty_t, empty_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out main_hdr_t main_hdr, inout main_meta_t m,
                        in empty_t ia, inout empty_t ioa) {

    state start {
      ex.extract(p, main_hdr.eth);
      transition select(main_hdr.eth.ethType) {
        0x0800: parse_ipv4;
        0x86DD: parse_ipv6;
      }
    }

    state parse_ipv4 {
      ex.extract(p, main_hdr.ipv4);
      m.l4proto = main_hdr.ipv4.protocol;
      transition accept;
    }

    state parse_ipv6 {
      ex.extract(p, main_hdr.ipv6);
      m.l4proto = main_hdr.ipv6.nexthdr;
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout main_hdr_t main_hdr, inout main_meta_t m,
                          in empty_t ia, out empty_t oa, inout empty_t ioa) {
    Filter_L4() filter;
    bit<16> nh;
    L3v4() l3_i;
    Nat_L3() nat3_i;
    ecnv4() ecn_i;
    action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
      main_hdr.eth.dmac = dmac;
      main_hdr.eth.smac = smac;
      im.set_out_port(port);
    }
    table forward_tbl {
      key = { nh : exact; } 
      actions = { forward; }
    }
    apply { 
      filter.apply(p, im, ia, oa, m.l4proto);
      nat3_i.apply(p, im, ia, oa, main_hdr.eth.ethType);
      ecn_i.apply(p, im, ia, oa, main_hdr.eth.ethType);
      l3_i.apply(p, im, ia, nh, main_hdr.eth.ethType);
      forward_tbl.apply(); 
    }
  }

  control micro_deparser(emitter em, pkt p, in main_hdr_t main_hdr) {
    apply { 
      em.emit(p, main_hdr.eth); 
    }
  }
}

ModularMultiFunction() main;


 
