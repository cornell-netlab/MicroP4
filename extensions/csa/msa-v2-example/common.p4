/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */


struct empty_t { }

struct swtrace_inout_t {
  bit<4> ipv4_ihl;
  bit<16> ipv4_total_len;
}

cpackage L3(pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout bit<16> etherType);

cpackage Filter_L4(pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout bit<8> l4proto);

/*
ecn (pkt p, inout sm_t sm  es_t es, in empty_t ia, out empty_t oa, 
    inout empty_t ioa);


swtrace (pkt p, inout sm_t sm  es_t es, in empty_t ia, out empty_t oa, 
    inout swtrace_inout_t ioa);
*/
