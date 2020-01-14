/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024

struct sr6_meta_t {
}


header routing_ext_h {
	bit<8> nexthdr;
	bit<8> hdr_ext_len; // gives the length of the routing extension header in octets
	bit<8> routing_type;
	bit<8> seg_left;
}

// an example is set here assuming that we have only 4 IPv6 addresses in the route , there can be up to:
// ((hdr_ext_len * 8) - 64 )/128  
header sr6_h {
	bit<4> cmprI; // info if addresses 1 to n-1 are compressed ,  0  not compressed
	bit<4> cmprE; // info if last address is compressed, 0 not compressed
	bit<4> pad;
	bit<20> reserved;
	//conceptually : addresses vector varbit<((hdr_ext_len * 8) - 64 )/128>  addresses
	bit<128> address1; 
	bit<128> address2;
	bit<128> address3;
	bit<128> address4; 

}

struct sr6_hdr_t {
  routing_ext_h routing_ext0;
  sr6_h sr; 
  routing_ext_h routing_ext1;
}

// source routing 
// need to check that the node's ip address matches one of the addresses in the sr header 
// if it does not match we drop 
// if it matches then the nexthop is set to the next address in the list 
// the header is not modified
 
cpackage SR_v6 : implements Unicast<sr6_hdr_t, sr6_meta_t, 
                                     empty_t, empty_t, bit<16>> {
  parser micro_parser(extractor ex, pkt p, im_t im, out sr6_hdr_t hdr, inout sr6_meta_t meta,
                        in empty_t ia, inout bit<16> ethType) {
    state start {
      transition select(nexthdr) {
        8x43: parse_routing_ext;
      }
    }

    state parse_routing_ext {
      ex.extract(p, hdr.routing_ext0);
      transition select(hdr.routing_ext.routing_type){
      	8x03: parse_src_routing; 
      }
    }
    
    state parse_src_routing {
      ex.extract(p, hdr.sr);
      transition accept;
    }

  
  }
  
control micro_control(pkt p, im_t im, inout sr6_hdr_t hdr, inout sr6_meta_t m,
                          in empty_t ia, out empty_t oa, inout bit<16> ioa) {
    action drop_action() {
            im.drop(); // Drop packet
       }
    table sr6_tbl{
    	key = {
    	 hdr.routing_ext.routing_type: exact;
    	 hdr.sr.cmprI: exact; 
    	 hdr.sr.cmprE: exact; 
    	 hdr.sr.address1: exact;  
    	// remaining addresses or directly maytch against addresses
    	}
    	actions = {
    		drop_action;
    		set_nexthop;
    	}
    	const entries = {
    	// TODO 
    	(8x03, 0, 0, MATCHING_IP,...): set_nexthop();
    	(8x03, 0, 0, _,_,_...): drop_action();
    	
    	}
    }
    
    apply {
      		sr6_tbl.apply();
    }
  }
  control micro_deparser(emitter em, pkt p, in sr6_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.routing_ext0);
      em.emit(p, hdr.sr6);
    }
  }
}

