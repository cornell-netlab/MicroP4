/*
 * This is program "p1" describing a parser with variable header along with DAG.
 * The structure of the parser is following.
 *         A
 *     b/     \c
 *     B-- 0 --C
 *     |1
 *     D
 *
 *     A,B,C and D are headers described using a_ht, b_ht, c_ht and d_ht in the
 *     program.
 *
 * This parser is merged with the parser of program "parser2.p4" and its
 * possible resultant parser is described in "merged_parser1-2.p4"
 *
 * In this program, variable header can be unrolled by creating a select key
 * field on header length field ("hlf" in b_ht) with select cases of all possible
 * values.
 */

#include <core.p4>
#include <v1model.p4>

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32

header a_ht {
  bit<2> f1; 
  bit<4> kf; 
  bit<2> f2; 
}

header b_ht {
  bit<4> f1; 
  bit<4> f2; 
  bit<2> kf; 
  bit<2> hlf;
  varbit<320> vf;
}

header c_ht {
  bit<16> f1; 
  bit<16> f2; 
}

header d_ht {
  bit<16> f1;

struct headers {
  a_ht a;
  b_ht b;
  c_ht c;
  d_ht d;
}

// required metadata of struct of struct type
struct ingress_data_t {
  bit<12> id;
}

parser ParserImpl(packet_in packet, out headers hdr, inout ingress_data_t meta, 
                  inout standard_metadata_t standard_metadata) {
  state start {
    packet.extract(hdr.a);
    transition select(hdr.a.kf) {
      0xb: parse_b;
      0xc: parse_c;
    }
  }

  state parse_b {
    packet.extract(hdr.b);
    transition select(hdr.b.kf) {
      0b00: parse_c;
      0b01: parse_d;
      default: accept
    }
  }

  state parse_c {
    packet.extract(hdr.c);
    transition accept;
  }

  state parse_d {
    packet.extract(hdr.d);
    transition accept;
  }

}
   
control DeparserImpl(packet_out packet, in headers hdr) {
  apply {
  }
}


control ingress(inout headers hdr, inout ingress_data_t meta, inout 
                standard_metadata_t standard_metadata) {
}

control egress(inout headers hdr, inout ingress_data_t meta, 
               inout standard_metadata_t standard_metadata) {
 apply { 
  // This ingress-egress processing is enforced by the switch architecture.
  // Composition should be done on control flow graph representation.
 }
}

control verifyChecksum(inout headers hdr, inout ingress_data_t meta) {
  apply { }
}

control computeChecksum(inout headers hdr, inout ingress_data_t meta) {
  apply { }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(),
         DeparserImpl()) main;
