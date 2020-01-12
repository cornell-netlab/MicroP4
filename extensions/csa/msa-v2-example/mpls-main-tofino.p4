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
    msa_twobytes_h[11] msa_hdr_stack_s0;
}

struct ModularMpls_parser_meta_t {
    bool   eth_v;
    bit<1> packet_reject;
}

struct Mpls_parser_meta_t {
    bool   mpls_v;
    bit<1> packet_reject;
}

struct Mpls_hdr_vop_t {
    bool mpls_sv;
    bool mpls_siv;
}

struct ModularMpls_hdr_vop_t {
}

struct empty_t {
}

struct swtrace_inout_t {
    bit<4>  ipv4_ihl;
    bit<16> ipv4_total_len;
}

struct mpls_meta_t {
    bit<16> ethType;
}

struct mpls_h {
    bit<20> label;
    bit<3>  exp;
    bit<1>  s;
    bit<8>  ttl;
}

struct mpls_hdr_t {
    mpls_h mpls;
}

control Mpls_micro_parser(inout msa_packet_struct_t p, out mpls_hdr_t hdr, inout mpls_meta_t meta, inout bit<16> ethType, out Mpls_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.mpls_v = false;
        parser_meta.packet_reject = 1w0b0;
    }
    action micro_parser_reject() {
        parser_meta.packet_reject = 1w0b1;
    }
    action i_112_parse_mpls_0() {
        parser_meta.mpls_v = true;
        hdr.mpls.label = p.msa_hdr_stack_s0[7].data[15:0] ++ p.msa_hdr_stack_s0[8].data[15:12];
        hdr.mpls.exp = p.msa_hdr_stack_s0[8].data[12:10];
        hdr.mpls.s = p.msa_hdr_stack_s0[8].data[8:8];
        hdr.mpls.ttl = p.msa_hdr_stack_s0[8].data[7:0];
        meta.ethType = ethType;
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset: exact;
            ethType              : ternary;
        }
        actions = {
            i_112_parse_mpls_0();
            micro_parser_reject();
            NoAction();
        }
        const entries = {
                        (16w112, 16w0x8847) : i_112_parse_mpls_0();

                        (16w112, default) : micro_parser_reject();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control Mpls_micro_control(inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout mpls_hdr_t hdr, inout mpls_meta_t m, out Mpls_hdr_vop_t hdr_vop) {
    @name(".NoAction") action NoAction_0() {
    }
    @name("Mpls.micro_control.drop_action") action drop_action() {
        ig_intr_md_for_tm.ucast_egress_port = 9w0x0;
    }
    @name("Mpls.micro_control.encap") action encap() {
        m.ethType = 16w0x8847;
        hdr_vop.mpls_sv = true;
        hdr_vop.mpls_siv = false;
        hdr.mpls.label = 20w0x4000;
        hdr.mpls.exp = 3w0x1;
        hdr.mpls.s = 1w0x1;
        hdr.mpls.ttl = 8w32;
    }
    @name("Mpls.micro_control.decap") action decap() {
        m.ethType = 16w0x800;
        hdr_vop.mpls_sv = false;
        hdr_vop.mpls_siv = true;
    }
    @name("Mpls.micro_control.replace") action replace() {
        hdr.mpls.label = 20w0x4000;
        hdr.mpls.ttl = hdr.mpls.ttl + 8w255;
    }
    @name("Mpls.micro_control.mpls_tbl") table mpls_tbl_0 {
        key = {
            hdr.mpls.ttl  : exact @name("hdr.mpls.ttl") ;
            m.ethType     : exact @name("m.ethType") ;
            hdr.mpls.label: exact @name("hdr.mpls.label") ;
            hdr.mpls.s    : exact @name("hdr.mpls.s") ;
        }
        actions = {
            drop_action();
            encap();
            decap();
            replace();
            @defaultonly NoAction_0();
        }
        const entries = {
                        (8w0, default, default, default) : drop_action();

                        (default, 16w0x800, default, default) : encap();

                        (default, 16w0x8477, 20w0x4000, 1w1) : decap();

                        (default, 16w0x8477, 20w0x4001, 1w1) : replace();

        }

        default_action = NoAction_0();
    }
    apply {
        mpls_tbl_0.apply();
    }
}

control Mpls_micro_deparser(inout msa_packet_struct_t p, in mpls_hdr_t hdr, in Mpls_parser_meta_t parser_meta, in Mpls_hdr_vop_t hdr_vop) {
    action mpls_14_18() {
        p.msa_hdr_stack_s0[7].data[15:0] = hdr.mpls.label[19:4];
        p.msa_hdr_stack_s0[8].data[15:0] = hdr.mpls.label[3:0] ++ hdr.mpls.exp ++ hdr.mpls.s[0:0] ++ hdr.mpls.ttl[7:0];
    }
    action move_14_4_4() {
        p.msa_hdr_stack_s0[10].data[15:0] = p.msa_hdr_stack_s0[8].data[15:0];
        p.msa_hdr_stack_s0[9].data[15:0] = p.msa_hdr_stack_s0[7].data[15:0];
    }
    action mpls_14_18_MO_Emit_4() {
        move_14_4_4();
        mpls_14_18();
    }
    action mpls_14_18_MO_Emit_0() {
        mpls_14_18();
    }
    action MO_Emit_0() {
    }
    action move_18_-4_4() {
        p.msa_hdr_stack_s0[7].data[15:0] = p.msa_hdr_stack_s0[9].data[15:0];
        p.msa_hdr_stack_s0[8].data[15:0] = p.msa_hdr_stack_s0[10].data[15:0];
    }
    action MO_Emit_-4() {
        move_18_-4_4();
    }
    table deparser_tbl {
        key = {
            p.indices.curr_offset: exact;
            parser_meta.mpls_v   : exact;
            hdr_vop.mpls_sv      : exact;
            hdr_vop.mpls_siv     : exact;
        }
        actions = {
            mpls_14_18();
            move_14_4_4();
            mpls_14_18_MO_Emit_4();
            mpls_14_18_MO_Emit_0();
            MO_Emit_0();
            move_18_-4_4();
            MO_Emit_-4();
            NoAction();
        }
        const entries = {
                        (16w112, false, true, false) : mpls_14_18_MO_Emit_4();

                        (16w112, true, true, false) : mpls_14_18_MO_Emit_0();

                        (16w112, false, false, true) : MO_Emit_0();

                        (16w112, true, false, true) : MO_Emit_-4();

        }

        const default_action = NoAction();
    }
    apply {
        deparser_tbl.apply();
    }
}

control Mpls(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout bit<16> inout_param) {
    Mpls_micro_parser() Mpls_micro_parser_inst;
    Mpls_micro_control() Mpls_micro_control_inst;
    Mpls_micro_deparser() Mpls_micro_deparser_inst;
    mpls_hdr_t mpls_hdr_t_var;
    mpls_meta_t mpls_meta_t_var;
    Mpls_parser_meta_t Mpls_parser_meta_t_var;
    Mpls_hdr_vop_t Mpls_hdr_vop_t_var;
    apply {
        Mpls_micro_parser_inst.apply(msa_packet_struct_t_var, mpls_hdr_t_var, mpls_meta_t_var, inout_param, Mpls_parser_meta_t_var);
        Mpls_micro_control_inst.apply(ig_intr_md_for_tm, mpls_hdr_t_var, mpls_meta_t_var, Mpls_hdr_vop_t_var);
        Mpls_micro_deparser_inst.apply(msa_packet_struct_t_var, mpls_hdr_t_var, Mpls_parser_meta_t_var, Mpls_hdr_vop_t_var);
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

control ModularMpls_micro_parser(inout msa_packet_struct_t p, out hdr_t hdr, out ModularMpls_parser_meta_t parser_meta) {
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

control ModularMpls_micro_control(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout hdr_t hdr) {
    @name(".NoAction") action NoAction_0() {
    }
    bit<16> nh_0;
    @name("ModularMpls.micro_control.mpls") Mpls() mpls_0;
    @name("ModularMpls.micro_control.forward") action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
        hdr.eth.dmac = dmac;
        hdr.eth.smac = smac;
        ig_intr_md_for_tm.ucast_egress_port = port;
    }
    @name("ModularMpls.micro_control.forward_tbl") table forward_tbl_0 {
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
        nh_0 = 16w10;
        mpls_0.apply(msa_packet_struct_t_var, ig_intr_md_for_tm, hdr.eth.ethType);
        forward_tbl_0.apply();
    }
}

control ModularMpls_micro_deparser(inout msa_packet_struct_t p, in hdr_t hdr, in ModularMpls_parser_meta_t parser_meta) {
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

control ModularMpls(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm) {
    ModularMpls_micro_parser() ModularMpls_micro_parser_inst;
    ModularMpls_micro_control() ModularMpls_micro_control_inst;
    ModularMpls_micro_deparser() ModularMpls_micro_deparser_inst;
    hdr_t hdr_t_var;
    ModularMpls_parser_meta_t ModularMpls_parser_meta_t_var;
    apply {
        ModularMpls_micro_parser_inst.apply(msa_packet_struct_t_var, hdr_t_var, ModularMpls_parser_meta_t_var);
        ModularMpls_micro_control_inst.apply(msa_packet_struct_t_var, ig_intr_md_for_tm, hdr_t_var);
        ModularMpls_micro_deparser_inst.apply(msa_packet_struct_t_var, hdr_t_var, ModularMpls_parser_meta_t_var);
    }
}

struct msa_user_metadata_t {
    empty_t in_param;
    empty_t out_param;
    empty_t inout_param;
}

parser msa_tofino_ig_parser(packet_in pin, out msa_packet_struct_t mpkt, out msa_user_metadata_t msa_um, out ingress_intrinsic_metadata_t ig_intr_md) {
    ParserCounter() pc0;
    state start {
        pc0.set((bit<8>)9);
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
    ModularMpls() ModularMpls_inst;
    apply {
        ModularMpls_inst.apply(mpkt, ig_intr_md_for_tm);
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
        pc0.set((bit<8>)9);
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
    apply {
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

