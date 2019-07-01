// Only used parameters are shown. e.g.,  "in" param and meta in l3 are not
// shown.
// in router in, out and inout params are not shown.

// l3 runtime interface
l3(pkt, inout sm_t, es_t, out bit<16>, inout bit<16>);
// l3.p4
parser P(extractor ex, pkt p, out l3_hdr_t hdr, inout bit<16> type) { //inout arg
  state start {
    transition select(type){
      0x0800: parse_ipv4;
    }
  }
  state parse_ipv4 {
    ex.extract(p, hdr.ipv4);
    transition accept;
  }
}
control Pipe(pkt p, inout l3_hdr_t hdr, out bit<16> nexthop, inout sm_t sm, es_t es) { // nexthop out arg
  action process(bit<16> nh) {
    hdrs.ipv4.ttl = hdr.ipv4 - 1;
    nexthop = nh;// setting out param
  }
  table ipv4_lpm_tbl {
    key = { hdr.ipv4.dstAddr : lpm } 
    actions = { process; }
  }
  apply { ipv4_lpm_tbl.apply(); }
}
control D(emitter em, pkt p, in l3_hdr_t h) {
  apply { em.emit(p, h.ipv4); }
}


// router using l3
parser P(extractor ex, pkt p, out hdr_t h, inout bit<16> meta) {
  state start {
    ex.extract(p, h.eth);
    meta = h.eth.ethType;    
    transition accept;
  }
}
control Pipe(pkt p, inout hdr_t h, inout sm_t sm, es_t es, inout bit<16> meta) {
  bit<16> nexthop_id;  l3 l3_inst;
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
    // nexthop_id is set by l3 program
    // meta could be useful in case of multiple ip layer protocol supported by
    // one program
    l3_inst.apply(p, sm, es, nexthop_id, meta);
    // if meta is changed, we set ethType here.
    h.eth.ethType = meta;

    forward_tbl.apply(); 
    if (sm.deq_qdepth > 100) // limit
      drop();
  }
}
control D(emitter em, pkt p, in hdr_t h) {
  apply { em.emit(p, h.eth); }
}
