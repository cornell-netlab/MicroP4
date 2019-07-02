#include"msa-v2.p4"
#include"common.p4"

struct ecn_meta_t { }
struct empty_t { }

const bit<19> ECN_THRESHOLD = 10;

header ipv4_h {
  bit<4> version;
  bit<4> ihl;
  bit<6> diffserv;
  bit<8> ecn;
  bit<16> totalLen;
  bit<16> identification;
  bit<3> flags;
  bit<13> fragOffset;
  bit<8> ttl;
  bit<8> protocol;
  bit<16> hdrChecksum;
  bit<16> srcAddr;
  bit<16> dstAddr; 
}

struct ecn_hdr_t {
  ipv4_h ipv4;
}

cpackage ecn : implements Unicast<ecn_hdr_t, ecn_meta_t, empty_t, bit<16>, bit<16>> {
  parser unicast_parser(extractor ex, pkt p, out ecn_hdr_t hdr, inout ecn_meta_t meta,
                        in empty_t ia, inout bit<16> etheType) { //inout arg
    state start {
      transition select(ethType){
        0x0800: parse_ipv4;
      }
    }
    state parse_ipv4 {
      ex.extract(p, hdr.ipv4);
      transition accept;
    }
  }

  control unicast_control(pkt p, inout ecn_hdr_t hdr, inout ecn_meta_t m, inout sm_t sm, 
                          es_t es, in empty_t ia, out empty_t oa, inout empty_t ioa) {

    swtrace_inout_t swarg;
    swtrace swtrace_inst;
    empty_t ia;
    empty_t oa;
    apply {
      swarg.ipv4_ihl = hdr.ipv4.ihl;
      swarg.ipv4_total_len = hdr.ipv4.totalLen;


      if (hdr.ipv4.ecn == 1 || hdr.ipv4.ecn == 2) {
        if (standard_metadata.enq_qdepth >= ECN_THRESHOLD){
          hdr.ipv4.ecn = 3;
        }
      }
      swtrace_inst.apply(p, sm, es, ia, oa, swarg);
    }
  }

  control unicast_deparser(emitter em, pkt p, in ecn_hdr_t h) {
    apply { 
      em.emit(p, h.ipv4); 
    }
  }
}

