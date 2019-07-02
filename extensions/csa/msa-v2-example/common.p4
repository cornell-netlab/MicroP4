struct empty_t { }

l3 (pkt p, inout sm_t sm  es_t es, in empty_t e, out bit<16> nexthop, 
    inout bit<16> etheType);


ecn (pkt p, inout sm_t sm  es_t es, in empty_t ia, out empty_t oa, 
    inout empty_t ioa);
