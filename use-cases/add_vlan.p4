// Scenario: Slicing the switch or horizontal composition
// -> basic_switch.p4 is provided by vendor along with its controller.
// -> vlan feature is required to be added along with basic switching as usual
// for other ports. 
// 
// Add VLAN support on basic ethernet switch - basic_switch.p4
// Semantic of this composition "Add" is following
// Tables in two programs contain overlapping matchkeys. 
// basic_switch forwards using destMac for native traffic and add_vlan(below
// program) forwards based on vlan tag and destMac.
// 
// Is it possible to have native ethernet traffic coming from Access ports should
// have fallback processing by basic_switch.p4. May be useful in alpha-testing of
// the feature.

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
struct ingress_data_t {
  bit<12> tag_id;
}

/*
struct metadata {
  ingress_data_t d;
}
*/

parser ParserImpl(packet_in packet, out headers hdr, inout ingress_data_t meta, 
                  inout standard_metadata_t standard_metadata) {
  state start {
    packet.extract(hdr.ethernet);
    transition select(hdr.ethernet.etherType) {
      0x8100: parse_vlan;
      // Parser accepts native ethernet frames.
      // If they are received from access port, this program inserts an
      // approperiate vlan tag
      default: accept;
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
    // If the frame is to be forwarded to access port, the program removes the
    // vlan tag
    packet.emit(hdr.vlan_tag);
  }
}


control ingress(inout headers hdr, inout ingress_data_t meta, inout 
                standard_metadata_t standard_metadata) {
  action nop() {}

  action mac_learn () {
    digest<learn_digest_t> (1, {hdr.ethernet.srcAddr,
                                standard_metadata.ingress_port});
  }

  action forward_on_trunc_port (bit<9> port) {

  }

  action forward_on_access_port (bit<9> port) {
    hdr.ethernet.etherType = hdr.vlan_tag.etherType;
    hdr.vlan_tag.setInvalid();
  }

  action forward(bit<9> out_port) {
    standard_metadata.egress_port = out_port;
  }

  action broadcast_on_vlan(bit<12> id) {
    // May be clone on multiple egress port>
    // And, if one of the port is access port, remove the vlan tag
  }


  // Sets the tag id on the frames received from access ports
  action set_tag_id(bit<12> id) {
    // May be clone on multiple egress port>
  }

  // This action can be used to notify controller about miss in vlan port mapping
  action send_to_cpu() {

  }

  // vlan tagging is configured by control plane 
  // Table ingress port to vlan tag table
  table port_vlan_mapping {
    key = {
      standard_metadata.ingress_port : exact;
    }
    actions = {
      send_to_cpu;
      set_tag_id;
      nop;
    }
    default_action = send_to_cpu;
  }

  table learn_notify {
    key = {
      hdr.ethernet.srcAddr : exact;
      hdr.vlan_tag.id : exact;
      standard_metadata.ingress_port : exact;
    }
    actions = {
      nop;
      mac_learn;
    }
    default_action = mac_learn;
  }

  // Implements basic ethernet switching 
  table dmac_switching {
    key = {
      hdr.vlan_tag.id : exact;
      hdr.ethernet.dstAddr : exact;
    }

    actions = {
      forward_on_trunc_port;
      forward_on_access_port;
      broadcast_on_vlan;
    }
    default_action = broadcast_on_vlan;
  }

  apply {
    if (!hdr.vlan_tag.isValid())
      port_vlan_mapping.apply();
    learn_notify.apply();
    dmac_switching.apply();
  }
}

control egress(inout headers hdr, inout ingress_data_t meta, 
               inout standard_metadata_t standard_metadata) {
 apply { 
  // This ingress-egress processing is enforced by the switch architecture.
  // Composition should be done on control flow graph representation.
 }
}

control verifyChecksum(inout headers hdr, inout ingress_data_t meta) {
  apply { }
}

control computeChecksum(inout headers hdr, inout ingress_data_t meta) {
  apply { }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(),
         DeparserImpl()) main;

