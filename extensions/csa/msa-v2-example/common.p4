/*
 * Author: Hardik Soni, Myriana Rifai
 * Email: hks57@cornell.edu 
 *        myriana.rifai@nokia-bell-labs.com
 */


struct empty_t { }

struct eth_meta_t {
  bit<48> dmac;
  bit<48> smac;
  bit<16> ethType; 
}

struct swtrace_inout_t {
  bit<4> ipv4_ihl;
  bit<16> ipv4_total_len;
}

struct mplslr_inout_t {
  bit<16> eth_type;
  bit<16> next_hop;
}

cpackage ecnv4(pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout bit<16> etherType);
                 
cpackage ecnv6(pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout bit<16> etherType);
                 
cpackage L3v4(pkt p, im_t im, in empty_t ia, out bit<16> nh, 
                 inout empty_t ioa);
                 
cpackage L3v6(pkt p, im_t im, in empty_t ia, out bit<16> nh,
                 inout empty_t ioa);

cpackage Filter_L4(pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout bit<8> l4proto);
                 
cpackage Nat_L4(pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout bit<8> l4proto);

cpackage Nat_L3(pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout bit<16> etherType);

cpackage FilterL3_v4(pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout bit<16> etherType);
                 
cpackage FilterL3_v6(pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout bit<16> etherType);

cpackage Vlan(pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout bit<16> etherType);
                 
cpackage VXlan(pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout eth_meta_t ethhdr);

cpackage MplsLSR(pkt p, im_t im, in empty_t ia, out bit<16> nh,
                 inout mplslr_inout_t ioa);

cpackage MplsLR(pkt p, im_t im, in empty_t ia, out empty_t oa,
                 inout empty_t ioa);
                                  
cpackage SR_v4(pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout bit<16> etherType);
                 
cpackage SR_v6(pkt p, im_t im, in empty_t ia, out bit<16> oa, 
                 inout bit<8> nexthdr);
                 

                 
