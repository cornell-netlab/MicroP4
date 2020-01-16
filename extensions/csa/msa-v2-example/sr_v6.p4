/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024
#define MATCHING_IP 0x0a000256
#define DESTINATION 0x0a000256

struct sr6_meta_t {
	bit<4> num_addrs;
}


header routing_ext_h {
	bit<8> nexthdr;
	bit<8> hdr_ext_len; // gives the length of the routing extension header in octets
	bit<8> routing_type;
}

header sr6_h {
	bit<8> seg_left;
	bit<8> last_entry;
	bit<8> flags;
	bit<16> tag;
}
  
header sr6_1addr_h {
	bit<128> address1; 
}

header sr6_2addr_h {
	bit<128> address1;
	bit<128> address2; 
}

header sr6_3addr_h {
	bit<128> address1;
	bit<128> address2;
	bit<128> address3; 
}

header sr6_4addr_h {
	bit<128> address1; 
	bit<128> address2;
	bit<128> address3;
	bit<128> address4; 
#define MAX_REMAINING_ADDRESSES 4
	varbit<(128*MAX_REMAINING_ADDRESSES)> remaining_addresses;	
}


struct sr6_hdr_t {
  routing_ext_h routing_ext0;
  sr6_h sr6;
  sr6_1addr_h sr_1addr;
  sr6_2addr_h sr_2addr;
  sr6_3addr_h sr_3addr; 
  sr6_4addr_h sr_4addr;
}

// source routing 
// need to check that the node's ip address matches one of the addresses in the sr header 
// if it does not match we drop 
// if it matches then the nexthop is set to the next address in the list 
// the header is not modified
 
cpackage SR_v6 : implements Unicast<sr6_hdr_t, sr6_meta_t, 
                                     empty_t, bit<16>, bit<8>> {
  parser micro_parser(extractor ex, pkt p, im_t im, out sr6_hdr_t hdr, inout sr6_meta_t meta,
                        in empty_t ia, inout bit<8> nexthdr) {
    state start {
      transition select(nexthdr) {
        43: parse_routing_ext;
      }
    }

    state parse_routing_ext {
      ex.extract(p, hdr.routing_ext0);
      transition select(hdr.routing_ext0.routing_type){
      	3: parse_src_routing; 
      }
    }
    
    state parse_src_routing {
      ex.extract(p, hdr.sr6);
      transition select(hdr.routing_ext0.hdr_ext_len){
		2: parse_single_address;
		3: parse_two_addresses;
		4: parse_three_addresses;
		_: parse_four_addresses; 
      }
    }

	state parse_single_address {
		ex.extract (p, hdr.sr_1addr);
		transition accept;
	}
	
	state parse_two_addresses {
		ex.extract (p, hdr.sr_2addr);
		transition accept;
	}
	
	state parse_three_addresses {
		ex.extract (p, hdr.sr_3addr);
		transition accept;
	}
	
	state parse_four_addresses {
		ex.extract (p, hdr.sr_4addr);
		transition accept;
	}
  
  }
  
control micro_control(pkt p, im_t im, inout sr6_hdr_t hdr, inout sr6_meta_t m,
                          in empty_t ia,  out bit<16> nh, inout bit<8> ioa) {
    bit<128> neighbour;
    action drop_action() {
            im.drop(); // Drop packet
       }
       
    action set_nexthop(bit<128> nextHopAddr) {
      neighbour = nextHopAddr;
    }

    table sr6_tbl{
    	key = {
    	 hdr.routing_ext0.routing_type: exact;
    	 hdr.routing_ext0.hdr_ext_len: exact;
    	 hdr.sr6.last_entry: exact; 
    	 hdr.sr_1addr.address1: exact;
    	 hdr.sr_2addr.address1: exact;
    	 hdr.sr_2addr.address2: exact;
    	 hdr.sr_3addr.address1: exact;
    	 hdr.sr_3addr.address2: exact;
    	 hdr.sr_3addr.address3: exact;
    	 hdr.sr_4addr.address1: exact;
    	 hdr.sr_4addr.address2: exact;
    	 hdr.sr_4addr.address3: exact;
    	 hdr.sr_4addr.address4: exact;
    	}
    	actions = {
    		drop_action;
    		set_nexthop;
    	}
    	const entries = {
    	(3, 2, 1, MATCHING_IP, _, _, _, _, _, _, _, _, _): set_nexthop(DESTINATION);
    	(3, 2, _, _, _, _, _, _, _, _, _, _, _): drop_action();
    	(3, 3, 0, _, MATCHING_IP, _, _, _, _, _, _, _, _): set_nexthop(hdr.sr_2addr.address2);
    	(3, 3, 1, _, _, MATCHING_IP, _, _, _, _, _, _, _): set_nexthop(DESTINATION);
    	(3, 3, _, _, _, _, _, _, _, _, _, _, _): drop_action();
    	(3, 4, 0, _, _, _, MATCHING_IP, _, _, _, _, _, _): set_nexthop(hdr.sr_3addr.address2);
    	(3, 4, 0, _, _, _, _, MATCHING_IP, _, _, _, _, _): set_nexthop(hdr.sr_3addr.address3); 
    	(3, 4, 1, _, _, _, _, _, MATCHING_IP, _, _, _, _): set_nexthop(DESTINATION);
    	(3, 4, _, _, _, _, _, _, _, _, _, _, _): drop_action();
    	(3, 5, 0, _, _, _, _, _, _, MATCHING_IP, _, _, _): set_nexthop(hdr.sr_4addr.address2);
    	(3, 5, 0, _, _, _, _, _, _, _, MATCHING_IP, _, _): set_nexthop(hdr.sr_4addr.address3); 
    	(3, 5, 0, _, _, _, _, _, _, _, _, MATCHING_IP, _): set_nexthop(hdr.sr_4addr.address4);
    	(3, 5, 0, _, _, _, _, _, _, _, _, _, MATCHING_IP): set_nexthop(DESTINATION);
    	(3, 5, 1, _, _, _, _, _, _, _, _, MATCHING_IP, _): set_nexthop(DESTINATION);
    	//TODO check for match in the remaining addresses if size more than 5
    	(3, 5, _, _, _, _, _, _, _, _, _, _, _): drop_action();
    	
    	}
    }	
   	action set_out_arg(bit<16> n) {
    	 nh = n; 
    }  
    table set_out_nh_tbl{
    	key = {
    	  neighbour: exact;
    	}
    	actions = {
    		set_out_arg;
      }
    }
    
    apply {
      		sr6_tbl.apply();
          set_out_nh_tbl.apply();
    }
  }
  control micro_deparser(emitter em, pkt p, in sr6_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.routing_ext0);
      em.emit(p, hdr.sr6);
      em.emit(p, hdr.sr_1addr);
      em.emit(p, hdr.sr_2addr);
      em.emit(p, hdr.sr_3addr);
      em.emit(p, hdr.sr_4addr);
    }
  }
}

