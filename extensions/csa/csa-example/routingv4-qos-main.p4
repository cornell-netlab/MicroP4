/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */

#include"csa.p4"
#include"common.p4"


struct meta1_t { 
}

struct meta2_t { 
}


cpackage router : implements OrchestrationSwitch<empty_t, empty_t, empty_t, 
                                              meta1_t, meta2_t> {

  control csa_pipe(csa_packet_in pin, csa_packet_out po, inout meta1_t meta, 
                 inout csa_standard_metadata_t sm, egress_spec es) {

        external_meta_t arg;

        l2() layer2;
        l3() layer3;
        ecn() ecnlayer;
        csa_packet_out() ecn_po;
        csa_packet_out() l3_po;
        csa_packet_in() l2_pin;
        csa_packet_in() l3_pin;
        empty_t e;
        empty_t eio;

        apply{
        	ecnlayer.apply(pin, ecn_po, sm, es, e, arg , eio);
        	ecn_po.get_packet_in(l3_pin);
            layer3.apply(l3_pin, l3_po, sm, es, e, arg, eio);
            l3_po.get_packet_in(l2_pin);
            layer2.apply(l2_pin, po, sm, es, arg, e, eio);
            
            
        }

    }                                              
}

router() main;                                              
