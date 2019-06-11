#include <core.p4>
#define MAX_MPLS_LABELS 3

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

header MPLS_h {
    bit<20> label;
    bit<3> tc;
    bit bos;
    bit<8> ttl;
}

struct Parsed_headers {
    Ethernet_h ethernet;
    IPv4_h ip;
    MPLS_h[MAX_MPLS_LABELS] mpls_lbls;
}

error { 
    IPv4IncorrectVersion,
    IPv4OptionsNotSupported
}

struct ingress_metadata_t {
    bit<1> num_lbls;
    bit<32> next_hop;
}

parser TopParser(packet_in pin, out Parsed_headers ph, 
                 inout ingress_metadata_t meta, 
                 inout standard_metadata_t standard_metadata) {

    state start {
        meta.num_lbls = 0;
        transition parse_ethernet;
    }
 
    state parse_ethernet {
        pin.extract(ph.ethernet);
        transition select (ph.ethernet.etherType) {
           0x0800: parse_ipv4;
           0x8847: parse_mpls;
        }
    }
 
    state parse_mpls {
        pin.extract(ph.mpls_lbls.next);
        meta.num_lbls = meta.num_lbls + 1;
        transition select(ph.mpls_lbls.last.bos) {
           0: parse_mpls;
           1: parse_ipv4;
        }
    }
 
    state parse_ipv4 {
        pin.extract(ph.ip);
        verify(ph.ip.version == 4w4, error.IPv4IncorrectVersion);
        verify(ph.ip.ihl == 4w5, error.IPv4OptionsNotSupported);
        transition accept;
    }
}


