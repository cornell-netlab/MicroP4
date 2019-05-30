#include <core.p4>
#include <v1model.p4>

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32

header ethernet_h {
  bit<48> dAddr;
  bit<48> sAddr;
  bit<16> etherType;
}


header ipv4_h {
  bit<64> unused;
  bit<8> ttl;
  bit<8> protocol;
  bit<16> hdrChecksum;
  bit<32> sAddr;
  bit<32> dAddr;
}


header tcp_h {
  bit<16> srcPort;
  bit<16> dstPort;
  bit<128> unused;
}
  
header udp_h {
  bit<16> srcPort;
  bit<16> dstPort;
  bit<16> len;
  bit<16> checksum;
}


struct headers {
  @name("ethernet")
  ethernet_h ethernet;
  @name("IPv4_h")
  ipv4_h ipv4;
  @name("tcp")
  tcp_h tcp;
  @name("udp")
  udp_h udp;
}

struct metadata_t {
}


parser Parser(packet_in packet, out headers hdr, inout metadata_t meta,
                  out standard_metadata_t standard_metadata) {
  state start {
    packet.extract(hdr.ethernet);
    transition select(hdr.ethernet.etherType) {
      0x0800: parse_ipv4;
    }
  }

  state parse_ipv4 {
    packet.extract(hdr.ipv4);
    transition select(hdr.ipv4.protocol) {
        0x06: parse_tcp;
        0x11: parse_udp;
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
   
control Deparser(packet_out packet, in headers hdr) {
  apply {

    packet.emit(hdr.ethernet);
    packet.emit(hdr.ipv4);
    packet.emit(hdr.udp);
    packet.emit(hdr.tcp);
  }
}

action drop_packet() {
  mark_to_drop();
}

control Ingress(inout headers hdr, inout metadata_t meta,
                inout standard_metadata_t standard_metadata) {

  action src_nat_tcp(bit<32> src_addr, bit<16> src_port) {
    hdr.ipv4.sAddr = src_addr;
    hdr.tcp.srcPort = src_port;
  }

  action dst_nat_tcp(bit<32> dst_addr, bit<16> dst_port) {
    hdr.ipv4.dAddr = dst_addr;
    hdr.tcp.dstPort = dst_port;
  }

  action src_nat_udp(bit<32> src_addr, bit<16> src_port) {
    hdr.ipv4.sAddr = src_addr;
    hdr.udp.srcPort = src_port;
  }

  action dst_nat_udp(bit<32> dst_addr, bit<16> dst_port) {
    hdr.ipv4.dAddr = dst_addr;
    hdr.udp.dstPort = dst_port;
  }

  table simple_nat {
    key = {
      hdr.ipv4.sAddr: exact;
      hdr.ipv4.dAddr: exact;
      hdr.ipv4.protocol: exact;
      hdr.tcp.srcPort: ternary;
      hdr.tcp.dstPort: ternary;
      hdr.udp.srcPort: ternary;
      hdr.udp.dstPort: ternary;

    }
    actions = {
      src_nat_tcp;
      dst_nat_tcp;
      src_nat_udp;
      dst_nat_udp;
      drop_packet;
      NoAction;
    }
    default_action = drop_packet();
  }

  apply {
    simple_nat.apply();


    // Dropping this packet based on a standard_metadata variable, whose value 
    // is available only in egress pipeline.
    // This will enforce dependency on egress processing.
    /*
    if (standard_metadata.deq_qdepth > 100)
    drop_packet();
    */
  }
}

control egress(inout headers hdr, inout metadata_t meta, 
                inout standard_metadata_t standard_metadata) { 
  apply { }
}

control verifyChecksum(inout headers hdr, inout metadata_t meta) {
  apply { }
}

control computeChecksum(inout headers hdr, inout metadata_t meta) {
  apply { }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(),
         DeparserImpl()) main;

