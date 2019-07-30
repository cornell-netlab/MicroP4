/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include"msa-v2.p4"
#include"common.p4"

const bit<5>  IPV4_OPTION_MRI = 31;

header swt_ipv4_option_t {
  bit<1> copyFlag;
  bit<2> optClass;
  bit<5> option;
  bit<8> optionLength;
}

header swt_mri_t {
  bit<16>  count;
}

header switch_t {
  bit<32>  swid;
  qdepth_t    qdepth;
}

struct swtrace_hdr_t {
  swt_ipv4_option_t ipv4_option;
  swt_mri_t mri;
  switch_t[9] swtraces;
}


struct swtrace_meta_t {
  bit<16> remaining;
  bit<16> count;
}

cpackage swtrace : implements Unicast<swtrace_hdr_t, swtrace_meta_t, empty_t, 
                                      empty_t, empty_t> {

  parser unicast_parser(extractor ex, pkt p, out swtrace_hdr_t hdr, inout swtrace_meta_t meta,
                        in empty_t ia, inout swtrace_inout_t ioa) { //inout arg

    state start {
      packet.extract(hdr.ipv4_option);
      transition select(hdr.ipv4_option.option) {
        IPV4_OPTION_MRI: parse_mri;
        default: accept;
      }
    }

    state parse_mri {
      packet.extract(hdr.mri);
      meta.remaining = hdr.mri.count;
      transition select(meta.remaining) {
        0 : accept;
        default: parse_swtrace;
      }
    }

    state parse_swtrace {
      packet.extract(hdr.swtraces.next);
      meta.remaining = meta.remaining  - 1;
      transition select(meta.remaining) {
        0 : accept;
        default: parse_swtrace;
      }
    }

  }

  control unicast_control(pkt p, inout swtrace_hdr_t hdr, inout swtrace_meta_t m, 
                          inout sm_t sm, es_t es, in empty_t e, out empty_t oa, 
                          inout swtrace_inout_t ioa) {

    action add_swtrace(switchID_t swid) { 
      hdr.mri.count = hdr.mri.count + 1;
      hdr.swtraces.push_front(1);
      // According to the P4_16 spec, pushed elements are invalid, so we need
      // to call setValid(). Older bmv2 versions would mark the new header(s)
      // valid automatically (P4_14 behavior), but starting with version 1.11,
      // bmv2 conforms with the P4_16 spec.
      hdr.swtraces[0].setValid();
      hdr.swtraces[0].swid = swid;
      hdr.swtraces[0].qdepth = es.get_value(DEQ_QDEPTH);
 
      ioa.ipv4_ihl = ioa.ipv4_ihl + 2;
      hdr.ipv4_option.optionLength = hdr.ipv4_option.optionLength + 8; 
      ioa.ipv4_total_len = ioa.ipv4_total_len + 8;
    }

    table swtrace {
      actions = { 
        add_swtrace; 
        NoAction; 
      }
      default_action = NoAction();      
    }
    apply {
      if (hdr.mri.isValid()) {
          swtrace.apply();
      }
    }
  }

  control unicast_deparser(emitter em, pkt p, in swtrace_hdr_t h) {
    apply { 
      em.emit(p, h.ipv4_option); 
      em.emit(p, h.mri); 
      em.emit(p, h.swtraces); 
    }
  }
}

