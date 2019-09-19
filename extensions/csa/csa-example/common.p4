/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */
#include <core.p4>
#include <csa.p4>

struct empty_t {}
struct external_meta_t {
  bit<32> next_hop;
} 

cpackage l2(csa_packet_in pin, csa_packet_out po,
                inout csa_standard_metadata_t sm, egress_spec es,
                      in external_meta_t in_meta, out empty_t out_meta,
                      inout empty_t inout_meta) (/*ctor parameters*/);

cpackage l3(csa_packet_in pin, csa_packet_out po, 
                inout csa_standard_metadata_t sm, egress_spec es,
                in empty_t in_meta, out external_meta_t out_meta,
                inout empty_t inout_meta) (/*ctor parameters*/);

cpackage ecn(csa_packet_in pin, csa_packet_out po, 
                inout csa_standard_metadata_t sm, egress_spec es,
                in empty_t in_meta, out external_meta_t out_meta,
                inout empty_t inout_meta) (/*ctor parameters*/);


cpackage Layer2(csa_packet_in pin, csa_packet_out po,
                inout csa_standard_metadata_t sm, egress_spec es,
                in external_meta_t in_meta, out empty_t out_meta,
                inout empty_t inout_meta) (/*ctor parameters*/);
