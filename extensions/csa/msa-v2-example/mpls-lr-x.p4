/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024
#define MPLS_ZONE_TTL 8w32

header mpls_h {
  bit<24> label;
  bit<8> exp;
  bit<8> bos;
  bit<8> ttl; 
}


struct mpls_hdr_t {
  mpls_h mpls0;
  mpls_h mpls1;
}


/*
 * If there is no MPLS header on packet, it can impose one.
 * If there is more than one it can remove.
 * It can also swap or find next hop based on the top(0th) MPLS header.
 */
cpackage MplsLR : implements Unicast<mpls_hdr_t, empty_t, 
                                  empty_t, empty_t, mplslr_inout_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out mpls_hdr_t hdr, 
                      inout empty_t meta, in empty_t ia, inout mplslr_inout_t ioa) {
                      
    state start {
      transition select(ioa.eth_type) {
        16w0x8847 : parse_mpls0;
        _ : accept;
      }
    }

    state parse_mpls0 {
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
                        in empty_t ia, out empty_t oa, inout mplslr_inout_t ioa) {
    action drop_action() {
      im.drop(); // Drop packet
    }

    action encap1(bit<24> lbl){
      ioa.eth_type = 0x8847;
      hdr.mpls1.setValid();
      
      hdr.mpls1.label = hdr.mpls0.label;
      hdr.mpls1.ttl = hdr.mpls0.ttl;
      hdr.mpls1.bos = hdr.mpls0.bos;
      hdr.mpls1.exp = hdr.mpls0.exp;
   		
      hdr.mpls0.label = lbl;
      hdr.mpls0.ttl = MPLS_ZONE_TTL;
      hdr.mpls1.bos = 8w0;
      ioa.next_hop = 16w10;
    }

    action encap0(bit<24> lbl){
      ioa.eth_type = 0x8847;
      hdr.mpls0.setValid();
      hdr.mpls0.label = lbl;
      hdr.mpls0.ttl = MPLS_ZONE_TTL;
      ioa.next_hop = 16w10;
    }

    action decap() {
      ioa.eth_type = 0x0800;
      hdr.mpls0.setInvalid();
      ioa.next_hop = 16w10;
    }
    
    action replace() {
      // hdr.mpls0.label = 20w0x4000;
      hdr.mpls0.ttl = hdr.mpls0.ttl -1;
      ioa.next_hop = 16w10;
    }
    
    table mpls_tbl{
    	key = {
    		hdr.mpls0.isValid() : exact;
    		hdr.mpls0.ttl : exact;
    		hdr.mpls0.label : exact;
        ioa.next_hop : exact;
        ioa.eth_type : exact;
    	}
    	actions = {
    		drop_action;
    		encap0;
    		encap1;
    		decap;
    		replace;
    	}
    }
    
    apply {
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

