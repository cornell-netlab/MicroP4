/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include"msa-v2.p4"
#include"common.p4"

header ethernet_h {
  bit<48> dstAddr;
  bit<48> srcAddr;
  bit<16> etherType;
}

struct hdr_t {
  ethernet_h eth;
}

struct meta_t { 
}

/*
l3 (pkt p, inout sm_t sm  es_t es, in empty_t e, out bit<16> nexthop, 
    inout bit<16> etheType);
*/

cpackage router : implements Unicast<hdr_t, meta_t, empty_t, empty_t, empty_t> {

  parser unicast_parser(extractor ex, pkt p, out hdr_t h, inout meta_t meta, 
                        in empty_t ia, inout empty_t ioa) {
    state start {
      ex.extract(p, h.eth);
      transition accept;
    }
  }

  control unicast_control(pkt p, inout hdr_t h, inout meta_t meta, inout sm_t sm,
                          es_t es, in empty_t ia, out empty_t oa, inout empty_t ioa) {
    
    bit<16> nexthop_id;  
    empty_t ia;
    empty_t oa;
    empty_t ioa;
    l3 l3_inst;
    ecn ecn_inst;
    action drop () {}           
    action forward(bit<48> dmac, bit<48> smac, bit<8> port) {
        h.eth.dstAddr = dmac;
        h.eth.srcAddr = smac;
        sm.out_port = port;    
    }
    table forward_tbl {
      key = { nexthop_id : exact; } 
      actions = { process; drop; }
    }
    apply {
      l3_inst.apply(p, sm, es, ia, nexthop_id, h.eth.ethType);
     
      forward_tbl.apply(); 
      ecn_inst.apply(p, sm, es, ia, oa, ioa);

    }
  }

  control unicast_deparser(emitter em, pkt p, in hdr_t h) {
    apply {
      em.emit(p, h.eth); 
    }
  }

}
