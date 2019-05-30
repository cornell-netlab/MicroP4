/*
 * This program describes a possible way to merge parsers of parser1.p4 and
 * parser2,p4. 
 * The solution can exist without recirculation, however number of headers and
 * variables will be huge.
 * Essentially, the parser is a result of cross-product between states
 * (fundamentally, transitions from key-fields in headers) of
 * parser1.p4's parser and parser2.p4's parser.
 *
 * Each header instances defined in parser1.p4 and parser2.p4 need to be
 * described using multiple possible combinations of headers in this program.
 * There exists multiple mappings between header fields of the merged program and
 * header fields of parser1,p4 and parser2,p4. This makes substitution of
 * headers of parser1.p4 and parser2.p4 non-trivial.
 * Without matching the key-fields in match+action tables, it is not possible to
 * identify the correct mapping for headers in parser1.p4 and parser2,p4
 * for a given packet.
 *
 * Not all the cross-products are listed here.
 * 
 */


#include <core.p4>
#include <v1model.p4>

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32


header p_ht {
  bit<2> f1;
  bit<4> kf; // = p1.a_ht.kf  --- 2-6 ---
  bit<2> f2;
}

header pb_ht {
  bit<4> f1; // --- 8-12 ---
}

header tb_ht {
  bit<4> f1; // --- 36-40 ---
}

header pc_ht {
  bit<4> f1; // --- 8-12 ---, 20-24, 28-32, 36-40, 44-48
  bit<4> f2; 
  bit<16> f3; 
}

header tc_ht {
  bit<8> f1; // --- 32-40 ---
}

header q_ht {
  bit<4> p2_a_kf; // = p2.a_ht.kf  --- 12-16 ---
  bit<2> p1_b_kf; // = p1.b_ht.kf  --- 16-18 ---
  bit<2> hlf; // = p1.b_ht.hlf  --- 18-20 ---
}

header sd_ht {
  bit<4> f1; // --- 20-24, 28-32, 36-40, 44-48
  bit<4> f2; 
  bit<4> f3; 
  bit<4> f4; 
}

header offset1_ht {
  bit<8> f1;
  bit<4> f2;
} 

header offset2_ht {
  bit<8> f1;
  bit<4> f2;
} 

header pb_0_b_00_ht {
  bit<4> p1cf1_p2bf1;
  bit<4> p1cf2_p2bf1;
  bit<8> p1cf2_p2bf2;
  bit<4> p1cf2_p2bkf;
}

header pb_0_b_01_ht {

}

header pb_0_c_00_ht {

}

header pb_0_c_01_ht {

}

struct headers {
  p_ht p;
  pb_ht pb;
  pc_ht pc;
  q_ht q;
  r_ht r;
  s1_ht s1;
  s2_ht s2;
  s3_ht s3;
}

parser ParserImpl(packet_in packet, out headers hdr, inout ingress_data_t meta, 
                  inout standard_metadata_t standard_metadata) {

  // Extracts 00 to 08 bits
  state start {
    packet.extract(hdr.p);
    transition select(hdr.p.kf) {
      0xb: parse_pb;  // parse for b of p1.b_ht;
      0xc: parse_pc;  // parse for c of p1.c_ht;
    }
  }

  // Extracts 08 to 20 bits
  state parse_pb {
    packet.extract(hdr.pb);
    packet.extract(hdr.q);
    transition select(hdr.q.hlf++hdr.q.p2_a_kf++hdr.q.p1_b_kf) {
      0b00 : parse_pb_0_b_00;
      0b00 : parse_pb_0_b_01;
      0b00 : parse_pb_0_c_00;
      0b00 : parse_pb_0_c_01;

      0b01 : parse_pb_1_b_00;
      0b01 : parse_pb_1_b_01;
      0b01 : parse_pb_1_c_00;
      0b01 : parse_pb_1_c_01;

      0b10 : parse_pb_2_b_00;
      0b10 : parse_pb_2_b_01;
      0b10 : parse_pb_2_c_00;
      0b10 : parse_pb_2_c_01;

      0b11 : parse_pb_3_b_00;
      0b11 : parse_pb_3_b_01;
      0b11 : parse_pb_3_c_00;
      0b11 : parse_pb_3_c_01;
    }
  }
  
  state parse_pb_0_b_00 {
    packet.extract(hdr.offset1); // p2.a.f3, p1.c.f1<12:>
    packet.extract(hdr.pb_0_b_00); // p2.b.f1, p1.c.f1<:4> p1.c.f2
  }
  state parse_pb_0_b_01 {
    packet.extract(hdr.offset2); // p2.a.f3, p1.d.f1<12:>
    packet.extract(hdr.pb_0_b_01); // p2.b.f1, p1.d.f1<:4> 
  }
  state parse_pb_0_c_00 {
    packet.extract(hdr.offset1); // p2.a.f3, p1.c.f1<12:>
    packet.extract(hdr.pb_0_c_00); // p2.c.f1<16:>, p1.c.f1<:4> p1.c.f2
  }
  state parse_pb_0_c_01 {
    packet.extract(hdr.offset2); // p2.a.f3, p1.d.f1<12:>
    packet.extract(hdr.pb_0_c_01); // p2.c.f1<16:>, p1.d.f1<:4>
  }



  state parse_pb_1_b_00 {
    packet.extract(hdr.vh1); // p2.a.f3<4:12>, p1.b.vlf<8>
    packet.extract(hdr...); // p2.a.f3<12:16>, p1.c.f1<4:>
    packet.extract(hdr.pb_1_b_00); //
  }
  state parse_pb_1_b_01 {
    packet.extract(hdr.vh1); // p2.a.f3<4:12>, p1.b.vlf<8>
    packet.extract(hdr...); // p2.a.f3<12:16>, p1.d.f1<4:>
    packet.extract(hdr.pb_1_b_01); //
  }
  state parse_pb_1_c_00 {
    packet.extract(hdr.vh1); // p2.a.f3<4:12>, p1.b.vlf<8>
    packet.extract(hdr...); // p2.a.f3<12:16>, p1.c.f1<4:>
    packet.extract(hdr.pb_1_c_00); //
  }
  state parse_pb_1_c_01 {
    packet.extract(hdr.vh1); // p2.a.f3<4:12>, p1.b.vlf<8>
    packet.extract(hdr...); // p2.a.f3<12:16>, p1.d.f1<4:>
    packet.extract(hdr.pb_1_c_01); //
  }


  state parse_pb_2_b_00 {
    packet.extract(hdr.vh2); // p2.a.f3<4:16>, p1.b.vlf<12:>
    packet.extract(hdr.pb_2_b_00); //
  }
  state parse_pb_2_b_01 {
    packet.extract(hdr.vh2); // p2.a.f3<4:16>, p1.b.vlf<12:>
    packet.extract(hdr.pb_2_b_01); //
  }
  state parse_pb_2_c_00 {
    packet.extract(hdr.vh2); // p2.a.f3<4:16>, p1.b.vlf<12:>
    packet.extract(hdr.pb_2_c_00); //
  }
  state parse_pb_2_c_01 {
    packet.extract(hdr.vh2); // p2.a.f3<4:16>, p1.b.vlf<12:>
    packet.extract(hdr.pb_2_c_01); //
  }

  state parse_pb_3_b_00 {
    packet.extract(hdr.vh2); // p2.a.f3<4:16>, p1.b.vlf<12:>
    packet.extract(hdr.pb_3_b_00); //
  }
  state parse_pb_3_b_01 {
    packet.extract(hdr.vh2); // p2.a.f3<4:16>, p1.b.vlf<12:>
    packet.extract(hdr.pb_3_b_01); //
  }
  state parse_pb_3_c_00 {
    packet.extract(hdr.vh2); // p2.a.f3<4:16>, p1.b.vlf<12:>
    packet.extract(hdr.pb_3_c_00); //
  }
  state parse_pb_3_c_01 {
    packet.extract(hdr.vh2); // p2.a.f3<4:16>, p1.b.vlf<12:>
    packet.extract(hdr.pb_3_c_01); //
  }



  // Extracts 08 to 32 bits
  state parse_pc {
    packet.extract(hdr.pc);
    transition select(hdr.pc.f2) {
      0xb: parse_qb;
      0xc: parse_qc;
    }
  }

  state parse_pb_bc {
    transition select( ) {
    }
  }

  state parse_pb_bd {
    transition select( ) {
    }
  }

  state parse_pb_cc {
    transition select( ) {
    }
  }

  state parse_pb_cd {
    transition select( ) {
    }
  }


}

