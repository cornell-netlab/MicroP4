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
	varbit<(MAX_SEG_LEFT * SEG_LEN)> segment_lists; // first element contains the last segment of the SR policy 
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

struct sr6_hdr_t {
  routing_ext_h routing_ext0;
  sr6_h sr6;
  ipv6_h inner_ipv6; 
  routing_ext_h routing_ext1;
}

// Segment Routing 
// SR ingress router : generate SR segment packet with segment in the destination i.e. encapsulates a received pkt in outer ipv6 hdr followed by optional srh 
// transit : forward packets with SR segments 
// endpoint : process local segment in the destination IPv6 
// need to get ipv6 header information here as metadata 
 
cpackage SR_v6 : implements Unicast<sr6_hdr_t, empty_t, 
                                     empty_t, empty_t,  sr6_inout_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out sr6_hdr_t hdr, inout empty_t meta,
                        in empty_t ia, inout sr6_inout_t ioa) {
    state start {
      transition select(ioa.nexthdr) {
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
      	transition select(ioa.dstAddr){
      		ROUTER_IP : parse_seg_routing;
      	}
	}
    
    state parse_seg_routing {
      	ex.extract(p, hdr.sr6, (bit<32>)(hdr.routing_ext0.hdr_ext_len *128 - 24));
		transition accept;
	}
  
  }
 
control micro_control(pkt p, im_t im, inout sr6_hdr_t hdr, inout empty_t m,
                          in empty_t ia,  out empty_t oa, inout sr6_inout_t ioa) {
                          
	action ingress_sr(){
		// SR domain ingress router : generate SR segment packet with segment in the destination i.e. encapsulates a received pkt in outer ipv6 hdr followed by optional srh
		hdr.routing_ext0.setValid();
		hdr.routing_ext0.nexthdr = 43;
		hdr.routing_ext0.hdr_ext_len = 6; 
		hdr.routing_ext0.routing_type = 4;
		hdr.sr6.setValid();
		hdr.sr6. seg_left = 3;
		hdr.sr6.last_entry = 3;  
		hdr.sr6.flags = 0;
		hdr.sr6.tag = 0; 
		hdr.sr6.segment_lists = (bit<384>)0x02560a0b0c025660a0b0f5670dbbfe03025d0a0b0c125660a0b0f5670dbbfe0302560ade0c025660a0b0f5670dbbfe03;
		ioa.dstAddr = FIRST_SEG;
	
		hdr.inner_ipv6.setValid();
		// copy the exact same values from the outer ipv6 address with the original ipv6 destination address 
		hdr.inner_ipv6.version = 6;
  		hdr.inner_ipv6.class = 0;
  		hdr.inner_ipv6.label = 0;
  		hdr.inner_ipv6.totalLen = ioa.totalLen;
  		hdr.inner_ipv6.nexthdr = ioa.nexthdr;
  		hdr.inner_ipv6.hoplimit = ioa.hoplimit;
  		hdr.inner_ipv6.srcAddr = ioa.srcAddr;
  		hdr.inner_ipv6.dstAddr = ioa.dstAddr;  
	 
	}  
	                     
	action endpoint_sr_lss() {
		hdr.sr6.seg_left = hdr.sr6.seg_left -1;
		//ioa.dstAddr = hdr.sr6.segment_lists[(hdr.routing_ext0.hdr.ext_len-3-hdr.sr6.seg_left)*128:(hdr.routing_ext0.hdr.ext_len-2-hdr.sr6.seg_left)*128];
	}

	// if egress domain sr router then decap the SR outer IP header + SRH and process next hdr 
	action egress_sr(){
		hdr.routing_ext0.setInvalid();
		hdr.sr6.setInvalid();
		hdr.inner_ipv6.setInvalid();
		ioa.totalLen = hdr.inner_ipv6.totalLen;
  		ioa.nexthdr = hdr.inner_ipv6.nexthdr;
  		ioa.hoplimit = hdr.inner_ipv6.hoplimit;
  		ioa.srcAddr = hdr.inner_ipv6.srcAddr;
  		ioa.dstAddr = hdr.inner_ipv6.dstAddr;  
	}
	   
    action drop_action() {
            im.drop(); // Drop packet
      }

    table sr6_tbl{
    	key = {
	    	 hdr.routing_ext0.routing_type: exact;
	    	 ioa.dstAddr: lpm;
	    	 hdr.sr6.last_entry: ternary; 
	    	 hdr.sr6.seg_left: ternary; 
    	}
    	actions = {
    		ingress_sr;
    		endpoint_sr_lss;
    		egress_sr;
    		drop_action;    		
    	}
    	 const entries = {
	    	(4, LOCAL_SRV6_SID, _, 0) : egress_sr();
	    	//(4, LOCAL_SRV6_SID, _, _ ) : drop_action();
	    	(4, LOCAL_SRV6_SID, _, _) : endpoint_sr_lss(); 
	    	(4, LOCAL_INT, _, 0) : egress_sr();
	    	(4, LOCAL_INT, _, _) : drop_action();
	    	(4, _, _, _) : ingress_sr();
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
      em.emit(p, hdr.inner_ipv6);
      em.emit(p, hdr.routing_ext1);
    }
  }
}

