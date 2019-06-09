/*
 *  Parser in this program.
 *  ethernet -- vlan
 *      |        |
 *     ipv41    ipv42 (of 2-eth-vlan-ip.p4)
 *  (of 1-eth-ip.p4)
 *
 *  Related Files for the composition.
 *  1. 1-eth-ip.p4
 *  2. 2-eth-vlan-ip.p4
 *  and the merged parser file.
 *  3. mp-12.p4 (This file)
 *
 *  Because, both the programs parses the IPv4 headers from different relative
 *  locations. 
 *
 *  Check mp-13.p4, mp-45.p4, .. for more examples.
 */



#include <core.p4>
#include <v1model.p4>

const bit<16> ETHERTYPE_IPV4 = 0x800;
const bit<16> ETHERTYPE_IPV6 = 0x86DD;
const bit<16> ETHERTYPE_VLAN1 = 0x8100;
const bit<16> ETHERTYPE_VLAN2 = 0x9100;

const bit<8> PROTOCOL_TCP = 0x06;
const bit<8> PROTOCOL_UDP = 0x11;
const bit<8> PROTOCOL_ICMP = 0x01;


typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

header ethernet_t {
  macAddr_t dstAddr;
  macAddr_t srcAddr;
  bit<16>   etherType;
}

header vlan_t {
  bit<3>  pcp;
  bit<1>  cfi;
  bit<12> vid;
  bit<16> etherType;
}

header ipv4_t {
  bit<4>    version;
  bit<4>    ihl;
  bit<8>    diffserv;
  bit<16>   totalLen;
  bit<16>   identification;
  bit<3>    flags;
  bit<13>   fragOffset;
  bit<8>    ttl;
  bit<8>    protocol;
  bit<16>   hdrChecksum;
  ip4Addr_t srcAddr;
  ip4Addr_t dstAddr;
}


struct metadata {
  bit<2> indicator_field;
}

struct headers {
  ethernet_t  ethernet;
  vlan_t      vlan1;
  ipv4_t      ipv4_1;
  ipv4_t      ipv4_2;
}



parser ParserImpl(packet_in packet, out headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

  state start {
      transition parse_ethernet;
  }

  state parse_ethernet {
    packet.extract(hdr.ethernet);
    meta.indicator_field = meta.indicator_field & 0b11;
    transition select(hdr.ethernet.etherType) {
      ETHERTYPE_VLAN1: parse_vlan1;
      ETHERTYPE_IPV4 : parse_ipv4_1;
      default: accept;
    }
  }

  state parse_vlan1 {
    packet.extract(hdr.vlan1);
    meta.indicator_field = meta.indicator_field & 0b10;
    transition select(hdr.vlan1.etherType) {
        ETHERTYPE_IPV4 : parse_ipv4_2;
        default: accept;
    }
  }
  
  state parse_ipv4_1 {
    packet.extract(hdr.ipv4_1);
    meta.indicator_field = meta.indicator_field & 0b01;
    transition accept;
  }

  state parse_ipv4_2 {
    meta.indicator_field = meta.indicator_field & 0b10;
    packet.extract(hdr.ipv4_2);
    transition accept;
  }
}



control verifyChecksum(inout headers hdr, inout metadata meta) {
  apply {  
  }
}



control ingress(inout headers hdr, inout metadata meta, 
                inout standard_metadata_t standard_metadata) {
  apply {
  }
}


control egress(inout headers hdr, inout metadata meta, 
               inout standard_metadata_t standard_metadata) {
  apply {  }
}


control computeChecksum(inout headers  hdr, inout metadata meta)
{
  apply {
  }
}

control DeparserImpl(packet_out packet, in headers hdr) {
  apply {
  }
}


V1Switch(
ParserImpl(),
verifyChecksum(),
ingress(),
egress(),
computeChecksum(),
DeparserImpl()
) main;

