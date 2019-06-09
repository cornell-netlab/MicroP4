# include <core.p4>
# include <csamodel.p4>

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32


// To hold maximum possible bytes parser may parse in the packet.
// In other words, number of bytes the parser may extract while traversing 
// longest path from the Start state to Accept state.
// It is a compile time know value even in case of variable length header and
// header stack.
#define max_num_of_bytes 1500

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
  bit<32> saddr;
  bit<32> daddr;
}

header tcp_h {
  bit<16> srcPort;
  bit<16> dstPort;
  bit<128> unused;
}
  
header byte {
  bit<8> bits;
}

// Alternate approach to byte.
// Storing all the bytes in a single header
// header packet_h {
//   bit<(max_num_of_bytes*8)> bits;
// }

header udp_h {
  bit<16> srcPort;
  bit<16> dstPort;
  bit<16> len;
  bit<16> checksum;
}

struct Parsed_headers {
  @name("ethernet")
  Ethernet_h ethernet;
  @name("vlan_tag")
  Vlan_tag_h vlan_tag;
  @name("ip")
  IPv4_h ip;
  @name("tcp")
  tcp_h tcp;
  @name("udp")
  udp_h udp;

  byte[max_num_of_bytes] bytes; 

// packet_h pkt;  
}

error { 
  IPv4IncorrectVersion,
  IPv4OptionsNotSupported
}

struct ingress_metadata_t {
  bit<32> nextHop;
  bit<8> if_index_ingress_port;

  bit<12> num_of_bytes;
}

parser TopParser(packet_in b, out Parsed_headers ph, inout ingress_metadata_t meta, 
                  inout standard_metadata_t standard_metadata) {

  state start {
    meta.num_of_bytes = 0;
    transition parse_bytes;
  }

  state parse_bytes {
    b.extract(ph.bytes.next);
    meta.num_of_bytes = meta.num_of_bytes + 1;
    transition select(meta.num_of_bytes) {
      max_num_of_bytes: accept;
      _ : parse_bytes;
    }
  }
  
  // Alternate approach to bytes
  // state parse_bits {
  //   packet.extract(ph.pkt);
  //   transition accept;
  // }
}


control Pipe(inout Parsed_headers headers, inout ingress_metadata_t  meta,
                inout standard_metadata_t standard_metadata) {

  nat.apply();

}



// deparser section
control DeparserImpl(packet_out b, in Parsed_headers p) {
  apply {
    b.emit(p.ethernet);
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
