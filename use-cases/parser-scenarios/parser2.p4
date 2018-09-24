/*
 * This is program "p2" describing a parser with DAG structure.
 * The structure of the parser is following.
 *          A
 *      b/     \c
 *      B-- 1 --C
 *
 *      A,B & C are headers described using a_ht, b_ht and c_ht in the
 *      program.
 *
 * This parser is merged with the parser of program "parser2.p4" and its
 * possible resultant parser is described in "merged_parser1-2.p4"
 */


#include <core.p4>
#include <v1model.p4>

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32

header a_ht {
  bit<4> f1; 
  bit<8> f2; 
  bit<4> kf; 
  bit<16> f3; 
}

header b_ht {
  bit<8> f1; //(sd.f4+tb.f1)/tc.f1/(sd.f2+sd.f3)/(vh4.f+sd.f1)/(vh4.f+vh5.f)
  bit<8> f2;
  bit<4> kf;
}

header c_ht {
  bit<32> f1;
  bit<32> f2;
}

struct headers {
  a_ht a;
  b_ht b;
  c_ht c;
}

// required metadata of struct of struct type
struct ingress_data_t {
  bit<1> b;
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
      0x1: parse_c;
      default: accept
    }
  }

  state parse_c {
    packet.extract(hdr.c);
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

