/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include"msa.p4"
#include"common.p4"

struct meta_t { }

header ethernet_h {
  bit<48> dmac;
  bit<48> smac;
  bit<16> ethType; 
}

struct hdr_t {
  ethernet_h eth;
}

cpackage MicroP4Switch : implements Unicast<hdr_t, meta_t, 
                                            empty_t, empty_t, empty_t> {
  parser micro_parser(extractor ex, pkt p, im_t im, out hdr_t hdr, inout meta_t meta,
                        in empty_t ia, inout empty_t ioa) {
    state start {
      ex.extract(p, hdr.eth);
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout hdr_t hdr, inout meta_t m,
                          in empty_t ia, out empty_t oa, inout empty_t ioa) {
    L3() l3_i;
    l3_inout_t l3ioa;

    action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
      hdr.eth.dmac = dmac;
      hdr.eth.smac = smac;
      im.set_out_port(port);
    }
    table forward_tbl {
      key = { l3ioa.next_hop : exact; } 
      actions = { forward; }
    }
    apply { 
      l3ioa.next_hop = 16w0;
      l3ioa.eth_type = hdr.eth.ethType;
      l3ioa.acl.hard_drop = 1w0;
      l3ioa.acl.soft_drop = 1w0;
      if (l3ioa.eth_type == 0x0800) {
        l3_i.apply(p, im, ia, oa, l3ioa);
        if (l3ioa.acl.hard_drop == 1w0 && l3ioa.acl.soft_drop == 1w0)
          forward_tbl.apply(); 
        else
          im.drop();
      } 
      /*
      if (im.get_value(metadata_fields_t.QUEUE_DEPTH_AT_DEQUEUE) == (bit<32>)64) {
          im.drop();
      }
      */
    }
  }

  control micro_deparser(emitter em, pkt p, in hdr_t hdr) {
    apply { 
      em.emit(p, hdr.eth); 
    }
  }
}

MicroP4Switch() main;


 
