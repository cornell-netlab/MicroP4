/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

struct l3_meta_t { }


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

struct l3v6_hdr_t {
  ipv6_h ipv6;
}

cpackage IPv6-EXT : implements Unicast<l3v6_hdr_t, l3_meta_t, empty_t, bit<16>, empty_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out l3v6_hdr_t hdr, inout l3_meta_t meta,  
                        in empty_t ia, inout empty_t ioa) { //inout arg
    state start {
      ex.extract(p, hdr.ipv6);
      
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout l3v6_hdr_t hdr, inout l3_meta_t m,
                          in empty_t e, out bit<16> nexthop, 
                          inout empty_t ioa) { // nexthop out arg
                          
    srv6_inout_t srv6io;
    
	action process(bit<16> nh){
	  hdr.ipv6.dstAddr = srv6io.dstAddr;
	  dr.ipv6.srcAddr = srv6io.srcAddr;
	  hdr.ipv6.totalLen = srv6io.totalLen;
      hdr.ipv6.hoplimit = srv6ioa.hoplimit - 1;
      nexthop = nh;
    }
    action default_act() {
      nexthop = 0; 
    }
    action drop_act() {
    	im.drop(); 
    }
    table ipv6_lpm_tbl {
      key = { 
        hdr.ipv6.dstAddr : lpm;
        hdr.ipv6.hopcount : exact;
        hdr.ipv6.class : ternary;
        hdr.ipv6.label : ternary;
      } 
      actions = {
        process; 
        drop_act;
        default_act;
      }
      default_action = default_act;
    }
    apply {
   		srv6io.totalLen = hdr.ipv6.totalLen;
    	srv6io.srcAddr = hdr.ipv6.srcAddr;
    	srv6io.dstAddr = hdr.ipv6.dstAddr;
    	srv6io.hoplimit = hdr.ipv6.hoplimit;
    	srv6io.nexthop = hdr.ipv6.nexthop;
    	if (hdr.ipv6.nexthdr == 43)
    		srv6.apply(p, im, ia, oa, srv6io);
      	ipv6_lpm_tbl.apply(); 
    }
  }

  control micro_deparser(emitter em, pkt p, in l3v6_hdr_t h) {
    apply { 
      em.emit(p, h.ipv6); 
    }
  }
}

 

 