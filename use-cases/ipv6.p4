/*
 * IPv6 router
 * Use case: 
 *  1. vlan support is added on basic_switch.p4 using add_vlan.p4
 *  2. Hosts on VLAN "vn1" runs on IPv6 address scheme.
 *  3. So, lets make one switch in vn1 a IPv6 router.
 */

# include <core.p4>
# include "v1model.p4"

header Ether_ht {
  bit<48> dAddr;
  bit<48> sAddr;
  bit<16> etherType;
}

header Vlan_ht {
  bit<3> prio;
  bit<1> c;
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




parser TopParser(packet_in b, out Parsed_headers ph, inout metadata meta,
                 inout standard_metadata_t standard_metadata)) {

  // This parser accepts only vlan tagged packets
  // Parser composition should take care of accept and reject states
  state start {
    b.extract(ph.eth);
    transition select (p.eth.etherType) {
      0x8100: parse_vlan;
      // Native ipv6 traffic is possible For the switches having access and trunk
      // ports. Application can decide the location of tagging
      0x86DD: parse_ipv6;
    }
  }

  state parse_vlan {
    packet.extract(p.vlan);
    transition select (p.vlan.eType) {
      0x86DD: parse_ipv6;
    }
  }

  state parse_ipv6 {
    b.extract(p.ip);
    verify(p.ip.version == 4w6, error.IPv4IncorrectVersion);
    transition accept;
  }
}

control DeparserImpl(packet_out b, Parsed_headers ph) {
  apply {
    b.emit(ph.ethernet);
    b.emit(ph.vlan);
    
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

control verifyChecksum(in Parsed_headers ph, inout metadata meta) {
  apply { }
}

control computeChecksum(inout Parsed_headers ph, inout metadata meta) {
  apply { }
}

V1Switch(TopParser(), verifyChecksum(), ingress(), egress(), computeChecksum(),
         DeparserImpl()) main;

