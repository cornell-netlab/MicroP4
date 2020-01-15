/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024
#define MPLS_ZONE_TTL 8w32

header mpls_h {
  bit<32> label;
  bit<16> exp;
  bit<8> bos;
  bit<8> ttl; 
}
struct mpls_hdr_t {
  mpls_h mpls0;
  mpls_h mpls1;
}

cpackage MplsLSR : implements Unicast<mpls_hdr_t, empty_t, 
                                  empty_t, bit<16>, bit<16> > {
  parser micro_parser(extractor ex, pkt p, im_t im, out mpls_hdr_t hdr, 
                      inout empty_t meta, in empty_t ia, 
                      inout bit<16> eth_type) {
    state start {
      ex.extract(p, hdr.mpls0);
      transition select(hdr.mpls0.bos) {
        8w0 : parse_mpls1;
        8w1 : accept;
      }
    }

    state parse_mpls1 {
      ex.extract(p, hdr.mpls1);
      transition accept;
    }
  }
  
  control micro_control(pkt p, im_t im, inout mpls_hdr_t hdr, inout empty_t m,
                        in empty_t ia, out bit<16> nextHop, 
                        inout bit<16> eth_type) {
    action drop_action() {
      im.drop(); // Drop packet
    }

    action encap1(){
      hdr.mpls1.setValid();
      
      hdr.mpls1.label = hdr.mpls0.label;
      hdr.mpls1.ttl = hdr.mpls0.ttl;
      hdr.mpls1.bos = hdr.mpls0.bos;
      hdr.mpls1.exp = hdr.mpls0.exp;
   		
      hdr.mpls0.label = 32w0x0400;
      hdr.mpls0.ttl = MPLS_ZONE_TTL;
      hdr.mpls1.bos = 8w0;
      nextHop = 16w10;
    }

    action encap0(){
      hdr.mpls0.setValid();
      hdr.mpls0.label = 32w0x4000;
      hdr.mpls0.ttl = MPLS_ZONE_TTL;
      nextHop = 16w10;
    }

    action decap(bit<16> t) {
      hdr.mpls0.setInvalid();
      nextHop = 16w10;
      eth_type = t;
    }
    
    action replace() {
      // hdr.mpls0.label = 20w0x4000;
      hdr.mpls0.ttl = hdr.mpls0.ttl -1;
      nextHop = 16w10;
    }
    
    table mpls_tbl{
    	key = {
    		hdr.mpls1.isValid() : exact;
    		hdr.mpls0.isValid() : exact;
    		hdr.mpls0.ttl : ternary;
    		hdr.mpls0.label : ternary;
    	}
    	actions = {
    		drop_action;
    		encap0;
    		encap1;
    		decap;
    		replace;
    	}
      /*
    	const entries = {
    	     (0,_,_,_): drop_action();
    	     (_,0x0800,_,_): encap();
    	     (_,0x8477, 20w0x4000, 1) : decap();
    	     (_,0x8477, 20w0x4001, 1): replace();
    	}
      */
    }
    
    apply {
          nextHop = 16w0;
      		mpls_tbl.apply();
    }
  }
  control micro_deparser(emitter em, pkt p, in mpls_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.mpls0);
      em.emit(p, hdr.mpls1);
    }
  }
}

