#include <core.p4>
#include <v1model.p4>

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32
#define MAX_MPLS_LABELS 20


header Ethernet_h {
  bit<48> dstAddr;
  bit<48> srcAddr;
  bit<16> etherType;
}

header IPv4_h {
  bit<4> version;
  bit<4> ihl;
  bit<8> diffserv;
  bit<16> totalLen;
  bit<16> identification;
  bit<3> flags;
  bit<13> fragOffset;
  bit<8> ttl;
  bit<8> protocol;
  bit<16> hdrChecksum;
  bit<32> srcAddr;
  bit<32> dstAddr;
}

struct Parsed_headers {
  Ethernet_h ethernet;
  IPv4_h ip;
  MPLS_h[MAX_MPLS_LABELS] mpls_lbls;

}

error { 
  IPv4IncorrectVersion,
  IPv4OptionsNotSupported
}


struct ingress_metadata_t {
  bit<32> nexthop;
  bit<8> if_index;
  bit<4> num_mpls_labels;
}


parser TopParser(packet_in packet, out Parsed_headers ph, 
                 inout ingress_metadata_t meta, 
                 inout standard_metadata_t standard_metadata) {

  // To send out ARP replies, CP can inject packet
  state start {
    transition parse_ethernet;
  }

  // checksum and local variable intialization
  state parse_ethernet {
    packet.extract(ph.ethernet);
    meta.num_mpls_labels = 0;
    transition select (ph.ethernet.etherType) {
      0x0800: parse_ipv4;
      0x8847: parse_mpls;
    }
  }

  state parse_mpls {
    packet.extract(ph.mpls_lbls.next);
    meta.num_mpls_labels = meta.num_mpls_labels + 1;
    transition select(ph.mpls_lbls.last.bos) {
      0: parse_mpls;
      1: parse_ipv4;
    }
  }

  state parse_ipv4 {
    packet.extract(ph.ip);
    verify(ph.ip.version == 4w4, error.IPv4IncorrectVersion);
    verify(ph.ip.ihl == 4w5, error.IPv4OptionsNotSupported);
    transition accept;
  }
}


control ingress(inout Parsed_headers headers, inout ingress_metadata_t  meta,
                inout standard_metadata_t standard_metadata) {

  action pop_mpls_label(bit<20> label) {
    // mpls_lbls[meta.num_mpls_labels].setInvalid();
    headers.mpls_lbls[meta.num_mpls_labels].setInvalid();
  }

  action push_mpls_label(bit<20> label, bit<3> tc, bit<1> bos) {
     
  }

  table ip_to_mpls_lbl {
    key = {
      headers.ip.dstAddr: exact;
      headers.ip.srcAddr: exact;
    }
    actions = {
      push_mpls_label;
      pop_mpls_label;
    }
  }

  apply {
    ip_to_mpls_lbl.apply();
  }
}


control egress(inout Parsed_headers headers, inout ingress_metadata_t meta,
                inout standard_metadata_t standard_metadata) {
  apply {
  }
}

// deparser section
control DeparserImpl(packet_out packet, in Parsed_headers headers) {
  apply {
    packet.emit(headers.ethernet);
    packet.emit(headers.ip);
  }
}



control verifyChecksum(inout Parsed_headers p, inout ingress_metadata_t meta) {
  apply {
    verify_checksum(true, 
    { p.ip.version, 
      p.ip.ihl, 
      p.ip.diffserv, 
      p.ip.totalLen, 
      p.ip.identification, 
      p.ip.flags, 
      p.ip.fragOffset, 
      p.ip.ttl, 
      p.ip.protocol,
      p.ip.srcAddr, 
      p.ip.dstAddr
    }, p.ip.hdrChecksum, HashAlgorithm.csum16);
  }
}

control computeChecksum(inout Parsed_headers p, inout ingress_metadata_t meta) {
  apply {
    update_checksum(p.ip.isValid(),
    { p.ip.version, 
      p.ip.ihl, 
      p.ip.diffserv,
      p.ip.totalLen,
      p.ip.identification,
      p.ip.flags,
      p.ip.fragOffset,
      p.ip.ttl,
      p.ip.protocol,
      p.ip.srcAddr,
      p.ip.dstAddr
    }, p.ip.hdrChecksum, HashAlgorithm.csum16);
  }
}


V1Switch(TopParser(), verifyChecksum(), ingress(), egress(), computeChecksum(),
         DeparserImpl()) main;
