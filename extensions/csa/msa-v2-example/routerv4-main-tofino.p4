header msa_twobytes_h {
    bit<16> data;
}

#include <core.p4>
#include <tofino.p4>
#include <tna.p4>

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
    msa_twobytes_h[15] msa_hdr_stack_s0;
}

struct ModularRouterv4_parser_meta_t {
    bool   eth_v;
    bit<1> packet_reject;
}

struct L3v4_parser_meta_t {
    bool   ipv4_v;
    bit<1> packet_reject;
}

struct L3v4_hdr_vop_t {
}

struct ModularRouterv4_hdr_vop_t {
}

struct empty_t {
}

struct swtrace_inout_t {
    bit<4>  ipv4_ihl;
    bit<16> ipv4_total_len;
}

struct l3_meta_t {
}

struct ipv4_h {
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
    bit<16> srcAddr;
    bit<16> dstAddr;
}

struct l3v4_hdr_t {
    ipv4_h ipv4;
}

control L3v4_micro_parser(inout msa_packet_struct_t p, out l3v4_hdr_t hdr, inout bit<16> ethType, out L3v4_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.ipv4_v = false;
        parser_meta.packet_reject = 1w0b0;
    }
    action micro_parser_reject() {
        parser_meta.packet_reject = 1w0b1;
    }
    action i_112_parse_ipv4_0() {
        parser_meta.ipv4_v = true;
        hdr.ipv4.version = p.msa_hdr_stack_s0[7].data[15:12];
        hdr.ipv4.ihl = p.msa_hdr_stack_s0[7].data[11:8];
        hdr.ipv4.diffserv = p.msa_hdr_stack_s0[7].data[7:0];
        hdr.ipv4.totalLen = p.msa_hdr_stack_s0[8].data[15:0];
        hdr.ipv4.identification = p.msa_hdr_stack_s0[9].data[15:0];
        hdr.ipv4.flags = p.msa_hdr_stack_s0[10].data[15:13];
        hdr.ipv4.fragOffset = p.msa_hdr_stack_s0[10].data[12:0];
        hdr.ipv4.ttl = p.msa_hdr_stack_s0[11].data[15:8];
        hdr.ipv4.protocol = p.msa_hdr_stack_s0[11].data[7:0];
        hdr.ipv4.hdrChecksum = p.msa_hdr_stack_s0[12].data[15:0];
        hdr.ipv4.srcAddr = p.msa_hdr_stack_s0[13].data[15:0];
        hdr.ipv4.dstAddr = p.msa_hdr_stack_s0[14].data[15:0];
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset: exact;
            ethType              : ternary;
        }
        actions = {
            i_112_parse_ipv4_0();
            micro_parser_reject();
            NoAction();
        }
        const entries = {
                        (16w112, 16w0x800) : i_112_parse_ipv4_0();

                        (16w112, default) : micro_parser_reject();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control L3v4_micro_control(inout l3v4_hdr_t hdr, out bit<16> nexthop) {
    @name("L3v4.micro_control.process") action process(bit<16> nh) {
        hdr.ipv4.ttl = hdr.ipv4.ttl + 8w255;
        nexthop = nh;
    }
    @name("L3v4.micro_control.default_act") action default_act() {
        nexthop = 16w0;
    }
    @name("L3v4.micro_control.ipv4_lpm_tbl") table ipv4_lpm_tbl_0 {
        key = {
            hdr.ipv4.dstAddr: lpm @name("hdr.ipv4.dstAddr") ;
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

control L3v4_micro_deparser(inout msa_packet_struct_t p, in l3v4_hdr_t h, in L3v4_parser_meta_t parser_meta) {
    action ipv4_14_30() {
        p.msa_hdr_stack_s0[7].data[15:0] = h.ipv4.version[3:0] ++ h.ipv4.ihl[3:0] ++ h.ipv4.diffserv[7:0];
        p.msa_hdr_stack_s0[8].data[15:0] = h.ipv4.totalLen[15:0];
        p.msa_hdr_stack_s0[9].data[15:0] = h.ipv4.identification[15:0];
        p.msa_hdr_stack_s0[10].data[15:0] = h.ipv4.flags[2:0] ++ h.ipv4.fragOffset[12:0];
        p.msa_hdr_stack_s0[11].data[15:0] = h.ipv4.ttl[7:0] ++ h.ipv4.protocol[7:0];
        p.msa_hdr_stack_s0[12].data[15:0] = h.ipv4.hdrChecksum[15:0];
        p.msa_hdr_stack_s0[13].data[15:0] = h.ipv4.srcAddr[15:0];
        p.msa_hdr_stack_s0[14].data[15:0] = h.ipv4.dstAddr[15:0];
    }
    table deparser_tbl {
        key = {
            p.indices.curr_offset: exact;
            parser_meta.ipv4_v   : exact;
        }
        actions = {
            ipv4_14_30();
            NoAction();
        }
        const entries = {
                        (16w112, true) : ipv4_14_30();

        }

        const default_action = NoAction();
    }
    apply {
        deparser_tbl.apply();
    }
}

control L3v4(inout msa_packet_struct_t msa_packet_struct_t_var, out bit<16> out_param, inout bit<16> inout_param) {
    L3v4_micro_parser() L3v4_micro_parser_inst;
    L3v4_micro_control() L3v4_micro_control_inst;
    L3v4_micro_deparser() L3v4_micro_deparser_inst;
    l3v4_hdr_t l3v4_hdr_t_var;
    L3v4_parser_meta_t L3v4_parser_meta_t_var;
    apply {
        L3v4_micro_parser_inst.apply(msa_packet_struct_t_var, l3v4_hdr_t_var, inout_param, L3v4_parser_meta_t_var);
        L3v4_micro_control_inst.apply(l3v4_hdr_t_var, out_param);
        L3v4_micro_deparser_inst.apply(msa_packet_struct_t_var, l3v4_hdr_t_var, L3v4_parser_meta_t_var);
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
        hdr.eth.dmac = p.msa_hdr_stack_s0[0].data[15:0] ++ p.msa_hdr_stack_s0[1].data[15:0] ++ p.msa_hdr_stack_s0[2].data[15:0];
        hdr.eth.smac = p.msa_hdr_stack_s0[3].data[15:0] ++ p.msa_hdr_stack_s0[4].data[15:0] ++ p.msa_hdr_stack_s0[5].data[15:0];
        hdr.eth.ethType = p.msa_hdr_stack_s0[6].data[15:0];
    }
    apply {
        micro_parser_init();
        i_0_start_0();
    }
}

struct struct_ModularRouterv4_micro_control_t {
}

control ModularRouterv4_micro_control_0(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout hdr_t hdr) {
    @name("ModularRouterv4.micro_control.l3_i") L3v4() l3_i_0;
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
            nh_0: lpm @name("nh") ;
        }
        actions = {
            forward();
            @defaultonly NoAction_0();
        }
        default_action = NoAction_0();
    }
    apply {
        l3_i_0.apply(msa_packet_struct_t_var, nh_0, hdr.eth.ethType);
        forward_tbl_0.apply();
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
        p.msa_hdr_stack_s0[0].data[15:0] = hdr.eth.dmac[47:32];
        p.msa_hdr_stack_s0[1].data[15:0] = hdr.eth.dmac[31:16];
        p.msa_hdr_stack_s0[2].data[15:0] = hdr.eth.dmac[15:0];
        p.msa_hdr_stack_s0[3].data[15:0] = hdr.eth.smac[47:32];
        p.msa_hdr_stack_s0[4].data[15:0] = hdr.eth.smac[31:16];
        p.msa_hdr_stack_s0[5].data[15:0] = hdr.eth.smac[15:0];
        p.msa_hdr_stack_s0[6].data[15:0] = hdr.eth.ethType[15:0];
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
        p.msa_hdr_stack_s0[0].data[15:0] = hdr.eth.dmac[47:32];
        p.msa_hdr_stack_s0[1].data[15:0] = hdr.eth.dmac[31:16];
        p.msa_hdr_stack_s0[2].data[15:0] = hdr.eth.dmac[15:0];
        p.msa_hdr_stack_s0[3].data[15:0] = hdr.eth.smac[47:32];
        p.msa_hdr_stack_s0[4].data[15:0] = hdr.eth.smac[31:16];
        p.msa_hdr_stack_s0[5].data[15:0] = hdr.eth.smac[15:0];
        p.msa_hdr_stack_s0[6].data[15:0] = hdr.eth.ethType[15:0];
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
        parse_hdr.eth.dmac[47:0] = parse_p.msa_hdr_stack_s0[0].data[15:0] ++ parse_p.msa_hdr_stack_s0[1].data[15:0] ++ parse_p.msa_hdr_stack_s0[2].data[15:0];
        parse_hdr.eth.smac[47:0] = parse_p.msa_hdr_stack_s0[3].data[15:0] ++ parse_p.msa_hdr_stack_s0[4].data[15:0] ++ parse_p.msa_hdr_stack_s0[5].data[15:0];
        parse_hdr.eth.ethType[15:0] = parse_p.msa_hdr_stack_s0[6].data[15:0];
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
        pc0.set((bit<8>)15);
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
        pc0.set((bit<8>)15);
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

