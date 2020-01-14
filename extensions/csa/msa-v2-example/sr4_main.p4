/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

#define TABLE_SIZE 1024

struct sr_meta_t {

}


header ethernet_h {
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

struct sr_hdr_t {
  ethernet_h eth;
  ip_h  ip;
}

// need to check the ip header for source routing option
// if option exists then check that the router is in the list of source routing list
// nexthop in the sr list would be the next hop 
cpackage SR4_main : implements Unicast<sr_hdr_t, sr_meta_t, 
                                     empty_t, empty_t, bit<16>> {
  parser micro_parser(extractor ex, pkt p, im_t im, out sr_hdr_t hdr, inout sr_meta_t meta,
                        in empty_t ia, inout bit<16> ethType) {          
    state start {
    ex.extract(p, hdr.eth);
      transition select(ethType) {
        0x0800: parse_ip;
      }
    }

    state parse_ip {
      ex.extract(p, hdr.ip);
      transition accept;
    }

  }
  
control micro_control(pkt p, im_t im, inout sr_hdr_t hdr, inout sr_meta_t m,
                          in empty_t ia, out empty_t oa, inout bit<16> ioa) {
                          
	SR_v4() srv4;    
	L3v4() l3_i;     
	bit<16> nh;
	action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
      hdr.eth.dmac = dmac;
      hdr.eth.smac = smac;
      im.set_out_port(port);
    }
    table forward_tbl {
      key = { nh : lpm; } 
      actions = { forward; }
    }                 
 // create main sr table 
 // classical forwarding ->done
    // if hlen>20 check src routing and set next hop based on that 
    // else perform l3v4 routing 
    // perform forwarding 
    apply {
    	if (hdr.ip,hlen>20)
    		srv4.apply(p, im, ia, oa, main_hdr.eth.ethType);
    	else if (hdr.eth.ethType == 0x0800)
    		l3_i.apply(p, im, ia, nh, ioa);
      	forward_tbl.apply();
    }
  }
  control micro_deparser(emitter em, pkt p, in sr_hdr_t hdr) {
    apply { 
      em.emit(p, hdr.ip);
    }
  }
}

SR4_main() main;