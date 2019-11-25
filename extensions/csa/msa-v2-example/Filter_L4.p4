/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024

struct filter_meta_t {
  bit<16> sport; 
  bit<16> dport;  
}


header udp_h {
  bit<16> sport; 
  bit<16> dport; 
}

header tcp_h {
  bit<16> sport; 
  bit<16> dport; 
}

struct callee_hdr_t {
  tcp_h tcp;
  udp_h udp;
}


cpackage Filter_L4 : implements Unicast<callee_hdr_t, filter_meta_t, 
                                     empty_t, empty_t, bit<8>> {
  parser micro_parser(extractor ex, pkt p, im_t im, out callee_hdr_t hdr, inout filter_meta_t meta,
                        in empty_t ia, inout bit<8> l4proto) {
    state start {
      transition select(l4proto) {
        0x06: parse_tcp;
        0x17: parse_udp;
      }
    }

    state parse_tcp {
      ex.extract(p, hdr.tcp);
      meta.sport=hdr.tcp.sport;
      meta.dport=hdr.tcp.dport;
      transition accept;
    }

    state parse_udp {
      ex.extract(p, hdr.udp);
      meta.sport=hdr.udp.sport;
      meta.dport=hdr.udp.dport;
      transition accept;
    }
  }
  
control micro_control(pkt p, im_t im, inout callee_hdr_t hdr, inout filter_meta_t m,
                          in empty_t ia, out empty_t oa, inout bit<8> ioa) {
    action drop_action() {
            im.set_out_port(0x00); // Drop packet
       }
    table filter_tbl{
    	key = {
    		m.sport : exact;
    		m.dport : exact;
    	}
    	actions = {
    		drop_action;
    	}
    	const entries = {
    	     (16w0x4000,_): drop_action();
    	     (_,16w0x4000): drop_action();
    	}
    }
    
    apply {
      		filter_tbl.apply();
    }
  }
  control micro_deparser(emitter em, pkt p, in callee_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.tcp);
      em.emit(p, hdr.udp);
    }
  }
}

