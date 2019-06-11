#include <core.p4>
#include <v1model.p4>

header csa_byte_h {
    bit<8> data;
}


header csa_indices_h {
    bit<16> pkt_length;
    bit<16> stack_head;
}


struct csa_packet_struct_t {
    csa_byte_h[34] csa_packet;
    csa_byte_h[34] csa_stack;
    csa_indices_h indices;
}


typedef bit<9> PortId_t;
enum csa_packet_path_t {
    NORMAL,
    RECIRCULATE
}

struct csa_standard_metadata_t {
    csa_packet_path_t packet_path;
    PortId_t          ingress_port;
    bool              drop_flag;
}

enum csa_metadata_fields_t {
    QUEUE_DEPTH_AT_DEQUEUE
}

extern egress_spec {
    void set_egress_port(in PortId_t egress_port);
    PortId_t get_egress_port();
    bit<32> get_value(csa_metadata_fields_t field_type);
}

extern csa_packet_in {
    csa_packet_in();
    csa_packet_struct_t get_packet_struct();
}

extern csa_packet_out {
    csa_packet_out();
    void get_packet_in(csa_packet_in csa_pin);
    void set_packet_struct(in csa_packet_struct_t obj);
}

struct empty_t {
}

struct external_meta_t {
    bit<32> next_hop;
}

header L2_Ethernet_h {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

struct L2_parsed_headers_t {
    L2_Ethernet_h ethernet;
}

struct L2_my_metadata_t {
    bit<8>  if_index;
    bit<32> next_hop;
}

control Layer2_csa_parser(in csa_packet_struct_t pin, out L2_parsed_headers_t parsed_hdr, inout L2_my_metadata_t meta, inout standard_metadata_t standard_metadata) {
    bit<1> visit_csa_start = 1w0b0;
    bit<1> visit_csa_accept = 1w0b0;
    action csa_csa_parser_invalid_headers() {
        parsed_hdr.ethernet.setInvalid();
    }
    action start_0() {
        meta.if_index = (bit<8>)standard_metadata.ingress_port;
        parsed_hdr.ethernet.setValid();
        parsed_hdr.ethernet.dstAddr = pin.csa_packet[0].data ++ (pin.csa_packet[1].data ++ (pin.csa_packet[2].data ++ (pin.csa_packet[3].data ++ (pin.csa_packet[4].data ++ pin.csa_packet[5].data))));
        parsed_hdr.ethernet.srcAddr = pin.csa_packet[6].data ++ (pin.csa_packet[7].data ++ (pin.csa_packet[8].data ++ (pin.csa_packet[9].data ++ (pin.csa_packet[10].data ++ pin.csa_packet[11].data))));
        parsed_hdr.ethernet.etherType = pin.csa_packet[12].data ++ pin.csa_packet[13].data;
        visit_csa_start = 1w0b1;
    }
    action csa_accept() {
        visit_csa_accept = 1w0b1;
    }
    table csa_start_tbl {
        key = {
            visit_csa_start: exact;
        }
        actions = {
            csa_accept();
            NoAction();
        }
        const entries = {
                        1w0b1 : csa_accept();

        }

        const default_action = NoAction();
    }
    apply {
        csa_csa_parser_invalid_headers();
        start_0();
        csa_start_tbl.apply();
    }
}

control Layer2_csa_import(in external_meta_t in_meta, inout empty_t inout_meta, in L2_parsed_headers_t parsed_hdr, inout L2_my_metadata_t meta, inout standard_metadata_t standard_metadata) {
    @globalname("Layer2.csa_import.set_input_parameters") action set_input_parameters() {
        meta.next_hop = in_meta.next_hop;
    }
    apply {
        set_input_parameters();
    }
}

struct struct_Layer2_csa_pipe_t {
}

control Layer2_csa_pipe_0(inout L2_parsed_headers_t parsed_hdr, inout L2_my_metadata_t meta, inout standard_metadata_t standard_metadata, inout struct_Layer2_csa_pipe_t struct_Layer2_csa_pipe_t_arg) {
    @globalname("Layer2.csa_pipe.drop_action") action drop_action() {
        mark_to_drop(standard_metadata);
    }
    @globalname("Layer2.csa_pipe.set_dmac") action set_dmac(bit<48> dmac, bit<9> port) {
        standard_metadata.egress_spec = port;
        parsed_hdr.ethernet.dstAddr = dmac;
    }
    @globalname("Layer2.csa_pipe.dmac") table dmac_0 {
        key = {
            meta.next_hop: exact @globalname("meta.next_hop") ;
        }
        actions = {
            drop_action();
            set_dmac();
        }
        const entries = {
                        32w0xa000101 : set_dmac(0x000000000001, 9w1);
                        32w0xa000201 : set_dmac(0x000000000002, 9w2);
                        32w0xa000301 : set_dmac(0x000000000003, 9w3);
        }

        default_action = drop_action();
    }
    apply {
        dmac_0.apply();
    }
}

control Layer2_csa_pipe_1(inout L2_parsed_headers_t parsed_hdr, inout L2_my_metadata_t meta, inout standard_metadata_t standard_metadata, inout struct_Layer2_csa_pipe_t struct_Layer2_csa_pipe_t_arg) {
    @globalname("Layer2.csa_pipe.drop_action") action drop_action_4() {
        mark_to_drop(standard_metadata);
    }
    @globalname(".NoAction") action NoAction_0() {
    }
    @globalname("Layer2.csa_pipe.drop_table") table drop_table_0 {
        key = {
            standard_metadata.enq_qdepth: exact @globalname("depth_at_dequeue") ;
        }
        actions = {
            drop_action_4();
            NoAction_0();
        }
        size = 32;
        default_action = NoAction_0();
    }
    @globalname("Layer2.csa_pipe.drop_action") action drop_action_3() {
        mark_to_drop(standard_metadata);
    }
    @globalname("Layer2.csa_pipe.set_smac") action set_smac(bit<48> smac) {
        parsed_hdr.ethernet.srcAddr = smac;
    }
    @globalname("Layer2.csa_pipe.smac") table smac_0 {
        key = {
            standard_metadata.egress_port: exact @globalname("egress_port") ;
        }
        actions = {
            drop_action_3();
            set_smac();
        }
        default_action = drop_action_3();
        const entries = {
                        9w2 : set_smac(0x000000000020);
                        9w3 : set_smac(0x000000000030);
                        9w1 : set_smac(0x000000000010);

        }

    }
    table debug_after_Layer2_csa_pipe_1 {
        key = {
            parsed_hdr.ethernet.isValid() : exact;
            parsed_hdr.ethernet.srcAddr : exact;
            parsed_hdr.ethernet.dstAddr : exact;
            parsed_hdr.ethernet.etherType : exact;
        }
        actions = {
            NoAction();
        }

    }
    apply {
        {
            drop_table_0.apply();
            smac_0.apply();
            debug_after_Layer2_csa_pipe_1.apply();
        }
    }
}

control Layer2_csa_deparser(inout csa_packet_struct_t po, in L2_parsed_headers_t parsed_hdr) {
    action ethernet_valid_0_112() {

        po.csa_packet[5].data = parsed_hdr.ethernet.dstAddr[7:0];
        po.csa_packet[4].data = parsed_hdr.ethernet.dstAddr[15:8];
        po.csa_packet[3].data = parsed_hdr.ethernet.dstAddr[23:16];
        po.csa_packet[2].data = parsed_hdr.ethernet.dstAddr[31:24];
        po.csa_packet[1].data = parsed_hdr.ethernet.dstAddr[39:32];
        po.csa_packet[0].data = parsed_hdr.ethernet.dstAddr[47:40];

        po.csa_packet[11].data = parsed_hdr.ethernet.srcAddr[7:0];
        po.csa_packet[10].data = parsed_hdr.ethernet.srcAddr[15:8];
        po.csa_packet[9].data = parsed_hdr.ethernet.srcAddr[23:16];
        po.csa_packet[8].data = parsed_hdr.ethernet.srcAddr[31:24];
        po.csa_packet[7].data = parsed_hdr.ethernet.srcAddr[39:32];
        po.csa_packet[6].data = parsed_hdr.ethernet.srcAddr[47:40];

        po.csa_packet[13].data = parsed_hdr.ethernet.etherType[7:0];
        po.csa_packet[12].data = parsed_hdr.ethernet.etherType[15:8];
    }
    table csa_emit_ethernet_0_tbl {
        key = {
            parsed_hdr.ethernet.isValid(): exact;
        }
        actions = {
            ethernet_valid_0_112();
            NoAction();
        }
        const entries = {
                        true : ethernet_valid_0_112();

        }

        const default_action = NoAction();
    }
    apply {
/*
        po.csa_packet[0].setValid();
        po.csa_packet[1].setValid();
        po.csa_packet[2].setValid();
        po.csa_packet[3].setValid();
        po.csa_packet[4].setValid();
        po.csa_packet[5].setValid();
        po.csa_packet[6].setValid();
        po.csa_packet[7].setValid();
        po.csa_packet[8].setValid();
        po.csa_packet[9].setValid();
        po.csa_packet[10].setValid();
        po.csa_packet[11].setValid();
        po.csa_packet[12].setValid();
        po.csa_packet[13].setValid();


        po.csa_packet[14].data = po.csa_packet[14].data;
        po.csa_packet[15].data = po.csa_packet[15].data;
        po.csa_packet[16].data = po.csa_packet[16].data;
        po.csa_packet[17].data = po.csa_packet[17].data;
        po.csa_packet[18].data = po.csa_packet[18].data;
        po.csa_packet[19].data = po.csa_packet[19].data;
        po.csa_packet[20].data = po.csa_packet[20].data;
        po.csa_packet[21].data = po.csa_packet[21].data;
        po.csa_packet[22].data = po.csa_packet[22].data;
        po.csa_packet[23].data = po.csa_packet[23].data;
        po.csa_packet[24].data = po.csa_packet[24].data;
        po.csa_packet[25].data = po.csa_packet[25].data;
        po.csa_packet[26].data = po.csa_packet[26].data;
        po.csa_packet[27].data = po.csa_packet[27].data;
        po.csa_packet[28].data = po.csa_packet[28].data;
        po.csa_packet[29].data = po.csa_packet[29].data;
        po.csa_packet[30].data = po.csa_packet[30].data;
        po.csa_packet[31].data = po.csa_packet[31].data;
        po.csa_packet[32].data = po.csa_packet[32].data;
        po.csa_packet[33].data = po.csa_packet[33].data;
*/
        /*
         *
        po.csa_packet[14].setValid();
        po.csa_packet[15].setValid();
        po.csa_packet[16].setValid();
        po.csa_packet[17].setValid();
        po.csa_packet[18].setValid();
        po.csa_packet[19].setValid();
        po.csa_packet[20].setValid();
        po.csa_packet[21].setValid();
        po.csa_packet[22].setValid();
        po.csa_packet[23].setValid();
        po.csa_packet[24].setValid();
        po.csa_packet[25].setValid();
        po.csa_packet[26].setValid();
        po.csa_packet[27].setValid();
        po.csa_packet[28].setValid();
        po.csa_packet[29].setValid();
        po.csa_packet[30].setValid();
        po.csa_packet[31].setValid();
        po.csa_packet[32].setValid();
        po.csa_packet[33].setValid();
        */

        csa_emit_ethernet_0_tbl.apply();
    }
}

struct struct_Layer2_t {
    L2_my_metadata_t         L2_my_metadata_t_var;
    // L2_parsed_headers_t L2_parsed_headers_t_var;
    struct_Layer2_csa_pipe_t struct_Layer2_csa_pipe_t_var;
    bit<16>                  L2_parsed_headers_t_valid;
}

control Layer2_inter_dep(inout csa_packet_struct_t po, in L2_parsed_headers_t hdr, inout bit<16> vbmp) {

    Layer2_csa_deparser() Layer2_csa_deparser_inst;
    apply {

        Layer2_csa_deparser_inst.apply(po, hdr);
    }
}

control Layer2_inter_parser(in csa_packet_struct_t pin, out L2_parsed_headers_t hdr, inout L2_my_metadata_t L2_my_metadata_t_var, inout standard_metadata_t standard_metadata, in bit<16> vbmp) {

    Layer2_csa_parser() Layer2_csa_parser_inst;
    apply {
        Layer2_csa_parser_inst.apply(pin, hdr, L2_my_metadata_t_var, standard_metadata);
    }
}

control Layer2_0(inout csa_packet_struct_t csa_packet_struct, inout standard_metadata_t standard_metadata, in external_meta_t in_args, out empty_t out_args, inout empty_t inout_args, inout struct_Layer2_t struct_Layer2_t_arg) {
    Layer2_csa_parser() Layer2_csa_parser_inst;
    L2_parsed_headers_t L2_parsed_headers_t_var;
    Layer2_csa_import() Layer2_csa_import_inst;
    Layer2_csa_pipe_0() Layer2_csa_pipe_0_inst;
    Layer2_inter_dep() Layer2_inter_dep_inst;
    apply {
        Layer2_csa_parser_inst.apply(csa_packet_struct, L2_parsed_headers_t_var, struct_Layer2_t_arg.L2_my_metadata_t_var, standard_metadata);
        Layer2_csa_import_inst.apply(in_args, inout_args, L2_parsed_headers_t_var, struct_Layer2_t_arg.L2_my_metadata_t_var, standard_metadata);
        Layer2_csa_pipe_0_inst.apply(L2_parsed_headers_t_var, struct_Layer2_t_arg.L2_my_metadata_t_var, standard_metadata, struct_Layer2_t_arg.struct_Layer2_csa_pipe_t_var);
        Layer2_inter_dep_inst.apply(csa_packet_struct, L2_parsed_headers_t_var, struct_Layer2_t_arg.L2_parsed_headers_t_valid);
    }
}

control Layer2_1(inout csa_packet_struct_t csa_packet_struct, inout standard_metadata_t standard_metadata, in external_meta_t in_args, out empty_t out_args, inout empty_t inout_args, inout struct_Layer2_t struct_Layer2_t_arg) {
    Layer2_inter_parser() Layer2_inter_parser_inst;
    L2_parsed_headers_t L2_parsed_headers_t_var;
    Layer2_csa_pipe_1() Layer2_csa_pipe_1_inst;
    Layer2_csa_deparser() Layer2_csa_deparser_inst;
    apply {
        Layer2_inter_parser_inst.apply(csa_packet_struct, L2_parsed_headers_t_var, struct_Layer2_t_arg.L2_my_metadata_t_var, standard_metadata, struct_Layer2_t_arg.L2_parsed_headers_t_valid);
        {
            Layer2_csa_pipe_1_inst.apply(L2_parsed_headers_t_var, struct_Layer2_t_arg.L2_my_metadata_t_var, standard_metadata, struct_Layer2_t_arg.struct_Layer2_csa_pipe_t_var);
            Layer2_csa_deparser_inst.apply(csa_packet_struct, L2_parsed_headers_t_var);
        }
    }
}

header L3_Ethernet_h {
    bit<96> unused;
    bit<16> etherType;
}

header L3_IPv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

struct L3_parsed_headers_t {
    L3_Ethernet_h ethernet;
    L3_IPv4_h     ip;
}

struct L3_router_metadata_t {
    bit<8>  if_index;
    bit<32> next_hop;
}

control Layer3_csa_parser(in csa_packet_struct_t pin, out L3_parsed_headers_t parsed_hdr, inout L3_router_metadata_t meta, inout standard_metadata_t standard_metadata) {
    bit<1> visit_csa_start = 1w0b0;
    bit<1> visit_csa_reject = 1w0b0;
    bit<1> visit_csa_parse_ipv4 = 1w0b0;
    bit<1> visit_csa_accept = 1w0b0;
    action csa_csa_parser_invalid_headers() {
        parsed_hdr.ethernet.setInvalid();
        parsed_hdr.ip.setInvalid();
    }
    action start_0() {
        meta.if_index = (bit<8>)standard_metadata.ingress_port;
        parsed_hdr.ethernet.setValid();
        parsed_hdr.ethernet.unused = pin.csa_packet[0].data ++ (pin.csa_packet[1].data ++ (pin.csa_packet[2].data ++ (pin.csa_packet[3].data ++ (pin.csa_packet[4].data ++ (pin.csa_packet[5].data ++ (pin.csa_packet[6].data ++ (pin.csa_packet[7].data ++ (pin.csa_packet[8].data ++ (pin.csa_packet[9].data ++ (pin.csa_packet[10].data ++ pin.csa_packet[11].data))))))))));
        parsed_hdr.ethernet.etherType = pin.csa_packet[12].data ++ pin.csa_packet[13].data;
        visit_csa_start = 1w0b1;
    }
    action csa_reject() {
        visit_csa_reject = 1w0b1;
    }
    action parse_ipv4_0() {
        parsed_hdr.ip.setValid();
        parsed_hdr.ip.version = pin.csa_packet[14].data[3:0];
        parsed_hdr.ip.ihl = pin.csa_packet[14].data[7:4];
        parsed_hdr.ip.diffserv = pin.csa_packet[15].data;
        parsed_hdr.ip.totalLen = pin.csa_packet[16].data ++ pin.csa_packet[17].data;
        parsed_hdr.ip.identification = pin.csa_packet[18].data ++ pin.csa_packet[19].data;
        parsed_hdr.ip.flags = pin.csa_packet[20].data[2:0];
        parsed_hdr.ip.fragOffset = pin.csa_packet[20].data[7:3] ++ pin.csa_packet[21].data;
        parsed_hdr.ip.ttl = pin.csa_packet[22].data;
        parsed_hdr.ip.protocol = pin.csa_packet[23].data;
        parsed_hdr.ip.hdrChecksum = pin.csa_packet[24].data ++ pin.csa_packet[25].data;
        parsed_hdr.ip.srcAddr = pin.csa_packet[26].data ++ (pin.csa_packet[27].data ++ (pin.csa_packet[28].data ++ pin.csa_packet[29].data));
        parsed_hdr.ip.dstAddr = pin.csa_packet[30].data ++ (pin.csa_packet[31].data ++ (pin.csa_packet[32].data ++ pin.csa_packet[33].data));
        visit_csa_parse_ipv4 = 1w0b1;
    }
    action csa_accept() {
        visit_csa_accept = 1w0b1;
    }
    table csa_start_tbl {
        key = {
            visit_csa_start              : exact;
            parsed_hdr.ethernet.etherType: ternary;
        }
        actions = {
            parse_ipv4_0();
            csa_reject();
            NoAction();
        }
        const entries = {
                        (1w0b1, 16w0x800) : parse_ipv4_0();

                        (1w0b1, default) : csa_reject();

        }

        const default_action = NoAction();
    }
    table csa_parse_ipv4_tbl {
        key = {
            visit_csa_parse_ipv4: exact;
            visit_csa_start     : exact;
        }
        actions = {
            csa_accept();
            NoAction();
        }
        const entries = {
                        (1w0b1, 1w0b1) : csa_accept();

        }

        const default_action = NoAction();
    }
    table debug_read_packet {
        key = {
            pin.csa_packet[0].data : exact;
            pin.csa_packet[1].data : exact;
            pin.csa_packet[2].data : exact;
            pin.csa_packet[3].data : exact;
            pin.csa_packet[4].data : exact;
            pin.csa_packet[5].data : exact;
            pin.csa_packet[6].data : exact;
            pin.csa_packet[7].data : exact;
            pin.csa_packet[8].data : exact;
            pin.csa_packet[9].data : exact;
            pin.csa_packet[10].data : exact;
            pin.csa_packet[11].data : exact;
            pin.csa_packet[12].data : exact;
            pin.csa_packet[13].data : exact;
            meta.if_index : exact;
            parsed_hdr.ethernet.unused : exact;
            parsed_hdr.ethernet.etherType : exact;
            pin.csa_packet[12].isValid(): exact;
            pin.csa_packet[13].isValid(): exact;
            parsed_hdr.ethernet.isValid(): exact;
            pin.csa_packet[32].isValid(): exact;
            pin.csa_packet[33].isValid(): exact;
        }
        actions = {
        }
    }
    apply {
        csa_csa_parser_invalid_headers();
        start_0();
        debug_read_packet.apply();
        csa_start_tbl.apply();
        csa_parse_ipv4_tbl.apply();
    }
}

control Layer3_csa_pipe(inout L3_parsed_headers_t parsed_hdr, inout L3_router_metadata_t meta, inout standard_metadata_t standard_metadata) {
    @globalname("Layer3.csa_pipe.set_nexthop") action set_nexthop(bit<32> nexthop_ipv4_addr, bit<9> port) {
        meta.next_hop = nexthop_ipv4_addr;
        standard_metadata.egress_spec = port;
    }
    @globalname("Layer3.csa_pipe.send_to_cpu") action send_to_cpu() {
    }
    @globalname("Layer3.csa_pipe.ipv4_fib_lpm") table ipv4_fib_lpm_0 {
        key = {
            parsed_hdr.ip.dstAddr: lpm @globalname("parsed_hdr.ip.dstAddr") ;
        }
        actions = {
            send_to_cpu();
            set_nexthop();
        }
        const entries = {
                        32w0xa000200 &&& 32w0xffffff00 : set_nexthop(32w0xa000201, 9w2);
                        32w0xa000300 &&& 32w0xffffff00 : set_nexthop(32w0xa000301, 9w3);
                        32w0xa000100 &&& 32w0xffffff00 : set_nexthop(32w0xa000101, 9w1);
        }

        default_action = send_to_cpu();
    }
    table debug_ingress_port {
        key = {standard_metadata.ingress_port : exact;}
        actions = {NoAction;}
    }
    apply {
        debug_ingress_port.apply();
        ipv4_fib_lpm_0.apply();
    }
}

control Layer3_csa_export(out external_meta_t out_meta, inout empty_t inout_meta, in L3_parsed_headers_t parsed_hdr, in L3_router_metadata_t meta, in standard_metadata_t standard_metadata) {
    @globalname("Layer3.csa_export.set_return_parameters") action set_return_parameters() {
        out_meta.next_hop = meta.next_hop;
    }
    apply {
        set_return_parameters();
    }
}

control Layer3_csa_deparser(inout csa_packet_struct_t po, in L3_parsed_headers_t parsed_hdr) {
    action ip_valid_0_160() {
        po.csa_packet[0].data[3:0] = parsed_hdr.ip.version[3:0];
        po.csa_packet[0].data[7:4] = parsed_hdr.ip.ihl[3:0];
        po.csa_packet[1].data = parsed_hdr.ip.diffserv[7:0];
        po.csa_packet[2].data = parsed_hdr.ip.totalLen[15:8];
        po.csa_packet[3].data = parsed_hdr.ip.totalLen[7:0];
        po.csa_packet[4].data = parsed_hdr.ip.identification[15:8];
        po.csa_packet[5].data = parsed_hdr.ip.identification[7:0];

        po.csa_packet[6].data[2:0] = parsed_hdr.ip.flags[2:0];
        po.csa_packet[6].data[7:3] = parsed_hdr.ip.fragOffset[4:0];
        po.csa_packet[7].data = parsed_hdr.ip.fragOffset[12:5];
        po.csa_packet[8].data = parsed_hdr.ip.ttl[7:0];
        po.csa_packet[9].data = parsed_hdr.ip.protocol[7:0];
        po.csa_packet[10].data = parsed_hdr.ip.hdrChecksum[15:8];
        po.csa_packet[11].data = parsed_hdr.ip.hdrChecksum[7:0];
        po.csa_packet[12].data = parsed_hdr.ip.srcAddr[31:24];
        po.csa_packet[13].data = parsed_hdr.ip.srcAddr[23:16];
        po.csa_packet[14].data = parsed_hdr.ip.srcAddr[15:8];
        po.csa_packet[15].data = parsed_hdr.ip.srcAddr[7:0];
        po.csa_packet[16].data = parsed_hdr.ip.dstAddr[31:24];
        po.csa_packet[17].data = parsed_hdr.ip.dstAddr[23:16];
        po.csa_packet[18].data = parsed_hdr.ip.dstAddr[15:8];
        po.csa_packet[19].data = parsed_hdr.ip.dstAddr[7:0];
    }
    action ip_valid_112_272() {
        po.csa_packet[14].data[3:0] = parsed_hdr.ip.version[3:0];
        po.csa_packet[14].data[7:4] = parsed_hdr.ip.ihl[3:0];
        po.csa_packet[15].data = parsed_hdr.ip.diffserv[7:0];
        po.csa_packet[16].data = parsed_hdr.ip.totalLen[15:8];
        po.csa_packet[17].data = parsed_hdr.ip.totalLen[7:0];
        po.csa_packet[18].data = parsed_hdr.ip.identification[15:8];
        po.csa_packet[19].data = parsed_hdr.ip.identification[7:0];
        po.csa_packet[20].data[2:0] = parsed_hdr.ip.flags[2:0];
        po.csa_packet[20].data[7:3] = parsed_hdr.ip.fragOffset[12:8];
        po.csa_packet[21].data = parsed_hdr.ip.fragOffset[7:0];
        po.csa_packet[22].data = parsed_hdr.ip.ttl[7:0];
        po.csa_packet[23].data = parsed_hdr.ip.protocol[7:0];
        po.csa_packet[24].data = parsed_hdr.ip.hdrChecksum[15:8];
        po.csa_packet[25].data = parsed_hdr.ip.hdrChecksum[7:0];
        po.csa_packet[26].data = parsed_hdr.ip.srcAddr[31:24];
        po.csa_packet[27].data = parsed_hdr.ip.srcAddr[23:16];
        po.csa_packet[28].data = parsed_hdr.ip.srcAddr[15:8];
        po.csa_packet[29].data = parsed_hdr.ip.srcAddr[7:0];
        po.csa_packet[30].data = parsed_hdr.ip.dstAddr[31:24];
        po.csa_packet[31].data = parsed_hdr.ip.dstAddr[23:16];
        po.csa_packet[32].data = parsed_hdr.ip.dstAddr[15:8];
        po.csa_packet[33].data = parsed_hdr.ip.dstAddr[7:0];
    }
    action ethernet_valid_0_112() {

        po.csa_packet[11].data = parsed_hdr.ethernet.unused[7:0];
        po.csa_packet[10].data = parsed_hdr.ethernet.unused[15:8];
        po.csa_packet[9].data = parsed_hdr.ethernet.unused[23:16];
        po.csa_packet[8].data = parsed_hdr.ethernet.unused[31:24];
        po.csa_packet[7].data = parsed_hdr.ethernet.unused[39:32];
        po.csa_packet[6].data = parsed_hdr.ethernet.unused[47:40];

        po.csa_packet[5].data = parsed_hdr.ethernet.unused[55:48];
        po.csa_packet[4].data = parsed_hdr.ethernet.unused[63:56];
        po.csa_packet[3].data = parsed_hdr.ethernet.unused[71:64];
        po.csa_packet[2].data = parsed_hdr.ethernet.unused[79:72];
        po.csa_packet[1].data = parsed_hdr.ethernet.unused[87:80];
        po.csa_packet[0].data = parsed_hdr.ethernet.unused[95:88];

        po.csa_packet[12].data = parsed_hdr.ethernet.etherType[15:8];
        po.csa_packet[13].data = parsed_hdr.ethernet.etherType[7:0];
        

    }
    table csa_emit_ethernet_0_tbl {
        key = {
            parsed_hdr.ethernet.isValid(): exact;
        }
        actions = {
            ethernet_valid_0_112();
            NoAction();
        }
        const entries = {
                        true : ethernet_valid_0_112();

        }

        const default_action = NoAction();
    }
    table csa_emit_ip_0_tbl {
        key = {
            parsed_hdr.ethernet.isValid(): exact;
            parsed_hdr.ip.isValid()      : exact;
        }
        actions = {
            ip_valid_0_160();
            ip_valid_112_272();
            NoAction();
        }
        const entries = {
                        (false, true) : ip_valid_0_160();

                        (true, true) : ip_valid_112_272();

        }

        const default_action = NoAction();
    }
    apply {
        csa_emit_ethernet_0_tbl.apply();
        csa_emit_ip_0_tbl.apply();
    }
}

control Layer3(inout csa_packet_struct_t csa_packet_struct, inout standard_metadata_t standard_metadata, in empty_t in_args, out external_meta_t out_args, inout empty_t inout_args) {
    Layer3_csa_parser() Layer3_csa_parser_inst;
    Layer3_csa_pipe() Layer3_csa_pipe_inst;
    Layer3_csa_deparser() Layer3_csa_deparser_inst;
    Layer3_csa_export() Layer3_csa_export_inst;
    L3_parsed_headers_t L3_parsed_headers_t_var;
    L3_router_metadata_t L3_router_metadata_t_var;

    table debug_before_Layer3_csa_parser {
        key = {
            csa_packet_struct.csa_packet[0].isValid() : exact;
            csa_packet_struct.csa_packet[10].isValid() : exact;
            csa_packet_struct.csa_packet[33].isValid() : exact;

        }
        actions = {NoAction;}
    }
    table debug_before_Layer3_csa_pipe {
        key = {
            csa_packet_struct.csa_packet[0].isValid() : exact;
            csa_packet_struct.csa_packet[10].isValid() : exact;
            csa_packet_struct.csa_packet[33].isValid() : exact;

        }
        actions = {NoAction;}
    }
    table debug_before_Layer3_csa_deparser {
        key = {
            csa_packet_struct.csa_packet[0].isValid() : exact;
            csa_packet_struct.csa_packet[10].isValid() : exact;
            csa_packet_struct.csa_packet[33].isValid() : exact;

        }
        actions = {NoAction;}
    }
    table debug_after_Layer3_csa_deparser {
        key = {
            csa_packet_struct.csa_packet[0].isValid() : exact;
            csa_packet_struct.csa_packet[10].isValid() : exact;
            csa_packet_struct.csa_packet[33].isValid() : exact;

        }
        actions = {NoAction;}
    }

    apply {
        debug_before_Layer3_csa_parser.apply();
        Layer3_csa_parser_inst.apply(csa_packet_struct, L3_parsed_headers_t_var, L3_router_metadata_t_var, standard_metadata);
        debug_before_Layer3_csa_pipe.apply();
        Layer3_csa_pipe_inst.apply(L3_parsed_headers_t_var, L3_router_metadata_t_var, standard_metadata);
        Layer3_csa_export_inst.apply(out_args, inout_args, L3_parsed_headers_t_var, L3_router_metadata_t_var, standard_metadata);
        debug_before_Layer3_csa_deparser.apply();
        Layer3_csa_deparser_inst.apply(csa_packet_struct, L3_parsed_headers_t_var);
        debug_after_Layer3_csa_deparser.apply();
    }
}

struct L2L3_user_metadata_t {
}

struct L2L3_psm_t {
}

struct struct_L2L3_csa_pipe_t {
    empty_t         e_0;
    external_meta_t arg_0;
    empty_t         eio_0;
    struct_Layer2_t struct_Layer2_t_var;
}

control L2L3_csa_pipe_0(inout csa_packet_struct_t csa_packet_struct, inout L2L3_user_metadata_t meta, inout standard_metadata_t sm, inout struct_L2L3_csa_pipe_t struct_L2L3_csa_pipe_t_arg) {
    @globalname("L2L3.csa_pipe.l3") Layer3() l3_0;
    Layer2_0() Layer2_0_inst;

     table debug_read_after_l3 {
        key = {
            csa_packet_struct.csa_packet[0].data : exact;
            csa_packet_struct.csa_packet[1].data : exact;
            csa_packet_struct.csa_packet[2].data : exact;
            csa_packet_struct.csa_packet[3].data : exact;
            csa_packet_struct.csa_packet[4].data : exact;
            csa_packet_struct.csa_packet[5].data : exact;
            csa_packet_struct.csa_packet[14].data : exact;
            csa_packet_struct.csa_packet[15].data : exact;
            csa_packet_struct.csa_packet[26].data : exact;
            csa_packet_struct.csa_packet[27].data : exact;
            csa_packet_struct.csa_packet[28].data : exact;
            csa_packet_struct.csa_packet[29].data : exact;
            csa_packet_struct.csa_packet[30].data : exact;
            csa_packet_struct.csa_packet[31].data : exact;
            csa_packet_struct.csa_packet[32].data : exact;
            csa_packet_struct.csa_packet[33].data : exact;
            csa_packet_struct.csa_packet[0].isValid() : exact;
            csa_packet_struct.csa_packet[10].isValid() : exact;
            csa_packet_struct.csa_packet[13].isValid() : exact;
            csa_packet_struct.csa_packet[14].isValid() : exact;
            csa_packet_struct.csa_packet[24].isValid() : exact;
            csa_packet_struct.csa_packet[33].isValid() : exact;
        }
        actions = {
            NoAction();
        }
    }

    apply {
        l3_0.apply(csa_packet_struct, sm, struct_L2L3_csa_pipe_t_arg.e_0, struct_L2L3_csa_pipe_t_arg.arg_0, struct_L2L3_csa_pipe_t_arg.eio_0);
        debug_read_after_l3.apply();
        Layer2_0_inst.apply(csa_packet_struct, sm, struct_L2L3_csa_pipe_t_arg.arg_0, struct_L2L3_csa_pipe_t_arg.e_0, struct_L2L3_csa_pipe_t_arg.eio_0, struct_L2L3_csa_pipe_t_arg.struct_Layer2_t_var);
    }
}

control L2L3_csa_pipe_1(inout csa_packet_struct_t csa_packet_struct, inout L2L3_user_metadata_t meta, inout standard_metadata_t sm, inout struct_L2L3_csa_pipe_t struct_L2L3_csa_pipe_t_arg) {
    Layer2_1() Layer2_1_inst;
    apply {
        {
            Layer2_1_inst.apply(csa_packet_struct, sm, struct_L2L3_csa_pipe_t_arg.arg_0, struct_L2L3_csa_pipe_t_arg.e_0, struct_L2L3_csa_pipe_t_arg.eio_0, struct_L2L3_csa_pipe_t_arg.struct_Layer2_t_var);
        }
    }
}

struct struct_L2L3_t {
    L2L3_user_metadata_t   L2L3_user_metadata_t_var;
    struct_L2L3_csa_pipe_t struct_L2L3_csa_pipe_t_var;
}

control L2L3_0(inout csa_packet_struct_t csa_packet_struct, inout standard_metadata_t standard_metadata, in empty_t in_args, out empty_t out_args, inout empty_t inout_args, inout struct_L2L3_t struct_L2L3_t_arg) {
    L2L3_csa_pipe_0() L2L3_csa_pipe_0_inst;

    apply {
        L2L3_csa_pipe_0_inst.apply(csa_packet_struct, struct_L2L3_t_arg.L2L3_user_metadata_t_var, standard_metadata, struct_L2L3_t_arg.struct_L2L3_csa_pipe_t_var);
    }

}

control L2L3_1(inout csa_packet_struct_t po, inout standard_metadata_t standard_metadata, in empty_t in_args, out empty_t out_args, inout empty_t inout_args, inout struct_L2L3_t struct_L2L3_t_arg) {
    L2L3_csa_pipe_1() L2L3_csa_pipe_1_inst;
    apply {
        {
            
            L2L3_csa_pipe_1_inst.apply(po, struct_L2L3_t_arg.L2L3_user_metadata_t_var, standard_metadata, struct_L2L3_t_arg.struct_L2L3_csa_pipe_t_var);
        }
    }
}

struct csa_user_metadata_t {
    empty_t       in_args;
    empty_t       out_args;
    empty_t       inout_args;
    struct_L2L3_t struct_L2L3_t_arg;
}

parser csa_v1model_parser(packet_in pin, out csa_packet_struct_t pkt, inout csa_user_metadata_t csa_um, inout standard_metadata_t csa_sm) {
    state start {
        pkt.indices.pkt_length = 16w1;
        verify(csa_sm.packet_length >= 32w14, error.PacketTooShort);
        transition parse_byte;
    }
    state parse_byte {
        pin.extract(pkt.csa_packet.next);
        pkt.indices.pkt_length = pkt.indices.pkt_length + 16w1;
        transition select(pkt.indices.pkt_length <= (bit<16>)csa_sm.packet_length &&
        pkt.indices.pkt_length <= 16w34) {
            false: accept;
            true: parse_byte;
        }
    }
}

control csa_v1model_deparser(packet_out po, in csa_packet_struct_t pkt) {
    apply {
        po.emit(pkt.csa_packet);
    }
}

control csa_ingress(inout csa_packet_struct_t pkt, inout csa_user_metadata_t csa_um, inout standard_metadata_t csa_sm) {
    L2L3_0() L2L3_0_inst;
    table debug_read_after_ingress {
        key = {
            pkt.csa_packet[0].data : exact;
            pkt.csa_packet[1].data : exact;
            pkt.csa_packet[2].data : exact;
            pkt.csa_packet[3].data : exact;
            pkt.csa_packet[4].data : exact;
            pkt.csa_packet[5].data : exact;
            pkt.csa_packet[14].data : exact;
            pkt.csa_packet[15].data : exact;
            pkt.csa_packet[26].data : exact;
            pkt.csa_packet[27].data : exact;
            pkt.csa_packet[28].data : exact;
            pkt.csa_packet[29].data : exact;
            pkt.csa_packet[30].data : exact;
            pkt.csa_packet[31].data : exact;
            pkt.csa_packet[32].data : exact;
            pkt.csa_packet[33].data : exact;
            pkt.csa_packet[0].isValid() : exact;
            pkt.csa_packet[10].isValid() : exact;
            pkt.csa_packet[13].isValid() : exact;
            pkt.csa_packet[14].isValid() : exact;
            pkt.csa_packet[24].isValid() : exact;
            pkt.csa_packet[33].isValid() : exact;
        }
        actions = {
        }
    }

    apply {
        L2L3_0_inst.apply(pkt, csa_sm, csa_um.in_args, csa_um.out_args, csa_um.inout_args, csa_um.struct_L2L3_t_arg);
        debug_read_after_ingress.apply();
    }
}

control csa_egress(inout csa_packet_struct_t pkt, inout csa_user_metadata_t csa_um, inout standard_metadata_t csa_sm) {
    L2L3_1() L2L3_1_inst;
    apply {

        L2L3_1_inst.apply(pkt, csa_sm, csa_um.in_args, csa_um.out_args, csa_um.inout_args, csa_um.struct_L2L3_t_arg);
    }
}

control csa_verify_checksum(inout csa_packet_struct_t pkt, inout csa_user_metadata_t csa_um) {
    apply {
    }
}

control csa_compute_checksum(inout csa_packet_struct_t pkt, inout csa_user_metadata_t csa_um) {
    apply {
    }
}

V1Switch(csa_v1model_parser(), csa_verify_checksum(), csa_ingress(), csa_egress(), csa_compute_checksum(), csa_v1model_deparser()) main;

