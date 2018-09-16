/*
 * IPv4 router with ACL checks, it modifies layer 2 header also
 * Functionality - IPv4 processing, ACL and routing
 */

# include <core.p4>
#include <v1model.p4>

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32

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

struct Parsed_headers {
  @name("ethernet")
  Ethernet_h ethernet;
  @name("ip")
  IPv4_h ip;
}

error { 
  IPv4IncorrectVersion,
  IPv4OptionsNotSupported
}


struct ingress_metadata_t {
  bit<32> nextHop;
}


parser TopParser(packet_in b, out Parsed_headers p, inout ingress_metadata_t meta, 
                  inout standard_metadata_t standard_metadata) {

  // checksum and local variable intialization
  state start {
    b.extract(p.ethernet);
    transition select (p.ethernet.etherType) {
      0x0800: parse_ipv4;
    }
  }

  state parse_ipv4 {
    b.extract(p.ip);
    verify(p.ip.version == 4w4, error.IPv4IncorrectVersion);
    verify(p.ip.ihl == 4w5, error.IPv4OptionsNotSupported);
    transition accept;
  }

}


control ingress(inout Parsed_headers headers, inout ingress_metadata_t  meta,
                inout standard_metadata_t standard_metadata) {
  
  action set_nexthop(bit<32> nexthop_ipv4_address, bit<9> port) {
    // TODO: update ttl and other header fields
    // Not of a concern for now
    meta.nextHop = nexthop_ipv4_address;
    standard_metadata.egress_port = port;
  }

  action send_to_cpu() {
    // TODO: how does V1model send it to cpu
    //standard_metadata.egress_port = CPU_OUT_PORT;
  }


  action drop_action() {
    mark_to_drop();
  }

  // ACL check
  table ipv4_acl {
    key = {
      headers.ip.srcAddr : ternary;
      headers.ip.dstAddr : ternary;
      headers.ip.protocol : ternary;
    }
    actions = {
      drop_action;
      set_nexthop;
    }

    size = TABLE_SIZE;
  }

  // next hop routing
  table ipv4_fib_lpm {
    key = {
      headers.ip.dstAddr : lpm;
    }
    actions = {
      send_to_cpu;
      set_nexthop;
    }

    size = TABLE_SIZE;
  }


  /***************************************************************************/
  /* If architecture allows following code can go in egress processing       */
  /* Composition is switch arch file dependent..                             */
  /***************************************************************************/
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
  /***************************************************************************/

  apply {
    if (standard_metadata.parser_error != error.NoError) {
      drop_action();
      return;
    }

    /*
     Why can't we store automatically synthesized table.apply result in a generic
     struct instance
     if (ipv4_acl.apply().action_run == drop_action)
      return;
    */

    if (!ipv4_acl.apply().hit) {
      ipv4_fib_lpm.apply();
    }


  /***************************************************************************/
  // Two options for composition:
  // Option 1: Here overridden control bloack can be called from other already
  // compiled program (maclearning or  l2switch.p4 ) can be called. But, need to 
  // decide mechanism. interface and abstraction for overriding. This is 
  // incremental rather than composition.
  //
  // Option 2: No sharing of control processing, ipv4 process the entire 
  // packet including mac address and interface set up.

  // Layer 2 functionality
  /***************************************************************************/
    dmac.apply();
    //if(dmac.apply().action_run == drop_action);
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
    b.emit(p.ethernet);
    b.emit(p.ip);
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
      p.ip.srcAddr, 
      p.ip.dstAddr
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
      p.ip.srcAddr,
      p.ip.dstAddr
    }, p.ip.hdrChecksum, HashAlgorithm.csum16);
  }
}


V1Switch(TopParser(), verifyChecksum(), ingress(), egress(), computeChecksum(),
         DeparserImpl()) main;
