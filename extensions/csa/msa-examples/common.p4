/*
 * Author: Hardik Soni, Myriana Rifai
 * Email: hks57@cornell.edu 
 *        myriana.rifai@nokia-bell-labs.com
 */


struct empty_t { }

struct vxlan_inout_t {
  bit<48> dmac;
  bit<48> smac;
  bit<16> ethType; 
}

struct swtrace_inout_t {
  bit<4> ipv4_ihl;
  bit<16> ipv4_total_len;
}

struct mplslr_inout_t {
  bit<16> next_hop;
  bit<16> eth_type;
}

struct vlan_inout_t {
	bit<48> dstAddr; 
	bit<16> invlan;
	bit<16> outvlan;
	bit<16> ethType;
}

struct sr6_inout_t {
  bit<16> totalLen;
  bit<8> nexthdr;
  bit<8> hoplimit;
  bit<128> srcAddr;
  bit<128> dstAddr;
}

struct acl_result_t {
  // hard drop can not be overridden
  bit<1> hard_drop;
  // soft drop can be overridden
  bit<1> soft_drop;
}

struct l3_inout_t {
  acl_result_t acl;
  bit<16> next_hop;
  bit<16> eth_type;
}

struct ipv4_acl_in_t {
  bit<32> sa;
  bit<32> da;
}

struct ipv6_acl_in_t {
  bit<128> sa;
  bit<128> da;
}
                 
cpackage IPv4(pkt p, im_t im, 
          in empty_t ia, out bit<16> nh, inout empty_t ioa);
          
cpackage ECN(pkt p, im_t im, 
          in empty_t ia, out empty_t oa, inout empty_t ioa);
          
cpackage IPv4toIPv6(pkt p, im_t im, 
          in empty_t ia, out empty_t oa, inout  bit<16> etherType);                    
                 
cpackage IPv4ACL(pkt p, im_t im, 
          in ipv4_acl_in_t ia, out empty_t oa, inout acl_result_t ioa);

cpackage IPv4NatACL(pkt p, im_t im, 
          in empty_t ia, out empty_t oa, inout acl_result_t ioa);

cpackage IPv6(pkt p, im_t im, 
          in empty_t ia, out bit<16> nh, inout empty_t ioa);

cpackage IPv6ACL(pkt p, im_t im, 
          in ipv6_acl_in_t ia, out empty_t oa, inout acl_result_t ioa);

cpackage IPv6NatACL(pkt p, im_t im, 
          in empty_t ia, out empty_t oa, inout acl_result_t ioa);

cpackage Vlan(pkt p, im_t im, 
          in empty_t ia, out empty_t oa, inout vlan_inout_t ethinfo);
          
cpackage MplsLR(pkt p, im_t im, 
          in empty_t ia, out empty_t oa, inout mplslr_inout_t ioa);

cpackage MplsLSR(pkt p, im_t im, 
          in empty_t ia, out bit<16> nh, inout bit<16> eth_type);
                                  
cpackage SRv4(pkt p, im_t im, 
          in empty_t ia, out bit<16> nh, inout empty_t ioa);
          
cpackage SR_v6(pkt p, im_t im, 
          in empty_t ia, out bit<16> nh, inout sr6_inout_t ioa);  
                  
cpackage SR_v6_Simple(pkt p, im_t im, 
          in empty_t ia, out empty_t oa, inout empty_t ioa);  

cpackage IPSRv4(pkt p, im_t im, 
          in empty_t ia, out bit<16> nh,  inout empty_t ioa);

cpackage L3(pkt p, im_t im, 
          in empty_t ia, out empty_t oa,  inout l3_inout_t ioa);

