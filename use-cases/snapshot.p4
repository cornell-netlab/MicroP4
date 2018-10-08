#include <core.p4>
#include <v1model.p4>

#define NUM_PIPELINE_STAGES 4
#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 32

/*
// P4C does not replace macro argument in action and table names
#define snapshot_table(stageNum)  action snapshot_data_stage_stageNum() { \
    hdr.snapshots[stageNum].setValid(); \
    hdr.snapshots[stageNum].ingress_port = standard_metadata.ingress_port; \
    hdr.snapshots[stageNum].ipv4_saddr = hdr.ipv4.sAddr; \
    hdr.snapshots[stageNum].ipv4_daddr = hdr.ipv4.sAddr; \
    hdr.snapshots[stageNum].my_ttl = hdr.ipv4.ttl; \
    hdr.snapshots[stageNum].l4_src_port = meta.srcPort; \
    hdr.snapshots[stageNum].l4_dst_port = meta.dstPort; \
  } \
  table snapshot_stageNum { \
    key = { \
      meta.my_counter: exact; \
    } \
    actions = { \
      increment_mycounter; \
      snapshot_data_stage_stageNum; \
    } \
    default_action = increment_mycounter(); \
  }
*/

// From following link
// https://github.com/jafingerhut/p4-guide/blob/master/v1model-special-ops/v1model-special-ops.p4
const bit<32> I2E_CLONE_SESSION_ID = 5;
const bit<32> E2E_CLONE_SESSION_ID = 11;


const bit<32> BMV2_V1MODEL_INSTANCE_TYPE_NORMAL        = 0;
const bit<32> BMV2_V1MODEL_INSTANCE_TYPE_INGRESS_CLONE = 1;
const bit<32> BMV2_V1MODEL_INSTANCE_TYPE_EGRESS_CLONE  = 2;
const bit<32> BMV2_V1MODEL_INSTANCE_TYPE_COALESCED     = 3;
const bit<32> BMV2_V1MODEL_INSTANCE_TYPE_RECIRC        = 4;
const bit<32> BMV2_V1MODEL_INSTANCE_TYPE_REPLICATION   = 5;
const bit<32> BMV2_V1MODEL_INSTANCE_TYPE_RESUBMIT      = 6;

#define IS_RESUBMITTED(std_meta) (std_meta.instance_type == BMV2_V1MODEL_INSTANCE_TYPE_RESUBMIT)
#define IS_RECIRCULATED(std_meta) (std_meta.instance_type == BMV2_V1MODEL_INSTANCE_TYPE_RECIRC)
#define IS_I2E_CLONE(std_meta) (std_meta.instance_type == BMV2_V1MODEL_INSTANCE_TYPE_INGRESS_CLONE)
#define IS_E2E_CLONE(std_meta) (std_meta.instance_type == BMV2_V1MODEL_INSTANCE_TYPE_EGRESS_CLONE)
#define IS_REPLICATED(std_meta) (std_meta.instance_type == BMV2_V1MODEL_INSTANCE_TYPE_REPLICATION)

header cpu_header_t {
  bit<64> preamble;
  bit<8>  device;
  bit<8>  reason;
  bit<8>  in_port;
  bit<8>  num_snapshot;
}

header ethernet_h {
  bit<48> dAddr;
  bit<48> sAddr;
  bit<16> etherType;
}

header vlan_tag_h {
  bit<3> priority;
  bit<1> cfi;
  bit<12> id;
  bit<16> etherType;
}

header ipv4_h {
  bit<64> unused;
  bit<8> ttl;
  bit<8> protocol;
  bit<16> hdrChecksum;
  bit<32> sAddr;
  bit<32> dAddr;
}


header tcp_h {
  bit<16> srcPort;
  bit<16> dstPort;
  bit<128> unused;
}
  

header udp_h {
  bit<16> srcPort;
  bit<16> dstPort;
  bit<16> len;
  bit<16> checksum;
}

header snapshot_data_h {
  bit<9> ingress_port;
  bit<32> ipv4_saddr;
  bit<32> ipv4_daddr;
  bit<8> my_ttl;
  bit<16> l4_src_port;
  bit<16> l4_dst_port;
}

struct headers {
  @name("cpu_header")
  cpu_header_t cpu_header;
  @name("ethernet")
  ethernet_h ethernet;
  @name("vlan_tag")
  vlan_tag_h vlan_tag;
  @name("IPv4_h")
  ipv4_h ipv4;
  @name("tcp")
  tcp_h tcp;
  @name("udp")
  udp_h udp;
  snapshot_data_h[NUM_PIPELINE_STAGES] snapshots;
}



struct ingress_data_t {
  int<16> my_counter;
  bit<16> srcPort;
  bit<16> dstPort;
}


parser ParserImpl(packet_in packet, out headers hdr, inout ingress_data_t meta, 
                  inout standard_metadata_t standard_metadata) {
  state start {
    packet.extract(hdr.ethernet);
    transition select(hdr.ethernet.etherType) {
      0x8100: parse_vlan;
      0x0800: parse_ipv4;
    }
  }

  state parse_vlan {
    packet.extract(hdr.vlan_tag);
    transition select(hdr.vlan_tag.etherType) {
      0x0800: parse_ipv4;
    }
  }

  state parse_ipv4 {
    packet.extract(hdr.ipv4);
    transition select(hdr.ipv4.protocol) {
        0x06: parse_tcp;
        0x11: parse_udp;
    }
  }

  state parse_tcp {
    packet.extract(hdr.tcp);
    meta.srcPort = hdr.tcp.srcPort;
    meta.dstPort = hdr.tcp.dstPort;
    transition accept;
  }

  state parse_udp {
    packet.extract(hdr.udp);
    meta.srcPort = hdr.udp.srcPort;
    meta.dstPort = hdr.udp.dstPort;
    transition accept;
  }
}

control ingress(inout headers hdr, inout ingress_data_t meta, inout 
                standard_metadata_t standard_metadata) {

  action increment_mycounter() {
    meta.my_counter = meta.my_counter + 1;
  }

  /*
  action do_clone_i2e() { 
    clone3(CloneType.I2E, I2E_CLONE_SESSION_ID, standard_metadata);
  }
  */


  action snapshot_data_stage_0 () {
    hdr.snapshots[0].setValid();
    hdr.snapshots[0].ingress_port = standard_metadata.ingress_port;
    hdr.snapshots[0].ipv4_saddr = hdr.ipv4.sAddr;
    hdr.snapshots[0].ipv4_daddr = hdr.ipv4.sAddr;
    hdr.snapshots[0].my_ttl = hdr.ipv4.ttl;
    hdr.snapshots[0].l4_src_port = meta.srcPort;
    hdr.snapshots[0].l4_dst_port = meta.dstPort;
    hdr.cpu_header.num_snapshot = 1;
  }

  table snapshot_0 {
    key = {
      meta.my_counter: exact;
    }
    actions = {
      increment_mycounter;
      snapshot_data_stage_0;
    }
    default_action = increment_mycounter();
  }

  action snapshot_data_stage_1 () {
    hdr.snapshots[1].setValid();
    hdr.snapshots[1].ingress_port = standard_metadata.ingress_port;
    hdr.snapshots[1].ipv4_saddr = hdr.ipv4.sAddr;
    hdr.snapshots[1].ipv4_daddr = hdr.ipv4.sAddr;
    hdr.snapshots[1].my_ttl = hdr.ipv4.ttl;
    hdr.snapshots[1].l4_src_port = meta.srcPort;
    hdr.snapshots[1].l4_dst_port = meta.dstPort;
    hdr.cpu_header.num_snapshot = hdr.cpu_header.num_snapshot + 1;
  }

  table snapshot_1 {
    key = {
      meta.my_counter: exact;
    }
    actions = {
      increment_mycounter;
      snapshot_data_stage_1;
    }
    default_action = increment_mycounter();
  }

  action snapshot_data_stage_2 () {
    hdr.snapshots[2].setValid();
    hdr.snapshots[2].ingress_port = standard_metadata.ingress_port;
    hdr.snapshots[2].ipv4_saddr = hdr.ipv4.sAddr;
    hdr.snapshots[2].ipv4_daddr = hdr.ipv4.sAddr;
    hdr.snapshots[2].my_ttl = hdr.ipv4.ttl;
    hdr.snapshots[2].l4_src_port = meta.srcPort;
    hdr.snapshots[2].l4_dst_port = meta.dstPort;
    hdr.cpu_header.num_snapshot = hdr.cpu_header.num_snapshot + 1;
  }

  table snapshot_2 {
    key = {
      meta.my_counter: exact;
    }
    actions = {
      increment_mycounter;
      snapshot_data_stage_2;
    }
    default_action = increment_mycounter();
  }

  action snapshot_data_stage_3  () {
    hdr.snapshots[3].setValid();
    hdr.snapshots[3].ingress_port = standard_metadata.ingress_port;
    hdr.snapshots[3].ipv4_saddr = hdr.ipv4.sAddr;
    hdr.snapshots[3].ipv4_daddr = hdr.ipv4.sAddr;
    hdr.snapshots[3].my_ttl = hdr.ipv4.ttl;
    hdr.snapshots[3].l4_src_port = meta.srcPort;
    hdr.snapshots[3].l4_dst_port = meta.dstPort;
    hdr.cpu_header.num_snapshot = hdr.cpu_header.num_snapshot + 1;
  }

  table snapshot_3 {
    key = {
      meta.my_counter: exact;
    }
    actions = {
      increment_mycounter;
      snapshot_data_stage_3;
    }
    default_action = increment_mycounter();
  }


  apply {
    snapshot_0.apply();
    snapshot_1.apply();
    snapshot_2.apply();
    snapshot_3.apply();
  }
}

control egress(inout headers hdr, inout ingress_data_t meta, 
               inout standard_metadata_t standard_metadata) {

  action do_clone_e2e() {
    clone3(CloneType.E2E, E2E_CLONE_SESSION_ID, standard_metadata);
  }
  apply {
    if (IS_E2E_CLONE(standard_metadata)) {
      hdr.cpu_header.setValid();
    } else {
      do_clone_e2e();
    }
  }
}

control DeparserImpl(packet_out packet, in headers hdr) {
  apply {
    packet.emit(hdr.cpu_header);
    packet.emit(hdr.snapshots);
    packet.emit(hdr.ethernet);
    packet.emit(hdr.vlan_tag);
    packet.emit(hdr.ipv4);
    packet.emit(hdr.udp);
    packet.emit(hdr.tcp);
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

