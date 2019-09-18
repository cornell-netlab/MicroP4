/*
 * Author: Myriana Rifai
 * Email: myriana.rifai@nokia-bell-labs.com
 */


struct empty_t { }

struct swtrace_inout_t {
  bit<4> ipv4_ihl;
  bit<16> ipv4_total_len;
}


l2 (csa_packet_in p, inout csa_standard_metadata_t csm, es_t es, in empty_t a, out empty_t oa, inout empty_t ioa);

l3 (csa_packet_in p, inout csa_standard_metadata_t csm, es_t es, in empty_t a, out empty_t oa, inout empty_t ioa);


ecn (csa_packet_in p, inout csa_standard_metadata_t csm, es_t es, in empty_t ia, out empty_t oa, 
    inout empty_t ioa);


swtrace (csa_packet_in p, inout csa_standard_metadata_t csm, es_t es, in empty_t ia, out empty_t oa, 
    inout swtrace_inout_t ioa);
