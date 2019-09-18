/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"csa.p4"
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


cpackage router : implements OrchestrationSwitch<empty_t, empty_t, empty_t, 
                                              meta_t, meta_t> {

  control csa_pipe(csa_packet_in pin, csa_packet_out po, inout L2L3_user_metadata_t meta, 
                 inout csa_standard_metadata_t sm, egress_spec es) {

        external_meta_t arg;

        l2() layer2;
        l3() layer3;
        ecn() ecnlayer;
        csa_packet_out() l3_po;
        csa_packet_out() l2_po;
        csa_packet_in() l2_pin;
        csa_packet_in() ecn_pin;
        empty_t e;
        empty_t eio;

        apply{
            layer3.apply(pin, l3_po, sm, es, e, arg, eio);
            l3_po.get_packet_in(l2_pin);
            layer2.apply(l2_pin, po, sm, es, arg, e, eio);
            l2_po.get_packet_in(ecn_in);
            ecnlayer.apply(ecn_in, po, sm, es, arg, e, eio);
        }

    }                                              
}

router() main;                                              