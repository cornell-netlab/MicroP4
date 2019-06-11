#include <core.p4>
#define MAX_MPLS_LABELS 3

header Ethernet_h {
    bit<96> addrs;
    bit<16> etherType;
}

header IPv4_h {
    bit<160> data;
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

struct ingress_metadata_t { }

parser TopParser(packet_in pin, out Parsed_headers ph, 
                 inout ingress_metadata_t meta) {

    state start {
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
        transition select(ph.mpls_lbls.last.bos) {
            0: parse_mpls;
            1: parse_ipv4;
        }
    }
 
    state parse_ipv4 {
        pin.extract(ph.ip);
        transition accept;
    }
}


/* Unrolled parser */
/*
parser TopParser(packet_in pin, out Parsed_headers ph, 
                 inout ingress_metadata_t meta) {

    state start {
        transition parse_ethernet;
    }
 
    state parse_ethernet {
        pin.extract(ph.ethernet);
        transition select (ph.ethernet.etherType) {
            0x0800: parse_ipv4;
            0x8847: parse_mpls_0;
        }
    }

    state parse_mpls_0 {
        pin.extract(ph.mpls_lbls[0]);
        transition select(ph.mpls_lbls[0].bos) {
            0: parse_mpls_1;
            1: parse_ipv4;
        }
    }

    state parse_mpls_1 {
        pin.extract(ph.mpls_lbls[1]);
        transition select(ph.mpls_lbls[1].bos) {
            0: parse_mpls_2;
            1: parse_ipv4;
        }
    }

    state parse_mpls_2 {
        pin.extract(ph.mpls_lbls[2]);
        transition select(ph.mpls_lbls[2].bos) {
            1: parse_ipv4;
        }
    }
 
    state parse_ipv4 {
        pin.extract(ph.ip);
        transition accept;
    }
}
*/
