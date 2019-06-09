/*
 *  Composing 2 ethernet switches with a router connected in star topology with
 *  router as a central node.
 *  The router provides routing across the two broadcast domains.
 *  It does not manage any physical port or interface.
 *  -------------------
 *  | s1 --- R --- s2 |
 *  -------------------
 *  The composed data plane can provide switching to 4 ethernet switches and
 *  routing across them.
 */


# include <core.p4>
#include <v1model.p4>

#define TABLE_SIZE 1024
#define MAC_TABLE_SIZE 1024

header cpu_header_router_h {
  bit<64> preamble;
  bit<8>  device;
  bit<8>  reason;
  // Router's if_index is virtual
  bit<8>  if_index;
}

header cpu_header_switch_h {
  bit<64> preamble;
  bit<8>  device;
  bit<8>  reason;
  bit<9>  if_index;
}


header Ethernet_h {
  bit<48> dstAddr;
  bit<48> srcAddr;
  bit<16> etherType;
}

struct s1_learn_digest_t {
  bit<48> ethSrcAddr;
  bit<9> ingressPort;
}

struct s2_learn_digest_t {
  bit<48> ethSrcAddr;
  bit<9> ingressPort;
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


// Initialize constant MACs and virtual port ids 
struct composition_metadata_t {
  bit<48> rtr_s1_mac;
  bit<48> rtr_s2_mac;
  bit<9> rtr_s1_port;
  bit<9> rtr_s2_port;
}

struct Parsed_headers {
  @name("cpu_header_switch")
  cpu_header_switch_h  cpu_header_switch;
  @name("cpu_header_router")
  cpu_header_router_h  cpu_header_router;
  @name("ethernet")
  Ethernet_h ethernet;
  @name("ip")
  IPv4_h ip;
}

error { 
  IPv4IncorrectVersion,
  IPv4OptionsNotSupported
}

struct s1_metadata_t {
  bit<16> bd;
  bit<9> if_index;
}

struct s2_metadata_t {
  bit<16> bd;
  bit<9> if_index;
}

struct router_metadata_t {
  bit<32> nextHop;
  bit<8> if_index;
//  standard_metadata_t router_standard_metadata;
}

struct metadata_t {
  s1_metadata_t s1_meta;
  s2_metadata_t s2_meta;
  router_metadata_t router_meta;
  composition_metadata_t composition_meta;
}

parser TopParser(packet_in b, out Parsed_headers p, inout metadata_t meta, 
                  inout standard_metadata_t standard_metadata) {

  state start {
    //meta.if_index = (bit<8>)standard_metadata.ingress_port;
    transition select((b.lookahead<bit<64>>())[63:0]) {
      64w0:     parse_cpu_header;
      default:  parse_ethernet;
    }
  }

  // There is multiple way to inject packet in data plane from control plane.
  // 1. dedicated CPU port
  // 2. Use one of the data plane port as CPU port and send packet encapsulated
  // in it to the port.A
  // Need to think how to address 2. case while composing single data plane.
  state parse_cpu_header {
    // b.extract(p.cpu_header);
    // Which header to extract?
    // Is it  to decide based on if_index/ingress_port)?
    b.extract(p.cpu_header_switch);
    // b.extract(p.cpu_header_router);
    // meta.if_index = p.cpu_header.if_index;
    transition parse_ethernet;
  }

  state parse_ethernet {
    b.extract(p.ethernet);
    transition select (p.ethernet.etherType) {
      0x0800: parse_ipv4;
      default: accept; 
    }
  }

  state parse_ipv4 {
    b.extract(p.ip);
    verify(p.ip.version == 4w4, error.IPv4IncorrectVersion);
    verify(p.ip.ihl == 4w5, error.IPv4OptionsNotSupported);
    transition accept;
  }

}


control ingress(inout Parsed_headers headers, inout metadata_t  meta,
                inout standard_metadata_t standard_metadata) {
  

/********************* Switch S1 actions *******************/
  action s1_nop() {}
  action s1_mac_learn () {
    digest<s1_learn_digest_t> (1, {headers.ethernet.srcAddr,
                                standard_metadata.ingress_port});
  }

  action s1_forward(bit<9> out_port) {
    standard_metadata.egress_spec = out_port;
  }

  action s1_broadcast_to_hosts() {
    standard_metadata.mcast_grp = 1;
  }

  action s1_set_bd (bit<16> bd) {
    meta.s1_meta.bd = bd;
  }
  action s1_broadcast() {
    standard_metadata.mcast_grp = 1;
  }

  action s1_send_to_cpu(bit<8> reason, bit<9> cpu_port) {
    headers.cpu_header_switch.setValid();
    headers.cpu_header_switch.preamble = 64w0;
    headers.cpu_header_switch.device = 8w0;
    headers.cpu_header_switch.reason = reason;
    headers.cpu_header_switch.if_index = standard_metadata.ingress_port;
    standard_metadata.egress_spec = cpu_port;
  }
/**********************************************************/

/********************* Switch S2 actions *******************/
  action s2_nop() {}
  action s2_mac_learn () {
    digest<s2_learn_digest_t> (1, {headers.ethernet.srcAddr,
                                standard_metadata.ingress_port});
  }

  action s2_forward(bit<9> out_port) {
    standard_metadata.egress_spec = out_port;
  }

  action s2_broadcast_to_hosts() {
    standard_metadata.mcast_grp = 1;
  }

  action s2_set_bd (bit<16> bd) {
    meta.s2_meta.bd = bd;
  }
  action s2_broadcast() {
    standard_metadata.mcast_grp = 1;
  }

  action s2_send_to_cpu(bit<8> reason, bit<9> cpu_port) {
    headers.cpu_header_switch.setValid();
    headers.cpu_header_switch.preamble = 64w0;
    headers.cpu_header_switch.device = 8w0;
    headers.cpu_header_switch.reason = reason;
    headers.cpu_header_switch.if_index = standard_metadata.ingress_port;
    standard_metadata.egress_spec = cpu_port;
  }
/**********************************************************/



/*********************  Switch S1 tables *******************/
  table s1_learn_notify {
    key = {
      headers.ethernet.srcAddr : exact;
      standard_metadata.ingress_port : exact;
    }
    actions = {
      s1_nop;
      s1_mac_learn;
    }
    default_action = s1_mac_learn;
  }

  table s1_smac_bd {
    key = {
      headers.ethernet.srcAddr : exact;
    }
    actions = {
      s1_set_bd;
    }
    size = MAC_TABLE_SIZE;
  }

  // Implements basic ethernet switching
  table s1_dmac_switching {
    key = {
      headers.ethernet.dstAddr : exact;
      meta.s1_meta.bd: exact;
    }
    actions = {
      s1_forward;
      s1_broadcast;
      // For ARP broadcasts
      s1_broadcast_to_hosts;
      s1_send_to_cpu;
    }
    size = MAC_TABLE_SIZE;
    default_action = s1_broadcast;
  }
/**********************************************************/


/********************* Switch S1 dup tables ***************/
  table s1_dup_learn_notify {
    key = {
      headers.ethernet.srcAddr : exact;
      standard_metadata.ingress_port : exact;
    }
    actions = {
      s1_nop;
      s1_mac_learn;
    }
    default_action = s1_mac_learn;
  }

  table s1_dup_smac_bd {
    key = {
      headers.ethernet.srcAddr : exact;
    }
    actions = {
      s1_set_bd;
    }
    size = MAC_TABLE_SIZE;
  }

  // Implements basic ethernet switching
  table s1_dup_dmac_switching {
    key = {
      headers.ethernet.dstAddr : exact;
      meta.s1_meta.bd: exact;
    }
    actions = {
      s1_forward;
      s1_broadcast;
      // For ARP broadcasts
      s1_broadcast_to_hosts;
      s1_send_to_cpu;
    }
    size = MAC_TABLE_SIZE;
    default_action = s1_broadcast;
  }
/**********************************************************/


/*********************  Switch S2 tables *******************/
  table s2_learn_notify {
    key = {
      headers.ethernet.srcAddr : exact;
      standard_metadata.ingress_port : exact;
    }
    actions = {
      s2_nop;
      s2_mac_learn;
    }
    default_action = s2_mac_learn;
  }

  table s2_smac_bd {
    key = {
      headers.ethernet.srcAddr : exact;
    }
    actions = {
      s2_set_bd;
    }
    size = MAC_TABLE_SIZE;
  }

  // Implements basic ethernet switching
  table s2_dmac_switching {
    key = {
      headers.ethernet.dstAddr : exact;
      meta.s2_meta.bd: exact;
    }
    actions = {
      s2_forward;
      s2_broadcast;
      // For ARP broadcasts
      s2_broadcast_to_hosts;
      s2_send_to_cpu;
    }
    size = MAC_TABLE_SIZE;
    default_action = s2_broadcast;
  }
/**********************************************************/
/*********************  Switch S2 dup tables **************/
  table s2_dup_learn_notify {
    key = {
      headers.ethernet.srcAddr : exact;
      standard_metadata.ingress_port : exact;
    }
    actions = {
      s2_nop;
      s2_mac_learn;
    }
    default_action = s2_mac_learn;
  }

  table s2_dup_smac_bd {
    key = {
      headers.ethernet.srcAddr : exact;
    }
    actions = {
      s2_set_bd;
    }
    size = MAC_TABLE_SIZE;
  }

  // Implements basic ethernet switching
  table s2_dup_dmac_switching {
    key = {
      headers.ethernet.dstAddr : exact;
      meta.s2_meta.bd: exact;
    }
    actions = {
      s2_forward;
      s2_broadcast;
      // For ARP broadcasts
      s2_broadcast_to_hosts;
      s2_send_to_cpu;
    }
    size = MAC_TABLE_SIZE;
    default_action = s2_broadcast;
  }
/**********************************************************/


/********************* Router actions *********************/
  action router_set_nexthop(bit<32> nexthop_ipv4_addr, bit<9> port) {
    headers.ip.ttl = headers.ip.ttl-1;
    meta.router_meta.nextHop = nexthop_ipv4_addr;
    standard_metadata.egress_spec = port;
  }

  action router_set_smac(bit<48> smac) {
    headers.ethernet.srcAddr = smac;
  }

  action router_set_dmac(bit<48> dmac) {
    headers.ethernet.dstAddr = dmac;
  }

  action router_send_to_cpu(bit<8> reason, bit<9> cpu_port) {
    headers.cpu_header_router.setValid();
    headers.cpu_header_router.preamble = 64w0;
    headers.cpu_header_router.device = 8w0;
    headers.cpu_header_router.reason = reason;
    headers.cpu_header_router.if_index = meta.router_meta.if_index;
    standard_metadata.egress_spec = cpu_port;
  }

  action router_drop_action() {
    mark_to_drop();
  }
/**********************************************************/


/*********************  Router tables *********************/
  table ipv4_fib_lpm {
    key = {
      headers.ip.dstAddr : lpm;
    }
    actions = {
      router_send_to_cpu;
      router_set_nexthop;
    }
    default_action = router_send_to_cpu();
    size = TABLE_SIZE;
  }


  table dmac {
    key = { meta.router_meta.nextHop: exact; }
    actions = {
      router_drop_action;
      router_set_dmac;
    }
    size = TABLE_SIZE;
    default_action = router_drop_action;
  }


  table smac {
    key = { standard_metadata.egress_port: exact; }
    actions = {
      router_drop_action;
      router_set_smac;
    }
    size = MAC_TABLE_SIZE;
    default_action = router_drop_action;
  }
/**********************************************************/

  // The egress of switches to ingress of router.
  // Recirculate or resubmit won't achieve the same goal.
  // Because, the router ports are virtual
  action update_standard_metadata() {
    // egress_spec?
    standard_metadata.ingress_port = standard_metadata.egress_spec;
  }

  apply {
    if ((bit<1>) standard_metadata.ingress_port == 1w0) {  
      s1_learn_notify.apply();
      s1_smac_bd.apply();
      s1_dmac_switching.apply();
    }

    if ((bit<1>) standard_metadata.ingress_port == 1w1) {  
      s2_learn_notify.apply();
      s2_smac_bd.apply();
      s2_dmac_switching.apply();
    }

    // Need to think more for general cases
    if (standard_metadata.egress_spec == meta.composition_meta.rtr_s1_port ||
    standard_metadata.egress_spec == meta.composition_meta.rtr_s2_port) {
      update_standard_metadata();
      ipv4_fib_lpm.apply();
      dmac.apply();
      smac.apply();
    }

      update_standard_metadata();
    if (standard_metadata.ingress_port == 9w100) {
      s1_dup_learn_notify.apply();
      s1_dup_smac_bd.apply();
      s1_dup_dmac_switching.apply();
    }
    if (standard_metadata.ingress_port == 9w200) {
      s2_dup_learn_notify.apply();
      s2_dup_smac_bd.apply();
      s2_dup_dmac_switching.apply();
    }

   

  }
}

control egress(inout Parsed_headers headers, inout metadata_t meta,
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

control verifyChecksum(inout Parsed_headers p, inout metadata_t meta) {
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

control computeChecksum(inout Parsed_headers p, inout metadata_t meta) {
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
