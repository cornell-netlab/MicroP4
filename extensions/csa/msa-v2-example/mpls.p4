/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024
#define MPLS_ZONE_TTL 32

struct mpls_meta_t {
  bit<16> ethType;
}


header mpls_h {
  bit<20> label; 
  bit<3> exp;
  bit<1> s;
  bit<8> ttl; 
}


struct mpls_hdr_t {
  mpls_h mpls;
}


cpackage Mpls : implements Unicast<mpls_hdr_t, mpls_meta_t, 
                                     empty_t, empty_t, bit<16>> {
  parser micro_parser(extractor ex, pkt p, im_t im, out mpls_hdr_t hdr, inout mpls_meta_t meta,
                        in empty_t ia, inout bit<16> ethType) {
    state start {
    meta.ethType = ethType;
      transition select(ethType) {
        0x8847: parse_mpls;
      }
    }

    state parse_mpls {
      ex.extract(p, hdr.mpls);
      transition accept;
    }

  }
  
control micro_control(pkt p, im_t im, inout mpls_hdr_t hdr, inout mpls_meta_t m,
                          in empty_t ia, out empty_t oa, inout bit<16> ioa) {
    action drop_action() {
            im.drop(); // Drop packet
       }
   action encap(){
   			m.ethType = 0x8847;
   			hdr.mpls.setValid();
   			hdr.mpls.label = 20w0x4000;
   			hdr.mpls.exp = 3w0x1;
   			hdr.mpls.s = 1w0x1;
   			hdr.mpls.ttl = MPLS_ZONE_TTL;
   			
       }
    action decap(){
   			m.ethType = 0x0800;
   			hdr.mpls.setInvalid();
       }
   action replace(){
   			hdr.mpls.label = 20w0x4000;
   			hdr.mpls.ttl = hdr.mpls.ttl -1;
   			
       }
    
    table mpls_tbl{
    	key = {
    		hdr.mpls.ttl : exact;
    		m.ethType : exact;
    		hdr.mpls.label : exact;
    		hdr.mpls.s : exact;
    	}
    	actions = {
    		drop_action;
    		encap;
    		decap;
    		replace;
    	}
    	const entries = {
    	     (0,_,_,_): drop_action();
    	     (_,0x0800,_,_): encap();
    	     (_,0x8477, 20w0x4000, 1) : decap();
    	     (_,0x8477, 20w0x4001, 1): replace();
    	}
    }
    
    apply {
      		mpls_tbl.apply();
    }
  }
  control micro_deparser(emitter em, pkt p, in mpls_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.mpls);
    }
  }
}

