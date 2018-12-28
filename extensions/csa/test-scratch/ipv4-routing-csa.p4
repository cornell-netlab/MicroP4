#include <core.p4>
#include <csa.p4>
#include "l2switch.ip4"

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32

cpackage Router : implements CSASwitch { 
// All the names under CSASwitch are visible under the "Router".
// Non Optional architecture blocks are matched based on name and their types
// unified. It is possible to match them and unify using signatures, but for
// initial implementation, kept it simple.
// All the type parameters of CSASwitch are unified in conjuction of programmable
// blocks.

  header Ethernet_h {
    bit<96> unused;
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

  struct parsed_headers_t {
    @name("ethernet")
    Ethernet_h ethernet;
    @name("ip")
    IPv4_h ip;
  }

  error { 
    IPv4IncorrectVersion,
    IPv4OptionsNotSupported
  }

  struct router_metadata_t {
    bit<8> if_index;
    bit<32> next_hop;
  }

  // Declarations for programmable blocks of basic switch cpackage type
  parser Parser(packet_in pin, out parsed_headers_t parsed_hdr, 
                  inout router_metadata_t meta, 
                  inout standard_metadata_t standard_metadata, 
                  in empty_t program_scope_metadata) {
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
      verify(parsed_hdr.ip.version == 4w4, error.IPv4IncorrectVersion);
      verify(parsed_hdr.ip.ihl == 4w5, error.IPv4OptionsNotSupported);
      transition accept;
    }
  }
  
  control Pipe(inout parsed_headers_t parsed_hdr, inout router_metadata_t meta,
               inout standard_metadata_t standard_metadata,
               egress_spec es) {

    external_meta_t external_meta;
    empty_t empty1;
    empty_t empty2;
    empty_t empty;

    // instantiation
    Layer2Switch() l2_switch_inst;

    ExecuteSwitch(l2_switch_inst)  exec_l2;

    action set_nexthop(bit<32> nexthop_ipv4_addr, bit<8> port) {
      parsed_hdr.ip.ttl = parsed_hdr.ip.ttl-1;
      // meta.next_hop = nexthop_ipv4_addr;
      external_meta.next_hop = nexthop_ipv4_addr;
      es.set_egress_port(port);
      // standard_metadata.egress_spec = port;
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

      default_action = send_to_cpu();
      size = TABLE_SIZE;
    }

    apply {
      ipv4_fib_lpm.apply();
      
      // invoking layer 2 switch
      exec_l2.apply(empty1, external_meta, empty2,
                    parsed_hdr, meta, standard_metadata);

      /*
       * Another alternative way would be not executing layer2_switch_inst here.
       * Instead, write 3rd program using OrchestrationSwitch and in its Pipe
       * control call instaces of ipv4 and Layer2Switch.
       */
    }
  }

  control Export(out external_meta_t out_meta, inout empty_t inout_meta, 
                 in parsed_headers_t parsed_hdr, in router_metadata_t meta,
                 in standard_metadata_t standard_metadata, egress_spec es) {
    action set_return_parameters () {
      out_meta.next_hop = meta.next_hop;
    }

    apply {
      set_return_parameters();
    }
  }
  
  control Deparser(packet_out po, in parsed_headers_t parsed_hdr,
                   out empty_t program_scope_metadata) {
    apply {
      po.emit(parsed_hdr.ethernet);
      po.emit(parsed_hdr.ip);
    }
  }

}
Router() main;
