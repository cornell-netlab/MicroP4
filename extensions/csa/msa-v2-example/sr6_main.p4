
/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024

struct sr_meta_t {

}


header ethernet_h {
  bit<48> dmac;
  bit<48> smac;
  bit<16> ethType; 
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


struct sr_hdr_t {
  ethernet_h eth;
  ipv6_h  ipv6;
}

// need to check the ip header for source routing option
// if option exists then check that the router is in the list of source routing list
// nexthop in the sr list would be the next hop 
cpackage SR4_main : implements Unicast<sr_hdr_t, sr_meta_t, 
                                     empty_t, empty_t, bit<16>> {
  parser micro_parser(extractor ex, pkt p, im_t im, out sr_hdr_t hdr, inout sr_meta_t meta,
                        in empty_t ia, inout bit<16> ethType) {          
    state start {
    ex.extract(p, hdr.eth);
      transition select(ethType) {
        0x08DD: parse_ipv6;
      }
    }

    state parse_ipv6 {
      ex.extract(p, hdr.ipv6);
      transition accept;
    }

  }
  
control micro_control(pkt p, im_t im, inout sr_hdr_t hdr, inout sr_meta_t m,
                          in empty_t ia, out empty_t oa, inout bit<16> ioa) {
                          
	IPv6-EXT() l3_i;
	bit<16> nh;
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
    	if (hdr.eth.ethType == 0x86DD)
    		l3_i.apply(p, im, ia, nh, ioa);
      	forward_tbl.apply();
    }
  }
  control micro_deparser(emitter em, pkt p, in sr_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.ip);
    }
  }
}

SR4_main() main;