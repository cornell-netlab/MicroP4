/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */


struct acl_metadata_t {
       bit<1> acl_deny;                          /* ifacl/vacl deny action */
       bit<1> acl_copy;                          /* generate copy to cpu */
       bit<1> racl_deny;                         /* racl deny action */
       bit<16> acl_nexthop;                      /* next hop from ifacl/vacl */
       bit<16> racl_nexthop;                     /* next hop from racl */
       bit<1> acl_nexthop_type;                  /* ecmp or nexthop */
       bit<1> racl_nexthop_type;                 /* ecmp or nexthop */
       bit<1> acl_redirect;                    /* ifacl/vacl redirect action */
       bit<1> racl_redirect;                     /* racl redirect action */
       bit<16> if_label;                         /* if label for acls */
       bit<16> bd_label;                         /* bd label for acls */
       bit<14> acl_stats_index;                  /* acl stats index */

}

struct l2_meta_t { 
	   bit<16> l2_nexthop;                       /* next hop from l2 */
	   bit<1> l2_nexthop_type;                   /* ecmp or nexthop */
	   bit<1> l2_redirect;                       /* l2 redirect action */
	   bit<1> l2_src_miss;                       /* l2 source miss */
	   bit<IFINDEX_BIT_WIDTH> l2_src_move;       /* l2 source interface mis-match */
	   bit<10> stp_group;                         /* spanning tree group id */
	   bit<3> stp_state;                         /* spanning tree port state */
	   bit<16> bd_stats_idx;                     /* ingress BD stats index */
	   bit<1> learning_enabled;                  /* is learning enabled */
	   bit<1> port_vlan_mapping_miss;            /* port vlan mapping miss */
	   bit<1> same_if_check;     /* same interface check */
}
struct qos_metadata_t {
        bit<8> outer_dscp;                        /* outer dscp */
        bit<3> marked_cos;                        /* marked vlan cos value */
        bit<8> marked_dscp;                       /* marked dscp value */
        bit<3> marked_exp;                        /* marked exp value */
}

struct i2e_metadata_t {
        bit<32> ingress_tstamp;
        bit<16> mirror_session_id;
}

struct empty_t { }

cpackage mac_acl(pkt p, im_t im, in acl_metadata_t ia, out acl_metadata_t oa, 
                 inout bit<16> etherType);