#include <core.p4>

header Ethernet_h {
    bit<96> addrs;
    bit<16> etherType;
}

header IPv4_h {
    bit<72> data1;
    bit<8> protocol;
    bit<80> data2;
}

header VLan_h {
    bit<3> priority;
    bit<1> cfi;
    bit<12> id;
    bit<16> etherType;
}

struct Parsed_headers {
    Ethernet_h ethernet;
    IPv4_h ip;
    VLan_h vlan;
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
            0x8100: parse_vlan;
        }
    }

    state parse_vlan {
        pin.extract(ph.vlan);
        transition select(ph.vlan.etherType) {
            0x0800: parse_ipv4;
        }
    }
 
    state parse_ipv4 {
        pin.extract(ph.ip);
        transition accept;
    }

    /*
    state parse_ipv4 {
        pin.extract(ph.ip);
        transition select(ph.ip.protocol) {
            0x0110: parse_tcp;
             _: accept;
        }
    }
    
    state parse_tcp {
        pin.extract(ph.tcp);
        transition accept;
    }
    */

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
