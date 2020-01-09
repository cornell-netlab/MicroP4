/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024

struct natl3_meta_t {
	bit<1> change; 
}

header ipv4_h {
  bit<4> version;
  bit<4> ihl;
  bit<8> diffserv;
  bit<8> ecn;
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

struct hdr_t {
  ipv4_h ipv4;
}

cpackage Nat_L3 : implements Unicast<hdr_t, natl3_meta_t, 
                                     empty_t, empty_t, bit<16>> {
  parser micro_parser(extractor ex, pkt p, im_t im, out hdr_t hdr, inout natl3_meta_t meta,
                        in empty_t ia, inout bit<16> etherType) {
    state start {
      transition select(etherType) {
        0x0800: parse_ipv4;
      }
    }

    state parse_ipv4 {
      ex.extract(p, hdr.ipv4);
      transition accept;
    }

  }
  
control micro_control(pkt p, im_t im, inout hdr_t hdr, inout natl3_meta_t m,
                          in empty_t ia, out empty_t oa, inout bit<16> etherType) {
    
    Nat_L4() nat4_i;
    action change_srcAddr() {
            m.change = 1;
       }
   table srcAddr_tbl{
    	key = {
    		hdr.ipv4.srcAddr : lpm;
    	}
    	actions = {
    		change_srcAddr;
    	}
    	const entries = {
    	     0x0a000200 &&& 0xffffff00: change_srcAddr();
    	}
   }
    
    apply {
    srcAddr_tbl.apply();
    nat4_i.apply(p, im, ia, oa, hdr.ipv4.protocol);
    }
  }
  control micro_deparser(emitter em, pkt p, in hdr_t hdr) {
    apply { 
      em.emit(p, hdr.ipv4);
    }
  }
}
