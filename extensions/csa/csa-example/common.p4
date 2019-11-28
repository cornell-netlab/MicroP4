/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */
#include <core.p4>
#include <csa.p4>

struct empty_t {}
struct external_meta_t {
  bit<32> next_hop;
  bit<128> next_hopv6;
} 

cpackage l2(csa_packet_in pin, csa_packet_out po,
                inout csa_standard_metadata_t sm, egress_spec es,
                in external_meta_t in_meta, out empty_t out_meta,
                inout empty_t inout_meta) (/*ctor parameters*/);

cpackage ipv4l3(csa_packet_in pin, csa_packet_out po, 
                inout csa_standard_metadata_t sm, egress_spec es,
                in empty_t in_meta, out external_meta_t out_meta,
                inout empty_t inout_meta) (/*ctor parameters*/);
                
cpackage ipv6l3(csa_packet_in pin, csa_packet_out po, 
                inout csa_standard_metadata_t sm, egress_spec es,
                in empty_t in_meta, out external_meta_t out_meta,
                inout empty_t inout_meta) (/*ctor parameters*/);

cpackage ecnv4(csa_packet_in pin, csa_packet_out po, 
                inout csa_standard_metadata_t sm, egress_spec es,
                in empty_t in_meta, out external_meta_t out_meta,
                inout empty_t inout_meta) (/*ctor parameters*/);
                
cpackage ecnv6(csa_packet_in pin, csa_packet_out po, 
                inout csa_standard_metadata_t sm, egress_spec es,
                in empty_t in_meta, out external_meta_t out_meta,
                inout empty_t inout_meta) (/*ctor parameters*/);
                
cpackage filter(csa_packet_in pin, csa_packet_out po, 
                inout csa_standard_metadata_t sm, egress_spec es,
                in empty_t in_meta, out external_meta_t out_meta,
                inout empty_t inout_meta) (/*ctor parameters*/);
                
cpackage nat(csa_packet_in pin, csa_packet_out po, 
                inout csa_standard_metadata_t sm, egress_spec es,
                in empty_t in_meta, out external_meta_t out_meta,
                inout empty_t inout_meta) (/*ctor parameters*/);



