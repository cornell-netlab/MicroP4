/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"common.p4"

struct meta_t {

}

header ethernet_h {
  bit<48> dmac;
  bit<48> smac;
  bit<16> ethType; 
}

struct hdr_t {
  ethernet_h eth;
}

cpackage ModularVlan: implements Unicast<hdr_t, meta_t, 
                                            empty_t, empty_t, empty_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out hdr_t hdr, inout meta_t m,
                        in empty_t ia, inout empty_t ioa) {

    state start {
      ex.extract(p, hdr.eth);
      transition accept;
    }

  }

  control micro_control(pkt p, im_t im, inout hdr_t hdr, inout meta_t m,
                          in empty_t ia, out empty_t oa, inout empty_t ioa) {
    Vlan() vlan;
    bit<16> nhv4;
    bit<128> nhv6;
    L3v4() l3v4_i;
    L3v6() l3v6_i;
    action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
      hdr.eth.dmac = dmac;
      hdr.eth.smac = smac;
      im.set_out_port(port);
    }
    table forward_tbl {
      key = { nhv4 : lpm; nhv6 : lpm;} 
      actions = { forward; }
    }
    apply { 
    nhv4 = 16w10;
    nhv6 = 128w10;
    // vlan should return something more than ethType to decide if routing is
    // required or not
    if(hdr.eth.ethType==0x8100)
      vlan.apply(p, im, ia, oa, hdr.eth.ethType);
    
    // then, this block can go in an if condition.
    if (hdr.eth.ethType==0x0800)
      l3v4_i.apply(p, im, ia, nhv4, hdr.eth.ethType);
    else if (hdr.eth.ethType==0x86DD) 
      l3v6_i.apply(p, im, ia, nhv6, hdr.eth.ethType);

    forward_tbl.apply(); 
    }
  }

  control micro_deparser(emitter em, pkt p, in hdr_t hdr) {
    apply { 
      em.emit(p, hdr.eth); 
    }
  }
}

ModularVlan() main;


 
