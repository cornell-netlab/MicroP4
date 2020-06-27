#include <core.p4>
#include <csa.p4>
#include "common.ip4"




struct L2L3_user_metadata_t {}
struct L2L3_psm_t {}

cpackage L2L3 : implements OrchestrationSwitch<empty_t, empty_t, empty_t, 
                                              L2L3_user_metadata_t, L2L3_psm_t> {

    control csa_pipe(csa_packet_in pin, csa_packet_out po, inout L2L3_user_metadata_t meta, 
                 inout csa_standard_metadata_t sm, egress_spec es) {

        external_meta_t arg;

        Layer2() l2;
        Layer3() l3;
        csa_packet_out() l3_po;
        csa_packet_in() l2_pin;
        empty_t e;
        empty_t eio;

        apply{
            l3.apply(pin, l3_po, sm, es, e, arg, eio);
            l3_po.get_packet_in(l2_pin);
            l2.apply(l2_pin, po, sm, es, arg, e, eio);
        }

    }
}

L2L3() main;
