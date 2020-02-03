/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024
#define MAX_SEG_LEFT 256
#define SEG_LEN 128
#define ROUTER_FUNC 0 // 0 for SR domain entry point , 1 for SR transit node
#define FIRST_SEG 0x02560a0b0c025660a0b0f5670dbbfe03
#define ROUTER_IP 0x20010a0b0c025660a0b0f5670dbbfe01
#define LOCAL_SRV6_SID 0x025603a1cc025660000000000000000
#define LOCAL_INT 0x02560a0b0c0256600000000000000000


header routing_ext_h {
	bit<8> nexthdr;
	bit<8> hdr_ext_len; // gives the length of the routing extension header in octets
	bit<8> routing_type;
}

// Here we consider that we do not have any options configured in the TLV
header sr6_h {
	bit<8> seg_left;
	bit<8> last_entry;  // index of the last element of the segment list zero based
	bit<8> flags; // 0 flag --> unused 
	bit<16> tag; // 0 if unused , not used when processsing the sid in 4.3.1
}
header seg1_h {
	bit<128> seg;
}
header seg2_h {
	bit<128> seg;
}
header seg3_h {
	bit<128> seg;
}
header seg4_h {
	bit<128> seg;
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


struct sr6_simple_hdr_t {
  ipv6_h ipv6; 
  routing_ext_h routing_ext0;
  sr6_h sr6;
  seg1_h seg1;
  seg2_h seg2;
  // seg3_h seg3;
  // seg4_h seg4;
}
 
cpackage SR_v6_Simple : implements Unicast<sr6_simple_hdr_t, empty_t, 
                                     empty_t, empty_t,  empty_t>  {
  parser micro_parser(extractor ex, pkt p, im_t im, out sr6_simple_hdr_t hdr, 
                      inout empty_t meta, in empty_t ia, inout empty_t ioa) {
    state start {
      ex.extract(p, hdr.ipv6);
      transition select(hdr.ipv6.nexthdr) {
        43: parse_routing_ext;
      }
    }

    state parse_routing_ext {
      ex.extract(p, hdr.routing_ext0);
      transition select(hdr.routing_ext0.routing_type){
      	4: check_seg_routing; 
      }
    }
  
    state check_seg_routing {
      transition select(hdr.ipv6.dstAddr){
        ROUTER_IP : parse_seg_routing;
      }
    }
    
    state parse_seg_routing {
      ex.extract(p, hdr.sr6);
      transition select(hdr.sr6.seg_left) {
        1: parse_seg1;
        2: parse_seg2;
    		// 3: parse_seg3;
    		// 4: parse_seg4;
      }
	  }
	
    state parse_seg1 {
      ex.extract(p, hdr.seg1);
      transition accept;
    }
	
    state parse_seg2 {
      ex.extract(p, hdr.seg1);
      ex.extract(p, hdr.seg2);
      transition accept;
    }
	
  /*
    state parse_seg3 {
      ex.extract(p, hdr.seg1);
      ex.extract(p, hdr.seg2);
      ex.extract(p, hdr.seg3);
      transition accept;
    }
    state parse_seg4 {
      ex.extract(p, hdr.seg1);
      ex.extract(p, hdr.seg2);
      ex.extract(p, hdr.seg3);
      ex.extract(p, hdr.seg4);
      transition accept;
    }
    */
  }
 
  control micro_control(pkt p, im_t im, inout sr6_simple_hdr_t hdr, inout empty_t m,
                        in empty_t ia, out empty_t oa, inout empty_t ioa) {
                        
    action drop_action() {
      im.drop(); // Drop packet
    }
    action copy_frm_first_seg(){
      hdr.ipv6.dstAddr = hdr.seg1.seg;
      hdr.sr6.seg_left = hdr.sr6.seg_left -1;
    }
    action copy_frm_second_seg(){
      hdr.ipv6.dstAddr = hdr.seg2.seg;
      hdr.sr6.seg_left = hdr.sr6.seg_left -1;
    }
    /*
    action copy_frm_third_seg(){
      hdr.ipv6.dstAddr = hdr.seg3.seg;
      hdr.sr6.seg_left = hdr.sr6.seg_left -1;
    }
    action copy_frm_fourth_seg(){
      hdr.ipv6.dstAddr = hdr.seg4.seg;
      hdr.sr6.seg_left = hdr.sr6.seg_left -1;
    }
    */
    table srv6_table {
    	key = {
	    	 hdr.routing_ext0.routing_type: exact;
	    	 hdr.sr6.last_entry: ternary; 
	    	 hdr.sr6.seg_left: ternary; 
    	}
    	actions = {
    		drop_action; 
        copy_frm_first_seg();
        copy_frm_second_seg();
        // copy_frm_third_seg();
        // copy_frm_fourth_seg();
    	}
    }	
    apply {
      srv6_table.apply();
    }
  }

  control micro_deparser(emitter em, pkt p, in sr6_simple_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.ipv6);
      em.emit(p, hdr.routing_ext0);
      em.emit(p, hdr.sr6);
      em.emit(p, hdr.seg1); 
      // em.emit(p, hdr.seg2); 
      // em.emit(p, hdr.seg3); 
    }
  }
}

