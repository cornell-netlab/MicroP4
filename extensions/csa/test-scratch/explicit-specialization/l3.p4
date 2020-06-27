#include <core.p4>
#include <csa.p4>
#include "structures.p4"

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32

header L3_Ethernet_h {
    bit<96> unused;
    bit<16> etherType;
}

header L3_IPv4_h {
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

struct L3_parsed_headers_t {
    L3_Ethernet_h ethernet;
    L3_IPv4_h ip;
}


struct L3_router_metadata_t {
    bit<8> if_index;
    bit<32> next_hop;
}

cpackage Layer3 : implements CSASwitch<empty_t, external_meta_t, empty_t, 
                                       L3_parsed_headers_t, 
                                       L3_router_metadata_t, empty_t> { 

  // Declarations for programmable blocks of basic switch cpackage type
    parser csa_parser(packet_in pin, out L3_parsed_headers_t parsed_hdr, 
                    inout L3_router_metadata_t meta, 
                    inout csa_standard_metadata_t standard_metadata) {
        state start {
            // This is a sample metadata update.
            meta.if_index = (bit<8>)standard_metadata.ingress_port;
            transition parse_ethernet;
        }
       
        state parse_ethernet {
            pin.extract(parsed_hdr.ethernet);
            transition select (parsed_hdr.ethernet.etherType) {
              0x0800: parse_ipv4;
            }
        }
       
        state parse_ipv4 {
            pin.extract(parsed_hdr.ip);
            transition accept;
        }
    }
  
    control csa_pipe(inout L3_parsed_headers_t parsed_hdr, inout L3_router_metadata_t meta,
                 inout csa_standard_metadata_t standard_metadata, egress_spec es) {
 
        external_meta_t external_meta;
        empty_t empty1;
        empty_t empty2;
        empty_t empty;
       
        action set_nexthop(bit<32> nexthop_ipv4_addr, bit<9> port) {
            // parsed_hdr.ip.ttl = parsed_hdr.ip.ttl-1;
            meta.next_hop = nexthop_ipv4_addr;
            es.set_egress_port(port);
        }
       
        action drop_action() {
            standard_metadata.drop_flag = true;
        }
       
        action send_to_cpu() {
            // es call
            ;
        }
       
        // next hop routing
        table ipv4_fib_lpm {
            key = {
                parsed_hdr.ip.dstAddr : lpm;
            }      
            actions = {
                send_to_cpu;
                set_nexthop;
            }
           
            const entries = {
                0x0a000200 &&& 0xffffff00 : set_nexthop(0x0a000201, 9w2);
                0x0a000300 &&& 0xffffff00 : set_nexthop(0x0a000301, 9w3);
            }

            default_action = send_to_cpu();

            // size = TABLE_SIZE;
        }
       
        apply {
            ipv4_fib_lpm.apply();
        }
    }

    control csa_export(out external_meta_t out_meta, inout empty_t inout_meta, 
                   in L3_parsed_headers_t parsed_hdr, in L3_router_metadata_t meta,
                   in csa_standard_metadata_t standard_metadata, egress_spec es) {
        action set_return_parameters() {
            out_meta.next_hop = meta.next_hop;
        }
        apply {
            set_return_parameters();
        }
    }

    control csa_deparser(packet_out po, in L3_parsed_headers_t parsed_hdr) {
        apply {
            po.emit(parsed_hdr.ethernet);
            po.emit(parsed_hdr.ip);
        }
    }
}
