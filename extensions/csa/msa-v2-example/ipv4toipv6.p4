/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

header ipv4_h {
  bit<4> version;
  bit<8> ihl;
  bit<8> diffserv;
  bit<16> totalLen;
  bit<16> identification;
  bit<3> flags;
  bit<13> fragOffset;
  bit<8> ttl;
  bit<8> protocol;
  bit<16> hdrChecksum;
  bit<32> srcAddr;
  bit<32> dstAddr; 
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

struct v4tov6_hdr_t {
  ipv4_h ipv4;
  ipv6_h ipv6;
}

cpackage IPv4toIPv6 : implements Unicast<v4tov6_hdr_t, empty_t, empty_t, empty_t, bit<16>> {

  parser micro_parser(extractor ex, pkt p, im_t im, out v4tov6_hdr_t hdr, 
                      inout empty_t meta, in empty_t ia, inout bit<16> ethType) {
    state start {
      transition select(ethType){
      	0x0800: parse_ipv4;
      	0x86DD: parse_ipv6;
      }
    }
    
    state parse_ipv4 { 
      ex.extract(p, hdr.ipv4);
      transition accept;
    }
    
    state parse_ipv6 { 
      ex.extract(p, hdr.ipv6);
      transition accept;
    }
  }

// simple v4 to v6 translation, we consider unfragmented packets and without options 
  control micro_control(pkt p, im_t im, inout v4tov6_hdr_t hdr, inout empty_t m,
                          in empty_t e, out empty_t oa, 
                          inout bit<16> ethType) { 
    
    action v4_v6(){
	    hdr.ipv4.setInvalid();
	    hdr.ipv6.setValid();
	    hdr.ipv6.version = 6;
 		hdr.ipv6.class = hdr.ipv4.diffserv;
  		hdr.ipv6.label = 0;
 		hdr.ipv6.totalLen = hdr.ipv4.totalLen - (bit<16>)(hdr.ipv4.ihl);
  		hdr.ipv6.nexthdr = hdr.ipv4.protocol; 
  		hdr.ipv6.hoplimit = hdr.ipv4.ttl;
  		hdr.ipv6.srcAddr = (bit<128>)hdr.ipv4.srcAddr;
  		hdr.ipv6.dstAddr = (bit<128>)hdr.ipv4.dstAddr; 
    }

	action v6_v4(){
		hdr.ipv6.setInvalid();
	    hdr.ipv4.setValid();
	  	hdr.ipv4.version = 4;
	  	hdr.ipv4.ihl = 20;
  		hdr.ipv4.diffserv = hdr.ipv6.class;
  		hdr.ipv4.totalLen = hdr.ipv6.totalLen +  (bit<16>)(hdr.ipv4.ihl);
  		hdr.ipv4.identification = 0;
		hdr.ipv4.flags = 0;
  		hdr.ipv4.fragOffset = 0;
  		hdr.ipv4.ttl = hdr.ipv6.hoplimit;
  		hdr.ipv4.protocol = hdr.ipv6.nexthdr;
  		hdr.ipv4.hdrChecksum = 0;
  		hdr.ipv4.srcAddr = (bit<32>)(hdr.ipv6.srcAddr << 96);
  		hdr.ipv4.dstAddr = (bit<32>)(hdr.ipv6.dstAddr << 96); 
	}
	
    table v4tobv6_tbl {
      key = { 
        ethType: exact;
      } 
      actions = { 
        v4_v6;
        v6_v4;
      }
      const entries = {
		(0x0800): v4_v6();
		(0x86DD): v6_v4();
      }

    }
    apply { 
      v4tobv6_tbl.apply(); 
    }
  }

  control micro_deparser(emitter em, pkt p, in v4tov6_hdr_t h) {
    apply { 
      em.emit(p, h.ipv4); 
      em.emit(p, h.ipv6); 
    }
  }
}

 
