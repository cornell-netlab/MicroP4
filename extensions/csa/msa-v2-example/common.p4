/*
 * Author: Hardik Soni, Myriana Rifai
 * Email: hks57@cornell.edu 
 *        myriana.rifai@nokia-bell-labs.com
 */


struct empty_t { }

struct swtrace_inout_t {
  bit<4> ipv4_ihl;
  bit<16> ipv4_total_len;
}

cpackage ecnv4(pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout bit<16> etherType);
                 
cpackage ecnv6(pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout bit<16> etherType);
                 
cpackage L3v4(pkt p, im_t im, in empty_t ia, out bit<16> nh, 
                 inout bit<16> etherType);
                 
cpackage L3v6(pkt p, im_t im, in empty_t ia, out bit<128> nh,
                 inout bit<16> etherType);

cpackage Filter_L4(pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout bit<8> l4proto);

cpackage Nat_L3(pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout bit<16> etherType);

cpackage Nat_L4(pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout bit<1> change, inout bit<8> l4proto);
/*
ecn (pkt p, inout sm_t sm  es_t es, in empty_t ia, out empty_t oa, 
    inout empty_t ioa);


swtrace (pkt p, inout sm_t sm  es_t es, in empty_t ia, out empty_t oa, 
    inout swtrace_inout_t ioa);
*/
