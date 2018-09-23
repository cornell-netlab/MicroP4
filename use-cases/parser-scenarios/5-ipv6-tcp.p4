#include <core.p4>
#include <v1model.p4>

const bit<16> ETHERTYPE_IPV4 = 0x800;
const bit<16> ETHERTYPE_IPV6 = 0x86DD;
const bit<16> ETHERTYPE_VLAN1 = 0x8100;
const bit<16> ETHERTYPE_VLAN2 = 0x9100;

const bit<8> PROTOCOL_TCP = 0x06;
const bit<8> PROTOCOL_UDP = 0x11;
const bit<8> PROTOCOL_GRE = 0x2f;

const bit<16> PROTOCOL_NVGRE = 0x6558;
const bit<16> UDP_DEST_VXLAN = 0x12B5;

typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;


header ethernet_t {
  macAddr_t dstAddr;
  macAddr_t srcAddr;
  bit<16>   etherType;
}

header ipv6_t {
  bit<4> version;
  bit<8> trafficClass;
  bit<20> flowLabel;
  bit<16> payloadLen;
  bit<8> nextHdr;
  bit<8> hopLimit;
  bit<128> srcAddr;
  bit<128> dstAddr;
}

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNum;
    bit<32> actNum;
    bit<4>  dataOffset;
    bit<3>  reserved;
    bit<9>  flags;
    bit<16> windowSize;
    bit<16> checksum; 
    bit<16> urgentPointer;
}

header udp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<16> payloadLength;
    bit<16> checksum; 
}

struct metadata {
  /* empty */
}

struct headers {
  ethernet_t  ethernet;
  ipv6_t      ipv6;
  tcp_t      tcp;
  udp_t      udp;
}

parser ParserImpl(packet_in packet,
                  out headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {

  state start {
    transition parse_ethernet;
  }

  state parse_ethernet {
    packet.extract(hdr.ethernet);
    transition select(hdr.ethernet.etherType) {
        ETHERTYPE_IPV6: parse_ipv6;
    }
  }

  state parse_ipv6 {
    packet.extract(hdr.ipv6);
    transition select(hdr.ipv6.nextHdr) {
        PROTOCOL_TCP: parse_tcp;
        PROTOCOL_UDP: parse_udp;
    }
  }

  state parse_tcp {
    packet.extract(hdr.tcp);
    transition accept;
  }

  state parse_udp {
    packet.extract(hdr.udp);
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
  apply {  
  }
}

control computeChecksum(inout headers  hdr, inout metadata meta) {
  apply {
  }

}

control DeparserImpl(packet_out packet, in headers hdr) {
  apply {
    packet.emit(hdr.ethernet);
    packet.emit(hdr.ipv6);
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

