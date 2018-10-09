#include <core.p4>
#include "v1model.p4"

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 1024

header ethernet_h {
  bit<48> dstAddr;
  bit<48> srcAddr;
  bit<16> etherType;
}

header vlan_h {
  bit<4> cPrio;
  bit<12> tag;
  bit<16> eType;
}

header ipv4_h {
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

header ipv6_h {
  bit<4> version;
  bit<8> trafficClass;
  bit<20> flowLabel;
  bit<16> payloadLen;
  bit<8> nextHdr;
  bit<8> hopLimit;
  bit<128> srcAddr;
  bit<128> dstAddr;
}

header icmpv6_h {
  bit<8> type;
  bit<8> code;
  bit<16> checksum;
}

header cpu_header_h {
  bit<64> preamble;
  bit<8>  device;
  bit<8>  reason;
  bit<8>  if_index;
}

struct Parsed_headers {
  cpu_header_h cpu_header; 
  ethernet_h eth;
  vlan_h vlan;
  ipv6_h ipv6;
  ipv4_h ipv4;
  icmpv6_h icmp;
}

error { 
  IPv6IncorrectVersion,
  IPv4IncorrectVersion,
  IPv4OptionsNotSupported
}

struct metadata {
  bit<128> nexthop_lladr;
  bit<32> nexthop;
  bit<8> if_index;
}

parser TopParser(packet_in b, out Parsed_headers ph, inout metadata meta,
                 inout standard_metadata_t standard_metadata) {

  /*
   * The popular technique of encapsulating packet in a header to send to data
   * plane needs to be handled by the multiplexed control channel.
   * 
   */

  state start {
    transition parse_ethernet;
  }

  state parse_ethernet {
    b.extract(ph.eth);
    transition select (ph.eth.etherType) {
      0x0800: parse_ipv4;
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

  state parse_ipv4 {
    b.extract(ph.ipv4);
    verify(ph.ipv4.version == 4w4, error.IPv4IncorrectVersion);
    verify(ph.ipv4.ihl == 4w5, error.IPv4OptionsNotSupported);
    transition accept;
  }

  state parse_ipv6 {
    b.extract(ph.ipv6);
    verify(ph.ipv6.version == 4w6, error.IPv6IncorrectVersion);
    transition select (ph.ipv6.nextHdr) {
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
    b.emit(ph.ipv4);
    b.emit(ph.ipv6);
    b.emit(ph.icmp);
  }
}

control ingress(inout Parsed_headers headers,  inout metadata meta, 
               inout standard_metadata_t standard_metadata) {

  action ipv6_set_nexthop(bit<128> nexthop_lladdr) {
    headers.ipv6.hopLimit = headers.ipv6.hopLimit-1;
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

  action ipv6_drop_action() {
    mark_to_drop();
  }

  table ipv6_fib_lpm {
    key = {
      headers.ipv6.dstAddr : lpm;
    }
    actions = {
      send_to_cpu;
      ipv6_set_nexthop;
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
      ipv6_drop_action;
      set_macs;
    }
    size = MAC_TABLE_SIZE;
    default_action = ipv6_drop_action;
  }

  action ipv4_set_nexthop(bit<32> nexthop_ipv4_addr, bit<9> port) {
    headers.ipv4.ttl = headers.ipv4.ttl-1;
    meta.nexthop = nexthop_ipv4_addr;
    standard_metadata.egress_spec = port;
  }

  action ipv4_drop_action() {
    mark_to_drop();
  }

  table ipv4_fib_lpm {
    key = {
      headers.ipv4.dstAddr : lpm;
    }
    actions = {
      send_to_cpu;
      ipv4_set_nexthop;
    }
    default_action = send_to_cpu();
    size = TABLE_SIZE;
  }

  action set_dmac(bit<48> dmac) {
    headers.eth.dstAddr = dmac;
  }

  table dmac {
    key = { meta.nexthop: exact; }
    actions = {
      ipv4_drop_action;
      set_dmac;
    }
    size = TABLE_SIZE;
    default_action = ipv4_drop_action;
  }

  action set_smac(bit<48> smac) {
    headers.eth.srcAddr = smac;
  }

  table smac {
    key = { standard_metadata.egress_port: exact; }
    actions = {
      ipv4_drop_action;
      set_smac;
    }
    size = MAC_TABLE_SIZE;
    default_action = ipv4_drop_action;
  }


  apply {
    if (standard_metadata.parser_error != error.NoError) {
      ipv4_drop_action();
      return;
    }
    if (standard_metadata.parser_error != error.NoError) {
      ipv6_drop_action();
      return;
    }

    ipv4_fib_lpm.apply();

    // Layer 2 functionality
    dmac.apply();
    // if(dmac.apply().action_run == drop_action);
    smac.apply();

    if (headers.icmp.isValid()) {
      //
      send_to_cpu(0xFF, 0x00);
    } else {
      ipv6_fib_lpm.apply();
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

