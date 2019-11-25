/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024

struct meta_t {
  bit<1> change; 
}


header tcp_h {
  bit<16> srcPort;
  bit<16> dstPort;
  bit<128> unused;
}
struct nat_hdr_t {
  tcp_h tcp;
}

cpackage Nat_L4 : implements Unicast<nat_hdr_t, meta_t, 
                                     empty_t, empty_t, bit<8>> {
  parser micro_parser(extractor ex, pkt p, im_t im, out nat_hdr_t hdr, inout meta_t meta,
                        in empty_t ia, inout bit<8> l4proto) {
    state start {
      transition select(l4proto) {
        0x06: parse_tcp;
      }
    }
    state parse_tcp {
      ex.extract(p, hdr.tcp);
      transition accept;
    }
  }
  
control micro_control(pkt p, im_t im, inout nat_hdr_t hdr, inout meta_t m,
                          in empty_t ia, out empty_t oa, inout bit<8> ioa) {
    action change_srcPort(bit<16> srcPort) {
            hdr.tcp.srcPort = srcPort;
       }
    table nat_tbl{
    	key = {
    		m.change : exact;
    	}
    	actions = {
    		change_srcPort;
    	}
    	const entries = {
    	     1: change_srcPort(16w0x1F90);
    	}
    }
    
    apply {
      		nat_tbl.apply();
    }
  }
  control micro_deparser(emitter em, pkt p, in nat_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.tcp);
    }
  }
}

