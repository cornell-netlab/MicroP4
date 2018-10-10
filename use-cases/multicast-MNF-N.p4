/*
 * Data plane for multicast function for upstream interfaces.
 * The data plane is controlled by higher level controller managing upstream
 * traffic and interfaces at edge devices.
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

header UDP_h {
  bit<16> srcPort;
  bit<16> dstPort;
  bit<16> payloadLength;
  bit<16> checksum; 
}

struct Parsed_headers {
  Ethernet_h ethernet;
  IPv4_h ipv4;
  UDP_h udp; 
}

error { 
  IPv4IncorrectVersion,
  IPv4OptionsNotSupported
}

struct ingress_metadata_t {

}

parser TopParser(packet_in packet, out Parsed_headers ph, 
                 inout ingress_metadata_t meta, 
                 inout standard_metadata_t standard_metadata) {

  state start {
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
      0x11: parse_udp;
    }
  }

  state parse_udp {
    packet.extract(ph.udp);
    transition accept;
  }
}

control ingress(inout Parsed_headers ph, inout ingress_metadata_t  meta,
                inout standard_metadata_t standard_metadata) {

  action set_multicast_group(bit<16> multicast_group) {
    standard_metadata.mcast_grp = multicast_group;
  }

  table replicate_upstream {
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
    if (ph.ipv4.isValid() && ph.udp.isValid())
      replicate_upstream.apply();
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
    forward_multicast_copy.apply();
  }
}

control DeparserImpl(packet_out packet, in Parsed_headers ph) {
  apply {
    packet.emit(ph.ethernet);
    packet.emit(ph.ipv4);
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
