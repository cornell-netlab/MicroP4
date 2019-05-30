# include <core.p4>
// TODO: enable STP and ARP handling
// Or Code it as another independent module adding features in layer 2
// Control Block overriding or function pointer like mechanism to call control
// block. but open question how to be sure that the same header fields will be
// processed. In this case, have to expose parser/header fields.

#include <v1model.p4>
 #define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32
 header Ethernet_h {
  bit<48> dstAddr;
  bit<48> srcAddr;
}
 struct learn_digest_t {
  bit<48> ethSrcAddr;
  bit<9> ingressPort;
}
 struct headers {
  @name("ethernet")
  Ethernet_h ethernet;
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
    transition accept;
  }
}
   
control DeparserImpl(packet_out packet, in headers hdr) {
  apply {
    packet.emit(hdr.ethernet);
  }
}
 control ingress(inout headers hdr, inout metadata meta, inout 
                standard_metadata_t standard_metadata) {

  data da;
  action nop() {}
  action mac_learn () {
    digest<learn_digest_t> (1, {hdr.ethernet.srcAddr,
                                standard_metadata.ingress_port});
  }
   action forward(bit<9> out_port) {
    standard_metadata.egress_port = out_port;
    da.md = 0;
  }
   action broadcast() {
    standard_metadata.mcast_grp = 1;
  }
   table learn_notify {
    key = {
      hdr.ethernet.srcAddr : exact;
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
      hdr.ethernet.dstAddr : exact;
    }
     actions = {
      forward;
      broadcast;
    }
    default_action = broadcast();
  }
   apply {
    //learn_notify.apply();
    dmac_switching.apply();
  }
}
 control egress(inout headers hdr, inout metadata meta, 
               inout standard_metadata_t standard_metadata) {
 apply { }
}
 control verifyChecksum(inout headers hdr, inout metadata meta) {
  apply { }
}
 control computeChecksum(inout headers hdr, inout metadata meta) {
  apply { }
}
 V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(),
         DeparserImpl()) main;

