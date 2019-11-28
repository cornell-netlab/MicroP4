/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

struct ecn_meta_t { }


header ipv6_h {
  bit<4> version;
  bit<8> ecn;
  bit<20> label;
  bit<16> totalLen;
  bit<8> nexthdr;
  bit<8> hoplimit;
  bit<128> srcAddr;
  bit<128> dstAddr;  
}

struct ecn_hdr_t {
  ipv6_h ipv6;
}

cpackage ecnv6 : implements Unicast<ecn_hdr_t, ecn_meta_t, empty_t, empty_t, bit<16>> {
  parser micro_parser(extractor ex, pkt p, im_t im, out ecn_hdr_t hdr, inout  ecn_meta_t meta,
                        in empty_t ia, inout bit<16> ethType) { //inout arg
    state start {
      transition select(ethType){
        0x86DD: parse_ipv6;
      }
    }
    state parse_ipv6 {
      ex.extract(p, hdr.ipv6);
      transition accept;
    }
  }

  control micro_control(pkt p,  im_t im, inout ecn_hdr_t hdr, inout ecn_meta_t m, in empty_t e,
                         out empty_t oa, inout bit<16> ioa) {

   action set_ecn() {
    	hdr.ipv6.ecn = 3;
    }
    table ecn_tbl{
    	key = {
    		hdr.ipv6.ecn : exact;
    	}
    	actions = {
    		set_ecn;
    	}
    	const entries = {
    	    8w0o1: set_ecn();
    	    8w0o2: set_ecn();
    	}
    }
    
    apply {
      		ecn_tbl.apply();
    }
  }

  control micro_deparser(emitter em, pkt p, in ecn_hdr_t h) {
    apply { 
      em.emit(p, h.ipv6); 
    }
  }
}

