#include <core.p4>
#if __TARGET_TOFINO__ == 2
#include <t2na.p4>
#else
#include <tna.p4>
#endif
header msa_twobytes_h {
    bit<16> data;
}

header msa_byte_h {
    bit<8> data;
}

header csa_indices_h {
    bit<16> pkt_len;
    bit<16> curr_offset;
}

struct msa_packet_struct_t {
    csa_indices_h      indices;
    msa_byte_h         msa_byte;
    msa_twobytes_h[17] msa_hdr_stack_s0;
}

struct ModularRouterv4_parser_meta_t {
    bool   eth_v;
    bit<1> packet_reject;
}

struct IPv4_parser_meta_t {
    bool   ipv4_v;
    bit<1> packet_reject;
}

struct IPv4_hdr_vop_t {
}

struct ModularRouterv4_hdr_vop_t {
}

struct empty_t {
}

struct eth_meta_t {
    bit<48> dmac;
    bit<48> smac;
    bit<16> ethType;
}

struct swtrace_inout_t {
    bit<4>  ipv4_ihl;
    bit<16> ipv4_total_len;
}

struct mplslr_inout_t {
    bit<16> next_hop;
    bit<16> eth_type;
}

struct acl_result_t {
    bit<1> hard_drop;
    bit<1> soft_drop;
}

struct l3_inout_t {
    acl_result_t acl;
    bit<16>      next_hop;
    bit<16>      eth_type;
}

struct ipv4_acl_in_t {
    bit<32> sa;
    bit<32> da;
}

struct ipv6_acl_in_t {
    bit<128> sa;
    bit<128> da;
}

struct ipv4_h {
    bit<8>  ihl_version;
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

struct ipv4_hdr_t {
    ipv4_h ipv4;
}

control IPv4_micro_parser(inout msa_packet_struct_t p, out ipv4_hdr_t hdr, out IPv4_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.ipv4_v = false;
        parser_meta.packet_reject = 1w0b0;
    }
    action i_112_start_0() {
        parser_meta.ipv4_v = true;
        hdr.ipv4.ihl_version = p.msa_hdr_stack_s0[7].data[15:8];
        hdr.ipv4.diffserv = p.msa_hdr_stack_s0[7].data[7:0];
        hdr.ipv4.totalLen = p.msa_hdr_stack_s0[8].data;
        hdr.ipv4.identification = p.msa_hdr_stack_s0[9].data;
        hdr.ipv4.flags = p.msa_hdr_stack_s0[10].data[15:13];
        hdr.ipv4.fragOffset = p.msa_hdr_stack_s0[10].data[12:0];
        hdr.ipv4.ttl = p.msa_hdr_stack_s0[11].data[15:8];
        hdr.ipv4.protocol = p.msa_hdr_stack_s0[11].data[7:0];
        hdr.ipv4.hdrChecksum = p.msa_hdr_stack_s0[12].data;
        hdr.ipv4.srcAddr = p.msa_hdr_stack_s0[13].data ++ p.msa_hdr_stack_s0[14].data;
        hdr.ipv4.dstAddr = p.msa_hdr_stack_s0[15].data ++ p.msa_hdr_stack_s0[16].data;
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset: exact;
        }
        actions = {
            i_112_start_0();
            NoAction();
        }
        const entries = {
                        16w112 : i_112_start_0();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control IPv4_micro_control(inout ipv4_hdr_t hdr, out bit<16> nexthop) {
    @name("IPv4.micro_control.process") action process(bit<16> nh) {
        hdr.ipv4.ttl = hdr.ipv4.ttl + 8w255;
        nexthop = nh;
    }
    @name("IPv4.micro_control.default_act") action default_act() {
        nexthop = 16w0;
    }
    @name("IPv4.micro_control.ipv4_lpm_tbl") table ipv4_lpm_tbl_0 {
        key = {
            hdr.ipv4.dstAddr : lpm @name("hdr.ipv4.dstAddr") ;
            hdr.ipv4.diffserv: ternary @name("hdr.ipv4.diffserv") ;
        }
        actions = {
            process();
            default_act();
        }
        default_action = default_act();
    }
    apply {
        ipv4_lpm_tbl_0.apply();
    }
}

control IPv4_micro_deparser(inout msa_packet_struct_t p, in ipv4_hdr_t h, in IPv4_parser_meta_t parser_meta) {
    action ipv4_14_34() {
        p.msa_hdr_stack_s0[11].data = h.ipv4.ttl ++ h.ipv4.protocol;
    }
    table deparser_tbl {
        key = {
            p.indices.curr_offset: exact;
            parser_meta.ipv4_v   : exact;
        }
        actions = {
            ipv4_14_34();
            NoAction();
        }
        const entries = {
                        (16w112, true) : ipv4_14_34();

        }

        const default_action = NoAction();
    }
    apply {
        deparser_tbl.apply();
    }
}

control IPv4(inout msa_packet_struct_t msa_packet_struct_t_var, out bit<16> out_param) {
    IPv4_micro_parser() IPv4_micro_parser_inst;
    IPv4_micro_control() IPv4_micro_control_inst;
    IPv4_micro_deparser() IPv4_micro_deparser_inst;
    ipv4_hdr_t ipv4_hdr_t_var;
    IPv4_parser_meta_t IPv4_parser_meta_t_var;
    apply {
        IPv4_micro_parser_inst.apply(msa_packet_struct_t_var, ipv4_hdr_t_var, IPv4_parser_meta_t_var);
        IPv4_micro_control_inst.apply(ipv4_hdr_t_var, out_param);
        IPv4_micro_deparser_inst.apply(msa_packet_struct_t_var, ipv4_hdr_t_var, IPv4_parser_meta_t_var);
    }
}

struct meta_t {
}

struct ethernet_h {
    bit<48> dmac;
    bit<48> smac;
    bit<16> ethType;
}

struct hdr_t {
    ethernet_h eth;
}

control ModularRouterv4_micro_parser(inout msa_packet_struct_t p, out hdr_t hdr, out ModularRouterv4_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.eth_v = false;
        parser_meta.packet_reject = 1w0b0;
    }
    action i_0_start_0() {
        parser_meta.eth_v = true;
        hdr.eth.dmac = p.msa_hdr_stack_s0[0].data ++ p.msa_hdr_stack_s0[1].data ++ p.msa_hdr_stack_s0[2].data;
        hdr.eth.smac = p.msa_hdr_stack_s0[3].data ++ p.msa_hdr_stack_s0[4].data ++ p.msa_hdr_stack_s0[5].data;
        hdr.eth.ethType = p.msa_hdr_stack_s0[6].data;
    }
    apply {
        micro_parser_init();
        i_0_start_0();
    }
}

struct struct_ModularRouterv4_micro_control_t {
}

control ModularRouterv4_micro_control_0(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout hdr_t hdr) {
    @name("ModularRouterv4.micro_control.ipv4_i") IPv4() ipv4_i_0;
    bit<16> nh_0;
    @name("ModularRouterv4.micro_control.forward") action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
        hdr.eth.dmac = dmac;
        hdr.eth.smac = smac;
        ig_intr_md_for_tm.ucast_egress_port = port;
    }
    @name(".NoAction") action NoAction_0() {
    }
    @name("ModularRouterv4.micro_control.forward_tbl") table forward_tbl_0 {
        key = {
            nh_0: exact @name("nh") ;
        }
        actions = {
            forward();
            @defaultonly NoAction_0();
        }
        default_action = NoAction_0();
    }
    apply {
        if (hdr.eth.ethType == 16w0x800) {
            ipv4_i_0.apply(msa_packet_struct_t_var, nh_0);
            forward_tbl_0.apply();
        }
    }
}

control ModularRouterv4_micro_control_1(in egress_intrinsic_metadata_t eg_intr_md, inout egress_intrinsic_metadata_for_deparser_t eg_intr_md_for_dprsr) {
    bit<32> tmp;
    bool tmp_0;
    apply {
        {
            tmp = (bit<32>)eg_intr_md.deq_qdepth;
            tmp_0 = tmp == 32w64;
            if (tmp_0) 
                eg_intr_md_for_dprsr.drop_ctl = 3w0x1;
        }
    }
}

control ModularRouterv4_micro_deparser(inout msa_packet_struct_t p, in hdr_t hdr, in ModularRouterv4_parser_meta_t parser_meta) {
    action eth_0_14() {
        p.msa_hdr_stack_s0[0].data = hdr.eth.dmac[47:32];
        p.msa_hdr_stack_s0[1].data = hdr.eth.dmac[31:16];
        p.msa_hdr_stack_s0[2].data = hdr.eth.dmac[15:0];
        p.msa_hdr_stack_s0[3].data = hdr.eth.smac[47:32];
        p.msa_hdr_stack_s0[4].data = hdr.eth.smac[31:16];
        p.msa_hdr_stack_s0[5].data = hdr.eth.smac[15:0];
    }
    table deparser_tbl {
        key = {
            parser_meta.eth_v: exact;
        }
        actions = {
            eth_0_14();
            NoAction();
        }
        const entries = {
                        true : eth_0_14();

        }

        const default_action = NoAction();
    }
    apply {
        deparser_tbl.apply();
    }
}

struct struct_ModularRouterv4_t {
    meta_t                                 meta_t_var;
    ModularRouterv4_parser_meta_t          ModularRouterv4_parser_meta_t_var;
    ModularRouterv4_hdr_vop_t              ModularRouterv4_hdr_vop_t_var;
    struct_ModularRouterv4_micro_control_t struct_ModularRouterv4_micro_control_t_var;
}

control ModularRouterv4_ingress_deparser(inout msa_packet_struct_t p, in hdr_t hdr, in ModularRouterv4_parser_meta_t parser_meta) {
    action eth_0_14() {
        p.msa_hdr_stack_s0[0].data = hdr.eth.dmac[47:32];
        p.msa_hdr_stack_s0[1].data = hdr.eth.dmac[31:16];
        p.msa_hdr_stack_s0[2].data = hdr.eth.dmac[15:0];
        p.msa_hdr_stack_s0[3].data = hdr.eth.smac[47:32];
        p.msa_hdr_stack_s0[4].data = hdr.eth.smac[31:16];
        p.msa_hdr_stack_s0[5].data = hdr.eth.smac[15:0];
    }
    table deparser_tbl {
        key = {
            parser_meta.eth_v: exact;
        }
        actions = {
            eth_0_14();
            NoAction();
        }
        const entries = {
                        true : eth_0_14();

        }

        const default_action = NoAction();
    }
    apply {
        deparser_tbl.apply();
    }
}

control ModularRouterv4_egress_parser(inout msa_packet_struct_t parse_p, out hdr_t parse_hdr, in ModularRouterv4_parser_meta_t parse_parser_meta) {
    action parse_eth_0_14() {
        parse_hdr.eth.dmac = parse_p.msa_hdr_stack_s0[0].data ++ parse_p.msa_hdr_stack_s0[1].data ++ parse_p.msa_hdr_stack_s0[2].data;
        parse_hdr.eth.smac = parse_p.msa_hdr_stack_s0[3].data ++ parse_p.msa_hdr_stack_s0[4].data ++ parse_p.msa_hdr_stack_s0[5].data;
        parse_hdr.eth.ethType = parse_p.msa_hdr_stack_s0[6].data;
    }
    table parse_deparser_tbl {
        key = {
            parse_parser_meta.eth_v: exact;
        }
        actions = {
            parse_eth_0_14();
            NoAction();
        }
        const entries = {
                        true : parse_eth_0_14();

        }

        const default_action = NoAction();
    }
    apply {
        parse_deparser_tbl.apply();
    }
}

control ModularRouterv4_0(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout struct_ModularRouterv4_t struct_ModularRouterv4_t_arg) {
    ModularRouterv4_micro_parser() ModularRouterv4_micro_parser_inst;
    hdr_t hdr_t_var;
    ModularRouterv4_micro_control_0() ModularRouterv4_micro_control_0_inst;
    ModularRouterv4_ingress_deparser() ModularRouterv4_ingress_deparser_inst;
    apply {
        ModularRouterv4_micro_parser_inst.apply(msa_packet_struct_t_var, hdr_t_var, struct_ModularRouterv4_t_arg.ModularRouterv4_parser_meta_t_var);
        ModularRouterv4_micro_control_0_inst.apply(msa_packet_struct_t_var, ig_intr_md_for_tm, hdr_t_var);
        ModularRouterv4_ingress_deparser_inst.apply(msa_packet_struct_t_var, hdr_t_var, struct_ModularRouterv4_t_arg.ModularRouterv4_parser_meta_t_var);
    }
}

control ModularRouterv4_1(inout msa_packet_struct_t msa_packet_struct_t_var, in egress_intrinsic_metadata_t eg_intr_md, inout egress_intrinsic_metadata_for_deparser_t eg_intr_md_for_dprsr, inout struct_ModularRouterv4_t struct_ModularRouterv4_t_arg) {
    ModularRouterv4_egress_parser() ModularRouterv4_egress_parser_inst;
    hdr_t hdr_t_var;
    ModularRouterv4_micro_control_1() ModularRouterv4_micro_control_1_inst;
    ModularRouterv4_micro_deparser() ModularRouterv4_micro_deparser_inst;
    apply {
        ModularRouterv4_egress_parser_inst.apply(msa_packet_struct_t_var, hdr_t_var, struct_ModularRouterv4_t_arg.ModularRouterv4_parser_meta_t_var);
        {
            ModularRouterv4_micro_control_1_inst.apply(eg_intr_md, eg_intr_md_for_dprsr);
            ModularRouterv4_micro_deparser_inst.apply(msa_packet_struct_t_var, hdr_t_var, struct_ModularRouterv4_t_arg.ModularRouterv4_parser_meta_t_var);
        }
    }
}

struct msa_user_metadata_t {
    empty_t                  in_param;
    empty_t                  out_param;
    empty_t                  inout_param;
    struct_ModularRouterv4_t struct_ModularRouterv4_t_arg;
}

parser msa_tofino_ig_parser(packet_in pin, out msa_packet_struct_t mpkt, out msa_user_metadata_t msa_um, out ingress_intrinsic_metadata_t ig_intr_md) {
    ParserCounter() pc0;
    state start {
        pc0.set((bit<8>)17);
        transition parse_msa_hdr_stack_s0;
    }
    state parse_msa_hdr_stack_s0 {
        pc0.decrement(8w1);
        pin.extract(mpkt.msa_hdr_stack_s0.next);
        transition select(pc0.is_zero()) {
            false: parse_msa_hdr_stack_s0;
            true: accept;
        }
    }
}

control msa_tofino_ig_control(inout msa_packet_struct_t mpkt, inout msa_user_metadata_t msa_um, in ingress_intrinsic_metadata_t ig_intr_md, in ingress_intrinsic_metadata_from_parser_t ig_intr_md_from_prsr, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm) {
    ModularRouterv4_0() ModularRouterv4_0_inst;
    apply {
        ModularRouterv4_0_inst.apply(mpkt, ig_intr_md_for_tm, msa_um.struct_ModularRouterv4_t_arg);
    }
}

control msa_tofino_ig_deparser(packet_out po, inout msa_packet_struct_t mpkt, in msa_user_metadata_t msa_um, in ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr) {
    apply {
        po.emit(mpkt.msa_hdr_stack_s0);
        po.emit(mpkt.msa_byte);
    }
}

parser msa_tofino_eg_parser(packet_in pin, out msa_packet_struct_t mpkt, out msa_user_metadata_t msa_um, out egress_intrinsic_metadata_t eg_intr_md) {
    ParserCounter() pc0;
    state start {
        pc0.set((bit<8>)17);
        transition parse_msa_hdr_stack_s0;
    }
    state parse_msa_hdr_stack_s0 {
        pc0.decrement(8w1);
        pin.extract(mpkt.msa_hdr_stack_s0.next);
        transition select(pc0.is_zero()) {
            false: parse_msa_hdr_stack_s0;
            true: accept;
        }
    }
}

control msa_tofino_eg_control(inout msa_packet_struct_t mpkt, inout msa_user_metadata_t msa_um, in egress_intrinsic_metadata_t eg_intr_md, in egress_intrinsic_metadata_from_parser_t eg_intr_md_from_prsr, inout egress_intrinsic_metadata_for_deparser_t eg_intr_md_for_dprsr, inout egress_intrinsic_metadata_for_output_port_t eg_intr_md_for_oport) {
    ModularRouterv4_1() ModularRouterv4_1_inst;
    apply {
        ModularRouterv4_1_inst.apply(mpkt, eg_intr_md, eg_intr_md_for_dprsr, msa_um.struct_ModularRouterv4_t_arg);
    }
}

control msa_tofino_eg_deparser(packet_out pkt_out, inout msa_packet_struct_t mpkt, in msa_user_metadata_t msa_um, in egress_intrinsic_metadata_for_deparser_t eg_intr_md_for_dprsr) {
    apply {
        pkt_out.emit(mpkt.msa_hdr_stack_s0);
        pkt_out.emit(mpkt.msa_byte);
    }
}

Pipeline(msa_tofino_ig_parser(), msa_tofino_ig_control(), msa_tofino_ig_deparser(), msa_tofino_eg_parser(), msa_tofino_eg_control(), msa_tofino_eg_deparser()) pipe;

Switch(pipe) main;

