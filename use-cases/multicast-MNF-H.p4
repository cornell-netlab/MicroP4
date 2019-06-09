/*
 * Data plane for multicast network function handling IGMP(v3) messages.
 *
 * This switch should act like a designated router for the hosts in the network.
 * Control plane of the switch is responsible to handle processing of IGMP
 * messages and can replicate packets to only down stream network interfaces.
 *
 */

# include <core.p4>
#include <v1model.p4>

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 64

header Ethernet_h {
  bit<48> dstAddr;
  bit<48> srcAddr;
  bit<16> etherType;
}

// This CPU header definition is taken from testdata examples in P4C repo code.
header cpu_header_t {
  bit<64> preamble;
  bit<8>  device;
  bit<8>  reason;
  bit<8>  if_index;
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

// 0x11-query, 0x22-v3Report, 0x12-v1Report, 0x16-v2Report 0x17-v2LeaveGroup
header IGMP_h {
  bit<8> msgType;
  bit<8> maxRespTime;
  bit<16> checksum;
  bit<32> grpAddr;
}


header UDP_h {
  bit<16> srcPort;
  bit<16> dstPort;
  bit<16> payloadLength;
  bit<16> checksum; 
}

struct Parsed_headers {
  cpu_header_t cpu_header;
  Ethernet_h ethernet;
  IPv4_h ipv4;
  IGMP_h igmp; 
  UDP_h udp; 
}

error { 
  IPv4IncorrectVersion,
  IPv4OptionsNotSupported
}

struct ingress_metadata_t {
  bit<8> if_index;
}

action drop() {
  mark_to_drop();
}

parser TopParser(packet_in packet, out Parsed_headers ph, 
                 inout ingress_metadata_t meta, 
                 inout standard_metadata_t standard_metadata) {

  state start {
    // 9 bit ingress port to 8 bit if_index mapping
    meta.if_index = (bit<8>)standard_metadata.ingress_port;
    transition select((packet.lookahead<bit<64>>())[63:0]) {
      64w0:     parse_cpu_header;
      default:  parse_ethernet;
  }
                                                      }
  state parse_cpu_header {
    packet.extract(ph.cpu_header);
    meta.if_index = ph.cpu_header.if_index;
    transition parse_ethernet;
  }

  state parse_ethernet {
    packet.extract(ph.ethernet);
    transition select (ph.ethernet.etherType) {
      0x0800: parse_ipv4;
    }
  }

  state parse_ipv4 {
    packet.extract(ph.ipv4);
    verify(ph.ipv4.version == 4w4, error.IPv4IncorrectVersion);
    verify(ph.ipv4.ihl == 4w5, error.IPv4OptionsNotSupported);
    transition select (ph.ipv4.protocol) {
      0x02: parse_igmp;
      0x11: parse_udp;
    }
  }

  state parse_udp {
    packet.extract(ph.udp);
    transition accept;
  }

  // CP can send a query to send out on multiple interfaces.
  state parse_igmp {
    packet.extract(ph.igmp);
    transition accept;
  }
}

control ingress(inout Parsed_headers ph, inout ingress_metadata_t  meta,
                inout standard_metadata_t standard_metadata) {

  action set_multicast_group(bit<16> multicast_group) {
    standard_metadata.mcast_grp = multicast_group;
  }

  action decap_cpu_header() {
    ph.cpu_header.setInvalid();
  }

  action encap_cpu_header(bit<9> cpu_port) {
    ph.cpu_header.setValid();
    ph.cpu_header.preamble = 64w0;
    ph.cpu_header.device = 8w0;
    ph.cpu_header.reason = 8w0xa0;
    ph.cpu_header.if_index = meta.if_index;
    standard_metadata.egress_spec = cpu_port;
  }

  table igmp_table {
    key = {
      ph.cpu_header.isValid(): exact;
      ph.igmp.isValid(): exact;
      ph.igmp.msgType: ternary;
      ph.igmp.grpAddr: ternary;
      ph.ipv4.srcAddr: ternary;
    }
    actions = {
      decap_cpu_header;
      // set the interfaces for which the switch is querier
      set_multicast_group;
      encap_cpu_header;
      NoAction;
    }
    default_action = NoAction();
  }

  table data_multicast{
    key = {
      // src address for source-specific multicast
      ph.ipv4.srcAddr: exact;
      // group address
      ph.ipv4.dstAddr: exact;
      ph.udp.srcPort: exact;
      ph.udp.dstPort: exact;
    }
    actions = {
      set_multicast_group;
      NoAction;
    }
    default_action = NoAction();
  }

  apply {
    if (ph.igmp.isValid())
      igmp_table.apply();
    if (ph.ipv4.isValid() && ph.udp.isValid())
      data_multicast.apply();
  }
}


control egress(inout Parsed_headers ph, inout ingress_metadata_t meta,
               inout standard_metadata_t standard_metadata) {
  
  action set_smac(bit<48> smac) {
    ph.ethernet.srcAddr = smac;
  }

  table forward_multicast_copy {
    key = {
      standard_metadata.mcast_grp: exact;
      standard_metadata.egress_rid: exact;
    }
    actions = {
      set_smac;
    }
  }


  apply {
    if (!ph.cpu_header.isValid())
      forward_multicast_copy.apply();
  }
}

control DeparserImpl(packet_out packet, in Parsed_headers ph) {
  apply {
    packet.emit(ph.cpu_header);
    packet.emit(ph.ethernet);
    packet.emit(ph.ipv4);
    packet.emit(ph.igmp);
    packet.emit(ph.udp);
  }
}



control verifyChecksum(inout Parsed_headers ph, inout ingress_metadata_t meta) {
  apply {
    verify_checksum(true, 
    { ph.ipv4.version, 
      ph.ipv4.ihl, 
      ph.ipv4.diffserv, 
      ph.ipv4.totalLen, 
      ph.ipv4.identification, 
      ph.ipv4.flags, 
      ph.ipv4.fragOffset, 
      ph.ipv4.ttl, 
      ph.ipv4.protocol,
      ph.ipv4.srcAddr, 
      ph.ipv4.dstAddr
    }, ph.ipv4.hdrChecksum, HashAlgorithm.csum16);

    // Need verify checksum for UDP and igmp
  }
}

control computeChecksum(inout Parsed_headers ph, inout ingress_metadata_t meta) {
  apply {
    update_checksum(ph.ipv4.isValid(),
    { ph.ipv4.version, 
      ph.ipv4.ihl, 
      ph.ipv4.diffserv,
      ph.ipv4.totalLen,
      ph.ipv4.identification,
      ph.ipv4.flags,
      ph.ipv4.fragOffset,
      ph.ipv4.ttl,
      ph.ipv4.protocol,
      ph.ipv4.srcAddr,
      ph.ipv4.dstAddr
    }, ph.ipv4.hdrChecksum, HashAlgorithm.csum16);

    // Need verify checksum for UDP and igmp
  }
}


V1Switch(TopParser(), verifyChecksum(), ingress(), egress(), computeChecksum(),
         DeparserImpl()) main;
