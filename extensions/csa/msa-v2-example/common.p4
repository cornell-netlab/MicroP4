/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */


struct empty_t { }

struct swtrace_inout_t {
  bit<4> ipv4_ihl;
  bit<16> ipv4_total_len;
}

/*
l3 (pkt p, inout sm_t sm  es_t es, in empty_t e, out bit<16> nexthop, 
    inout bit<16> etheType);


ecn (pkt p, inout sm_t sm  es_t es, in empty_t ia, out empty_t oa, 
    inout empty_t ioa);


swtrace (pkt p, inout sm_t sm  es_t es, in empty_t ia, out empty_t oa, 
    inout swtrace_inout_t ioa);
*/
