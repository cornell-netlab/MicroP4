#include <core.p4>
#include <csa.p4>
#include "common.p4"

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32



/////////////////////////////////////////////////////////////

header L2_Ethernet_h {
  bit<48> dstAddr;
  bit<48> srcAddr;
  bit<16> etherType;
}

struct L2_parsed_headers_t {
  L2_Ethernet_h ethernet;
}

struct L2_my_metadata_t {
  bit<8> if_index;
  bit<32> next_hop;
}

cpackage l2 : implements CSASwitch<external_meta_t, empty_t, empty_t, 
                                       L2_parsed_headers_t, L2_my_metadata_t,
                                       empty_t> {


  // Declarations for programmable blocks of basic switch package type
  parser csa_parser(packet_in pin, out L2_parsed_headers_t parsed_hdr, 
                inout L2_my_metadata_t meta, 
                inout csa_standard_metadata_t standard_metadata) {

    state start {
      // This is a sample metadata update.
      meta.if_index = (bit<8>)standard_metadata.ingress_port;
      transition parse_ethernet;
    }

    state parse_ethernet {
      pin.extract(parsed_hdr.ethernet);
      transition accept;
    }
  }
  
    control csa_import(in external_meta_t in_meta, inout empty_t inout_meta, 
                   in L2_parsed_headers_t parsed_hdr, inout L2_my_metadata_t meta, 
                   inout csa_standard_metadata_t standard_metadata, egress_spec es) {
 
        action set_input_parameters () {
            meta.next_hop = in_meta.next_hop;
        }
       
        apply {
            set_input_parameters();
        }
    }
 
    control csa_pipe(inout L2_parsed_headers_t parsed_hdr, inout L2_my_metadata_t meta,
               inout csa_standard_metadata_t standard_metadata, egress_spec es) {

        action set_dmac(bit<48> dmac, bit<9> port) {
          // P4Runtime error...
            es.set_egress_port(port);
            parsed_hdr.ethernet.dstAddr = dmac;
        }

        action drop_action() {
            standard_metadata.drop_flag = true;
        }
 
        table dmac {
            key = { meta.next_hop: exact; }
            actions = {
                drop_action;
                set_dmac;
            }
            const entries = {
                0x0a000201 : set_dmac(0x000000000002, 9w2);
                0x0a000301 : set_dmac(0x000000000003, 9w3);
            }
            default_action = drop_action;
            // size = TABLE_SIZE;
        }
 
        action set_smac(bit<48> smac) {
            parsed_hdr.ethernet.srcAddr = smac;
        }
 
        table smac {
            key = {  es.get_egress_port() : exact @name("egress_port"); }
            actions = {
                drop_action;
                set_smac;
            }
            default_action = drop_action;
            const entries = {
                9w2 : set_smac(0x000000000020);
                9w3 : set_smac(0x000000000030);
            }
            // size = MAC_TABLE_SIZE;
        }
 
        table drop_table{
            key = { 
                es.get_value(csa_metadata_fields_t.QUEUE_DEPTH_AT_DEQUEUE) 
                  : exact @name("depth_at_dequeue") ;
            }
            actions = {
                drop_action;
                NoAction;
            }
            /*
            const entries = {
                16w5 : drop_action();
            }
            */
            size = MAC_TABLE_SIZE;
            default_action = NoAction;
        }

        apply {
            dmac.apply(); 
            drop_table.apply();
            // if (!drop_table.apply().hit)
            smac.apply();
        }
    }

 
    control csa_deparser(packet_out po, in L2_parsed_headers_t parsed_hdr) {
        apply {
            po.emit(parsed_hdr.ethernet);
        }
    }
}

