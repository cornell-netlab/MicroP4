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


cpackage routerv6qos : implements OrchestrationSwitch<empty_t, empty_t, empty_t, 
                                              meta1_t, meta2_t> {

  control csa_pipe(csa_packet_in pin, csa_packet_out po, inout meta1_t meta, 
                 inout csa_standard_metadata_t sm, egress_spec es) {

        external_meta_t arg;

        l2() layer2;
        ipv6() ipv6layer;
        ecnv6() ecnlayer;
        csa_packet_out() ecn_po;
        csa_packet_out() ipv6_po;
        csa_packet_in() l2_pin;
        csa_packet_in() ipv6_pin;
        empty_t e;
        empty_t eio;

        apply{
        	ecnlayer.apply(pin, ecn_po, sm, es, e, arg , eio);
        	ecn_po.get_packet_in(ipv6_pin);
            ipv6layer.apply(ipv6_pin, ipv4_po, sm, es, e, arg, eio);
            ipv6_po.get_packet_in(l2_pin);
            layer2.apply(l2_pin, po, sm, es, arg, e, eio);
            
            
        }

    }                                              
}

routerv6qos() main;                                              
