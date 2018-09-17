/*
 * IPv6 router
 * Use case: 
 *  1. vlan support is added on basic_switch.p4 using add_vlan.p4
 *  2. Hosts on VLAN "111" runs on IPv6 address scheme.
 *  3. So, lets make one switch in vn1 an IPv6 router.
 */

# include <core.p4>
# include "v1model.p4"

header Ether_ht {
  bit<96> addrs;
  bit<16> etherType;
}

header Vlan_ht {
  bit<4> cPrio;
  bit<12> tag;
  bit<16> eType;
}

header IPv6_ht {
  bit<4> version;
  bit<8> trafficClass;
  bit<20> flowLabel;
  bit<16> payloadLen;
  bit<8> nextHdr;
  bit<8> hopLimit;
  bit<128> srcAddr;
  bit<128> dstAddr;
}


struct Parsed_headers {
  Ether_ht eth;
  Vlan_ht vlan;
  IPv6_ht ip;
}

error { 
  VLanIDMisMatch,
  NotVlanTraffic,
  IPv6IncorrectVersion
}

struct metadata {
  bit<128> nextHop;
}

parser TopParser(packet_in b, out Parsed_headers ph, inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

  // This parser accepts only vlan tagged packets
  // Parser composition should take care of accept and reject states
  state start {
    b.extract(ph.eth);
    verify(ph.eth.etherType == 0x8100, error.NotVlanTraffic);
    b.extract(ph.vlan);
    verify(ph.vlan.eType == 0x111, error.VLanIDMisMatch);
    transition select (ph.vlan.eType) {
      0x86DD: parse_ipv6;
    }
  }

  state parse_ipv6 {
    b.extract(ph.ip);
    verify(ph.ip.version == 4w6, error.IPv6IncorrectVersion);
    transition accept;
  }
}

control DeparserImpl(packet_out b, in Parsed_headers ph) {
  apply {
    b.emit(ph.eth);
    b.emit(ph.vlan);
    b.emit(ph.ip);
  }
}

control ingress(inout Parsed_headers ph,  inout metadata meta, 
               inout standard_metadata_t standard_metadata) {
 apply { }
}

control egress(inout Parsed_headers ph, inout metadata meta, 
               inout standard_metadata_t standard_metadata) {
 apply { }
}

control verifyChecksum(inout Parsed_headers ph, inout metadata meta) {
  apply { }
}

control computeChecksum(inout Parsed_headers ph, inout metadata meta) {
  apply { }
}

V1Switch(TopParser(), verifyChecksum(), ingress(), egress(), computeChecksum(),
         DeparserImpl()) main;

