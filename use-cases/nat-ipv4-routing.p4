# include <core.p4>
#include <v1model.p4>

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32

header cpu_header_h {
  bit<64> preamble;
  bit<8>  device;
  bit<8>  reason;
  bit<8>  if_index_ingress_port;
}

header Ethernet_h {
  bit<48> dstAddr;
  bit<48> srcAddr;
  bit<16> etherType;
}

header Vlan_tag_h {
  bit<3> priority;
  bit<1> cfi;
  bit<12> id;
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
  bit<32> saddr;
  bit<32> daddr;
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

struct Parsed_headers {
  @name("cpu_header")
  cpu_header_h cpu_header;
  @name("vlan_tag")
  Vlan_tag_h vlan_tag;
  @name("ethernet")
  Ethernet_h ethernet;
  @name("ip")
  IPv4_h ip;
  @name("tcp")
  tcp_h tcp;
  @name("udp")
  udp_h udp;
}

error { 
  IPv4IncorrectVersion,
  IPv4OptionsNotSupported
}


struct ingress_metadata_t {
  bit<32> nextHop;
  bit<8> if_index_ingress_port;
}


parser TopParser(packet_in b, out Parsed_headers p, inout ingress_metadata_t meta, 
                  inout standard_metadata_t standard_metadata) {

  state start {
    // 9 bit ingress port to 8 bit if_index mapping
    meta.if_index_ingress_port = (bit<8>)standard_metadata.ingress_port;
    transition select((b.lookahead<bit<64>>())[63:0]) {
      64w0:     parse_cpu_header;
      default:  parse_ethernet;
    }
  }

  state parse_cpu_header {
    b.extract(p.cpu_header);
    meta.if_index_ingress_port = p.cpu_header.if_index_ingress_port;
    transition parse_ethernet;
  }

  // checksum and local variable intialization
  state parse_ethernet {
    b.extract(p.ethernet);
    transition select (p.ethernet.etherType) {
      0x0800: parse_ipv4;
    }
  }

  state parse_ipv4 {
    b.extract(p.ip);
    verify(p.ip.version == 4w4, error.IPv4IncorrectVersion);
    verify(p.ip.ihl == 4w5, error.IPv4OptionsNotSupported);
    transition select(p.ip.protocol) {
        0x06: parse_tcp;
        0x11: parse_udp;
        default: accept;
    }
  }

  state parse_tcp {
    b.extract(p.tcp);
    transition accept;
  }

  state parse_udp {
    b.extract(p.udp);
    transition accept;
  }

}


control ingress(inout Parsed_headers headers, inout ingress_metadata_t  meta,
                inout standard_metadata_t standard_metadata) {
  
  action set_nexthop(bit<32> nexthop_ipv4_addr, bit<9> port) {
    headers.ip.ttl = headers.ip.ttl-1;
    meta.nextHop = nexthop_ipv4_addr;
    standard_metadata.egress_spec = port;
  }

  action send_to_cpu(bit<8> reason, bit<9> cpu_port) {
    headers.cpu_header.setValid();
    headers.cpu_header.preamble = 64w0;
    headers.cpu_header.device = 8w0;
    headers.cpu_header.reason = reason;
    headers.cpu_header.if_index_ingress_port = meta.if_index_ingress_port;
    standard_metadata.egress_spec = cpu_port;
  }

  action modify_ip_src_addr(bit<32> src_addr) {
    headers.ip.saddr = src_addr;
  }

  action modify_ip_dst_addr(bit<32> dst_addr) {
    headers.ip.daddr = dst_addr;
  }


  action modify_tcp_src_port(bit<16> src_port) {
    headers.tcp.srcPort = src_port;
  }

  action modify_tcp_dst_port(bit<16> dst_port) {
    headers.tcp.dstPort = dst_port;
  }

  action modify_udp_src_port(bit<16> src_port) {
    headers.udp.srcPort = src_port;
  }

  action modify_udp_dst_port(bit<16> dst_port) {
    headers.udp.dstPort = dst_port;
  }


  action drop_action() {
    mark_to_drop();
  }

  table simple_nat {
    key = {
      headers.ip.saddr: exact;
      headers.ip.daddr: exact;
      headers.ip.protocol: exact;
      headers.tcp.srcPort: ternary;
      headers.tcp.dstPort: ternary;
      headers.udp.srcPort: ternary;
      headers.udp.dstPort: ternary;

    }
    actions = {
       modify_ip_src_addr;
       modify_ip_dst_addr;
       modify_tcp_src_port;
       modify_tcp_dst_port;
       modify_udp_src_port;
       modify_udp_dst_port;
       send_to_cpu;

    }
    default_action = send_to_cpu();
  }

  // next hop routing
  table ipv4_fib_lpm {
    key = {
      headers.ip.daddr : lpm;
    }
    actions = {
      send_to_cpu;
      set_nexthop;
    }

    default_action = send_to_cpu();
    size = TABLE_SIZE;
  }

  action set_dmac(bit<48> dmac) {
    headers.ethernet.dstAddr = dmac;
  }

  table dmac {
    key = { meta.nextHop: exact; }
    actions = {
      drop_action;
      set_dmac;
    }
    size = TABLE_SIZE;
    default_action = drop_action;
  }

  action set_smac(bit<48> smac) {
    headers.ethernet.srcAddr = smac;
  }

  table smac {
    key = { standard_metadata.egress_port: exact; }
    actions = {
      drop_action;
      set_smac;
    }
    size = MAC_TABLE_SIZE;
    default_action = drop_action;
  }

  apply {
    if (standard_metadata.parser_error != error.NoError) {
      drop_action();
      return;
    }

    simple_nat.apply();
    ipv4_fib_lpm.apply();

    // Layer 2 functionality
    dmac.apply();
    // if(dmac.apply().action_run == drop_action);
    smac.apply();
  }
}


control egress(inout Parsed_headers headers, inout ingress_metadata_t meta,
                inout standard_metadata_t standard_metadata) {
  apply {
  }
}

// deparser section
control DeparserImpl(packet_out b, in Parsed_headers p) {
  apply {
    b.emit(p.cpu_header);
    b.emit(p.ethernet);
    b.emit(p.vlan_tag);
    b.emit(p.ip);
    b.emit(p.udp);
    b.emit(p.tcp);
  }
}



control verifyChecksum(inout Parsed_headers p, inout ingress_metadata_t meta) {
  apply {
    verify_checksum(true, 
    { p.ip.version, 
      p.ip.ihl, 
      p.ip.diffserv, 
      p.ip.totalLen, 
      p.ip.identification, 
      p.ip.flags, 
      p.ip.fragOffset, 
      p.ip.ttl, 
      p.ip.protocol,
      p.ip.saddr, 
      p.ip.daddr
    }, p.ip.hdrChecksum, HashAlgorithm.csum16);
  }
}

control computeChecksum(inout Parsed_headers p, inout ingress_metadata_t meta) {
  apply {
    update_checksum(p.ip.isValid(),
    { p.ip.version, 
      p.ip.ihl, 
      p.ip.diffserv,
      p.ip.totalLen,
      p.ip.identification,
      p.ip.flags,
      p.ip.fragOffset,
      p.ip.ttl,
      p.ip.protocol,
      p.ip.saddr,
      p.ip.daddr
    }, p.ip.hdrChecksum, HashAlgorithm.csum16);
  }
}


V1Switch(TopParser(), verifyChecksum(), ingress(), egress(), computeChecksum(),
         DeparserImpl()) main;
