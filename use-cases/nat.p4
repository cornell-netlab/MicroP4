
#include <core.p4>
#include <v1model.p4>

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32

header cpu_header_t {
  bit<64> preamble;
  bit<8>  device;
  bit<8>  reason;
  bit<8>  in_port;
}

header ethernet_h {
  bit<48> dAddr;
  bit<48> sAddr;
  bit<16> etherType;
}

header vlan_tag_h {
  bit<3> priority;
  bit<1> cfi;
  bit<12> id;
  bit<16> etherType;
}

/*
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
  bit<32> sAddr;
  bit<32> dAddr;
}
*/

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
  
/*
  bit<32> seqNo;
  bit<32> ackNo;
  bit<4>  dataOffset;
  bit<3>  res;
  bit<3>  ecn;
  bit<6>  ctrl;
  bit<16> window;
  bit<16> checksum;
  bit<16> urgentPtr;
}
*/

header udp_h {
  bit<16> srcPort;
  bit<16> dstPort;
  bit<16> len;
  bit<16> checksum;
}


struct headers {
  @name("cpu_header")
  cpu_header_t cpu_header;
  @name("ethernet")
  ethernet_h ethernet;
  @name("vlan_tag")
  vlan_tag_h vlan_tag;
  @name("IPv4_h")
  ipv4_h ipv4;
  @name("tcp")
  tcp_h tcp;
  @name("udp")
  udp_h udp;
}

// required metadata of struct of struct type
struct ingress_data_t {
}


parser ParserImpl(packet_in packet, out headers hdr, inout ingress_data_t meta, 
                  inout standard_metadata_t standard_metadata) {
  state start {
    packet.extract(hdr.ethernet);
    transition select(hdr.ethernet.etherType) {
      0x8100: parse_vlan;
      0x0800: parse_ipv4;
    }
  }

  state parse_vlan {
    packet.extract(hdr.vlan_tag);
    transition select(hdr.vlan_tag.etherType) {
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
   
control DeparserImpl(packet_out packet, in headers hdr) {
  apply {

    packet.emit(hdr.cpu_header);
    packet.emit(hdr.ethernet);
    packet.emit(hdr.vlan_tag);
    packet.emit(hdr.ipv4);
    packet.emit(hdr.udp);
    packet.emit(hdr.tcp);
  }
}


control ingress(inout headers hdr, inout ingress_data_t meta, inout 
                standard_metadata_t standard_metadata) {

  action modify_ipv4_src_addr(bit<32> src_addr) {
    hdr.ipv4.sAddr = src_addr;
  }

  action modify_ipv4_dst_addr(bit<32> dst_addr) {
    hdr.ipv4.dAddr = dst_addr;
  }


  action modify_tcp_src_port(bit<16> src_port) {
    hdr.tcp.srcPort = src_port;
  }

  action modify_tcp_dst_port(bit<16> dst_port) {
    hdr.tcp.dstPort = dst_port;
  }

  action modify_udp_src_port(bit<16> src_port) {
    hdr.udp.srcPort = src_port;
  }

  action modify_udp_dst_port(bit<16> dst_port) {
    hdr.udp.dstPort = dst_port;
  }

  action send_to_cpu(bit<9> cpu_port) {
    hdr.cpu_header.setValid();
    hdr.cpu_header.preamble = 64w0;
    hdr.cpu_header.device = 8w0;
    hdr.cpu_header.reason = 8w0xa0;
    hdr.cpu_header.in_port = (bit<8>)standard_metadata.ingress_port;
    standard_metadata.egress_spec = cpu_port;
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
       modify_ipv4_src_addr;
       modify_ipv4_dst_addr;
       modify_tcp_src_port;
       modify_tcp_dst_port;
       modify_udp_src_port;
       modify_udp_dst_port;
       send_to_cpu;

    }
    default_action = send_to_cpu();
  }

  apply {
    simple_nat.apply();
  }
}

control egress(inout headers hdr, inout ingress_data_t meta, 
               inout standard_metadata_t standard_metadata) {
 apply { 
  // This ingress-egress processing is enforced by the switch architecture.
  // Composition should be done on control flow graph representation or single
  // homogeneous abstraction
 }
}

control verifyChecksum(inout headers hdr, inout ingress_data_t meta) {
  apply { }
}

control computeChecksum(inout headers hdr, inout ingress_data_t meta) {
  apply { }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(),
         DeparserImpl()) main;

