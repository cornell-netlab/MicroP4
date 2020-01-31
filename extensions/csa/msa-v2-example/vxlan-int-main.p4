/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include"msa.p4"
#include"common.p4"

struct meta_t { 
	bit<8> l4proto;
}

header ethernet_h {
  bit<48> dmac;
  bit<48> smac;
  bit<16> ethType; 
}


header eth_h {
  bit<48> dmac;
  bit<48> smac;
  bit<16> ethType; 
}

header ipv4_h {
  bit<4> version;
  bit<4> ihl;
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

header udp_h {
  bit<16> sport; 
  bit<16> dport; 
  bit<16> len;
  bit<16> checksum;
}


struct hdr_t {
  ethernet_h eth;
  ipv4_h ipv4;
  udp_h udp;
}

cpackage VXLANINT : implements Unicast<hdr_t, meta_t, 
                                            empty_t, empty_t, empty_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out hdr_t hdr, inout meta_t m,
                        in empty_t ia, inout empty_t ioa) {
    state start {
      ex.extract(p, hdr.eth);
    transition select(hdr.eth.ethType){
        0x8000: parse_ip;
      }
    }
    
    state parse_ip{
    	ex.extract(p, hdr.ipv4);
    	transition select(hdr.ipv4.protocol){
    		0x11: parse_udp;
    	}
    }
    
    state parse_udp{
    	ex.extract(p, hdr.udp);
    	transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout hdr_t hdr, inout meta_t m,
                          in empty_t ia, out empty_t oa, inout empty_t ioa) {
    bit<16> nh;
    IPv4() ipv4_i;
    IPv6() ipv6_i;
    INT() int_vxlan;
    action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
      hdr.eth.dmac = dmac;
      hdr.eth.smac = smac;
      im.set_out_port(port);
    }
    table forward_tbl {
      key = { nh : exact; } 
      actions = { forward; }
    }
    apply { 
      nh = 16w0;
	  if (hdr.eth.ethType == 0x0800)
        ipv4_i.apply(p, im, ia, nh, ioa);
      else if (hdr.eth.ethType == 0x86DD)
        ipv6_i.apply(p, im, ia, nh, ioa);     
      if (hdr.udp.dport == 4789)
     	int_vxlan.apply(p, im, ia, oa,ioa);
      forward_tbl.apply(); 
    }
  }

  control micro_deparser(emitter em, pkt p, in hdr_t hdr) {
    apply { 
      em.emit(p, hdr.eth);
      em.emit(p, hdr.ipv4); 
      em.emit(p, hdr.udp);
    }
  }
}

VXLANINT() main;


 
