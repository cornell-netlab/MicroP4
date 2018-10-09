/*
 * IPv6 routing only
 */

#include <core.p4>
#include "v1model.p4"

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 1024

header cpu_header_ht {
  bit<64> preamble;
  bit<8>  device;
  bit<8>  reason;
  bit<8>  if_index;
}

header Ether_ht {
  bit<48> dstAddr;
  bit<48> srcAddr;
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

header ICMPv6_ht {
  bit<8> type;
  bit<8> code;
  bit<16> checksum;
}

struct Parsed_headers {
  cpu_header_ht cpu_header; 
  Ether_ht eth;
  Vlan_ht vlan;
  IPv6_ht ip;
  ICMPv6_ht icmp;
}

error { 
  VLanIDMisMatch,
  NotVlanTraffic,
  IPv6IncorrectVersion
}

struct metadata {
  bit<128> nexthop_lladr;
}

parser TopParser(packet_in b, out Parsed_headers ph, inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

  state start {
    transition parse_ethernet;
  }


  state parse_ethernet {
    b.extract(ph.eth);
    transition select (ph.eth.etherType) {
      0x86DD: parse_ipv6;
      0x8100: parse_vlan;
    }
  }
  
  state parse_vlan {
    b.extract(ph.vlan);
    transition select (ph.vlan.eType) {
      0x86DD: parse_ipv6;
    }
  }

  state parse_ipv6 {
    b.extract(ph.ip);
    verify(ph.ip.version == 4w6, error.IPv6IncorrectVersion);
    transition select (ph.ip.nextHdr) {
      0x3A: parse_icmpv6;
      default: accept;
    }
  }

  state parse_icmpv6 {
    b.extract(ph.icmp);
    transition accept;
  }

}

control DeparserImpl(packet_out b, in Parsed_headers ph) {
  apply {
    b.emit(ph.cpu_header);
    b.emit(ph.eth);
    b.emit(ph.vlan);
    b.emit(ph.ip);
    b.emit(ph.icmp);
  }
}

control ingress(inout Parsed_headers headers,  inout metadata meta, 
               inout standard_metadata_t standard_metadata) {

  action set_nexthop(bit<128> nexthop_lladdr) {
    headers.ip.hopLimit = headers.ip.hopLimit-1;
    meta.nexthop_lladr = nexthop_lladdr;
  }

  action send_to_cpu(bit<8> reason, bit<9> cpu_port) {
    headers.cpu_header.setValid();
    headers.cpu_header.preamble = 64w0;
    headers.cpu_header.device = 8w0;
    headers.cpu_header.reason = reason;
    headers.cpu_header.if_index = (bit<8>)standard_metadata.ingress_port;
    standard_metadata.egress_spec = cpu_port;
  }

  action drop_action() {
    mark_to_drop();
  }

  // next hop routing
  table ip_fib_lpm {
    key = {
      headers.ip.dstAddr : lpm;
    }
    actions = {
      send_to_cpu;
      set_nexthop;
    }
    default_action = send_to_cpu();
    size = TABLE_SIZE;
  }

  action set_macs(bit<48> dmac, bit<48> smac, bit<9> egress_port) {
    headers.eth.dstAddr = dmac;
    headers.eth.srcAddr = smac;
    standard_metadata.egress_spec = egress_port;
  }

  table set_mac_addresses {
    key = { meta.nexthop_lladr: exact; }
    actions = {
      drop_action;
      set_macs;
    }
    size = MAC_TABLE_SIZE;
    default_action = drop_action;
  }

  apply {
    if (standard_metadata.parser_error != error.NoError) {
      drop_action();
      return;
    }
    if (headers.icmp.isValid()) {
      //
      send_to_cpu(0xFF, 0x00);
    } else {
      ip_fib_lpm.apply();
      set_mac_addresses.apply();
    }
  }
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

