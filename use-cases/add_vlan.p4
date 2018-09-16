// Scenario:
// -> basic_switch.p4 is provided by vendor along with its controller.
// -> vlan feature is required to be added along with basic switching as usual
// for other ports.
// 
// Add VLAN support on basic ethernet switch - basic_switch.p4
// Semantic of this composition "Add" is following
// Tables in two programs contain overlapping matchkeys. 
// basic_switch forwards using destMac for native traffic and add_vlan(below
// program) forwards based on vlan tag and destMac.

#include <core.p4>
#include <v1model.p4>

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32

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

struct learn_digest_t {
  bit<48> ethSrcAddr;
  bit<9> ingressPort;
}

struct headers {
  @name("ethernet")
  Ethernet_h ethernet;
  @name("Vlan_tag_h")
  Vlan_tag_h vlan_tag;
}

// required metadata of struct of struct type
struct data {
  bit<8> md;
}
struct metadata {
  data d;
}

parser ParserImpl(packet_in packet, out headers hdr, inout metadata meta, 
                  inout standard_metadata_t standard_metadata) {
  state start {
    packet.extract(hdr.ethernet);
    transition select(hdr.ethernet.etherType) {
      0x8100: parse_vlan;
    // Parser accepts native ethernet frames.
    // If they are received from access port, vlan tag should be inserted
    transition accept;
    }
  }

  state parse_vlan {
    packet.extract(hdr.vlan_tag);
    transition accept;
  }
}
   
control DeparserImpl(packet_out packet, in headers hdr) {
  apply {
    packet.emit(hdr.ethernet);
    // If the frame is to be forwarded to access port, the tag should be removed. 
    packet.emit(hdr.vlan_tag);
  }
}


control ingress(inout headers hdr, inout metadata meta, inout 
                standard_metadata_t standard_metadata) {
  action nop() {}

  action mac_learn () {
    digest<learn_digest_t> (1, {hdr.ethernet.srcAddr,
                                standard_metadata.ingress_port});
  }

  action forward(bit<9> out_port) {
    // TODO: Add
    //standard_metadata.egress_port = out_port;
  }

  action broadcast() {
    // TODO: Add
    //standard_metadata.mcast_grp = 1;
  }

  // Use Case: vlan tagging is configured by control plane 
  // Table ingress port to vlan tag table
  table insert_vlan_tag {
    key = {
      standard_metadata.ingress_port : exact;
      hdr.vlan_tag.id;
    }
    actions = {
      // TODO: Add
      nop;
    }
    default_action = mac_learn;
  }

  // Implements basic ethernet switching 
  table dmac_switching {
    key = {
      hdr.ethernet.dstAddr : exact;
    }

    actions = {
      forward;
      broadcast;
    }
    default_action = broadcast;
  }

  apply {
    learn_notify.apply();
    dmac_switching.apply();
  }
}

control egress(inout headers hdr, inout metadata meta, 
               inout standard_metadata_t standard_metadata) {
 apply { 
  // This ingress-egress processing is enforced by the switch architecture.
  // Composition should be done on control flow graph representation.
 }
}

control verifyChecksum(in headers hdr, inout metadata meta) {
  apply { }
}

control computeChecksum(inout headers hdr, inout metadata meta) {
  apply { }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(),
         DeparserImpl()) main;

