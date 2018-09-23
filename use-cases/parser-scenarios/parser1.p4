#include <core.p4>
#include <v1model.p4>

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32

header a_ht {
  bit<2> f1; // p.f1
  bit<4> kf; // p.kf
  bit<2> f2; // p.f2
}

header b_ht {
  bit<4> f1; // pb.f1
  bit<4> f2; // q.p2_a_kf
  bit<2> kf; // q.p1_b_kf
  bit<2> hlf; // q.hlf   // length field * 8. create 2^2 states 
  varbit<320> vf;
}


/*************************
header b0_ht {
  bit<2> hlf; // 0 length
}

header b1_ht {
  bit<8> vf1; // vh1.f + vh2.f
}

header b2_ht {
  bit<16> vf2; // vh1.f + vh2.f + vh3.f
}

header b3_ht {
  bit<24> vf3;
}
*************************/


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
