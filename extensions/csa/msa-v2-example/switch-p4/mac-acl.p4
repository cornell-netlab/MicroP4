/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"msa.p4"
#include"switch-common.p4"



header eth_h {
  bit<48> lkp_mac_sa;
  bit<48> lkp_mac_da;
  bit<3> lkp_pkt_type;
  bit<16> lkp_mac_type;
}

struct  mac_acl_hdr_t {
  eth_h mac_acl_eth;
}

cpackage mac_acl : implements Unicast<ecn_hdr_t, ecn_meta_t, empty_t, empty_t, bit<16>> {
  parser micro_parser(extractor ex, pkt p, im_t im, out mac_acl_hdr_t hdr, inout l2_meta_t meta,
                        in empty_t ia, inout bit<16> ethType) { //inout arg
    state start {
      ex.extract(p, hdr.eth);
      transition accept;
    }
  }

  control micro_control(pkt p, im_t im, inout mac_acl_hdr_t hdr, inout l2_meta_t m,in empty_t e,
                           out empty_t oa, inout bit<16> ioa) {

#if !defined(ACL_DISABLE) && !defined(L2_DISABLE)
action racl_deny(acl_stats_index, acl_copy, acl_copy_reason) {
    acl_metadata.racl_deny = TRUE;
    acl_metadata.acl_stats_index = acl_stats_index;
    acl_metadata.acl_copy = acl_copy;
    fabric_metadata.reason_code = acl_copy_reason;
}

action racl_permit(acl_stats_index,
                   acl_copy, acl_copy_reason) {
    acl_metadata.acl_stats_index = acl_stats_index;
    acl_metadata.acl_copy = acl_copy;
    fabric_metadata.reason_code = acl_copy_reason;
}

action racl_redirect_nexthop(nexthop_index, acl_stats_index,
                             acl_copy, acl_copy_reason) {
    acl_metadata.racl_redirect = TRUE;
    acl_metadata.racl_nexthop = nexthop_index;
    acl_metadata.racl_nexthop_type = NEXTHOP_TYPE_SIMPLE;
    acl_metadata.acl_stats_index = acl_stats_index;
    acl_metadata.acl_copy = acl_copy;
    fabric_metadata.reason_code = acl_copy_reason;
}

action racl_redirect_ecmp(ecmp_index, acl_stats_index,
                          acl_copy, acl_copy_reason) {
    acl_metadata.racl_redirect = TRUE;
    acl_metadata.racl_nexthop = ecmp_index;
    acl_metadata.racl_nexthop_type = NEXTHOP_TYPE_ECMP;
    acl_metadata.acl_stats_index = acl_stats_index;
    acl_metadata.acl_copy = acl_copy;
    fabric_metadata.reason_code = acl_copy_reason;
}
	table mac_acl {
	    key = {
	        acl_metadata.if_label : ternary;
	        acl_metadata.bd_label : ternary;
	
	        hdr.eth.lkp_mac_sa : ternary;
	        hdr.eth.lkp_mac_da : ternary;
	        hdr.eth.lkp_mac_type : ternary;
	    }
	    actions = {
	        nop;
	        acl_deny;
	        acl_permit;
	        acl_mirror;
	        acl_redirect_nexthop;
	        acl_redirect_ecmp;
	    }
	    size : INGRESS_MAC_ACL_TABLE_SIZE;
	}   
    apply {
      	if (DO_LOOKUP(ACL)) {
        	apply(mac_acl);
    	}
    }
#endif /* !ACL_DISABLE && !L2_DISABLE */
  }

  control micro_deparser(emitter em, pkt p, in ecn_hdr_t h) {
  #if !defined(ACL_DISABLE) && !defined(L2_DISABLE)
    apply { 
      em.emit(p, h.eth); 
    }
  #endif /* !ACL_DISABLE && !L2_DISABLE */
  }
}

