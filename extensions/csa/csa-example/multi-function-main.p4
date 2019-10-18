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


cpackage multifunction : implements OrchestrationSwitch<empty_t, empty_t, empty_t, 
                                              meta1_t, meta2_t> {

  control csa_pipe(csa_packet_in pin, csa_packet_out po, inout meta1_t meta, 
                 inout csa_standard_metadata_t sm, egress_spec es) {

        external_meta_t arg;

        filter() filterlayer;
        nat() natlayer;
        ecn() ecnlayer;
        l3() layer3;
        l2() layer2;
        csa_packet_out() filter_po;
        csa_packet_out() nat_po;
        csa_packet_out() ecn_po;
        csa_packet_out() l3_po;
        csa_packet_in() nat_pin;
        csa_packet_in() ecn_pin;
        csa_packet_in() l3_pin;
        csa_packet_in() l2_pin;
        empty_t e;
        empty_t eio;

        apply{
            filterlayer.apply(pin, filter_po, sm, es, e, arg , eio);
        	filter_po.get_packet_in(nat_pin);
        	natlayer.apply(nat_pin, nat_po, sm, es, e, arg , eio);
        	nat_po.get_packet_in(ecn_pin);
        	ecnlayer.apply(ecn_pin, ecn_po, sm, es, e, arg , eio);
        	ecn_po.get_packet_in(l3_pin);
            layer3.apply(l3_pin, l3_po, sm, es, e, arg, eio);
            l3_po.get_packet_in(l2_pin);
            layer2.apply(l2_pin, po, sm, es, arg, e, eio);
            
            
        }

    }                                              
}

multifunction() main;                                              