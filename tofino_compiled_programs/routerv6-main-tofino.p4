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

#if __TARGET_TOFINO__ == 2
@pa_container_type ("ingress", "mpkt.msa_hdr_stack_s0[11].data", "normal")
@pa_container_type ("ingress", "mpkt.msa_hdr_stack_s0[10].data", "normal")
#endif
struct msa_packet_struct_t {
    csa_indices_h      indices;
    msa_byte_h         msa_byte;
    msa_twobytes_h[27] msa_hdr_stack_s0;
}

struct ModularRouterv6_parser_meta_t {
    bool   eth_v;
    bit<1> packet_reject;
}

struct L3v6_parser_meta_t {
    bool   ipv6_v;
    bit<1> packet_reject;
}

struct L3v6_hdr_vop_t {
}

struct ModularRouterv6_hdr_vop_t {
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
    bit<16> eth_type;
    bit<16> next_hop;
}

struct l3_meta_t {
}

struct ipv6_h {
    bit<4>   version;
    bit<8>   class;
    bit<20>  label;
    bit<16>  totalLen;
    bit<8>   nexthdr;
    bit<8>   hoplimit;
    bit<128> srcAddr;
    bit<128> dstAddr;
}

struct l3v6_hdr_t {
    ipv6_h ipv6;
}

control L3v6_micro_parser(inout msa_packet_struct_t p, out l3v6_hdr_t hdr, out L3v6_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.ipv6_v = false;
        parser_meta.packet_reject = 1w0b0;
    }
    action i_112_start_0() {
        parser_meta.ipv6_v = true;
        hdr.ipv6.version = p.msa_hdr_stack_s0[7].data[15:12];
        hdr.ipv6.class = p.msa_hdr_stack_s0[7].data[11:4];
        hdr.ipv6.label = p.msa_hdr_stack_s0[7].data[3:0] ++ p.msa_hdr_stack_s0[8].data;
        hdr.ipv6.totalLen = p.msa_hdr_stack_s0[9].data;
        hdr.ipv6.nexthdr = p.msa_hdr_stack_s0[10].data[15:8];
        hdr.ipv6.hoplimit = p.msa_hdr_stack_s0[10].data[7:0];
        hdr.ipv6.srcAddr = p.msa_hdr_stack_s0[11].data ++ p.msa_hdr_stack_s0[12].data ++ p.msa_hdr_stack_s0[13].data ++ p.msa_hdr_stack_s0[14].data ++ p.msa_hdr_stack_s0[15].data ++ p.msa_hdr_stack_s0[16].data ++ p.msa_hdr_stack_s0[17].data ++ p.msa_hdr_stack_s0[18].data;
        hdr.ipv6.dstAddr = p.msa_hdr_stack_s0[19].data ++ p.msa_hdr_stack_s0[20].data ++ p.msa_hdr_stack_s0[21].data ++ p.msa_hdr_stack_s0[22].data ++ p.msa_hdr_stack_s0[23].data ++ p.msa_hdr_stack_s0[24].data ++ p.msa_hdr_stack_s0[25].data ++ p.msa_hdr_stack_s0[26].data;
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

control L3v6_micro_control(inout l3v6_hdr_t hdr, out bit<16> nexthop) {
    @name("L3v6.micro_control.process") action process(bit<16> nh) {
        hdr.ipv6.hoplimit = hdr.ipv6.hoplimit + 8w255;
        nexthop = nh;
    }
    @name("L3v6.micro_control.default_act") action default_act() {
        nexthop = 16w0;
    }
    @name("L3v6.micro_control.ipv6_lpm_tbl") table ipv6_lpm_tbl_0 {
        key = {
            hdr.ipv6.dstAddr: lpm @name("hdr.ipv6.dstAddr") ;
            hdr.ipv6.class  : ternary @name("hdr.ipv6.class") ;
            hdr.ipv6.label  : ternary @name("hdr.ipv6.label") ;
        }
        actions = {
            process();
            default_act();
        }
        default_action = default_act();
    }
    apply {
        ipv6_lpm_tbl_0.apply();
    }
}

control L3v6_micro_deparser(inout msa_packet_struct_t p, in l3v6_hdr_t h, in L3v6_parser_meta_t parser_meta) {
    action ipv6_14_54() {
        p.msa_hdr_stack_s0[10].data = h.ipv6.nexthdr ++ h.ipv6.hoplimit;
    }
    table deparser_tbl {
        key = {
            p.indices.curr_offset: exact;
            parser_meta.ipv6_v   : exact;
        }
        actions = {
            ipv6_14_54();
            NoAction();
        }
        const entries = {
                        (16w112, true) : ipv6_14_54();

        }

        const default_action = NoAction();
    }
    apply {
        deparser_tbl.apply();
    }
}

control L3v6(inout msa_packet_struct_t msa_packet_struct_t_var, out bit<16> out_param) {
    L3v6_micro_parser() L3v6_micro_parser_inst;
    L3v6_micro_control() L3v6_micro_control_inst;
    L3v6_micro_deparser() L3v6_micro_deparser_inst;
    l3v6_hdr_t l3v6_hdr_t_var;
    L3v6_parser_meta_t L3v6_parser_meta_t_var;
    apply {
        L3v6_micro_parser_inst.apply(msa_packet_struct_t_var, l3v6_hdr_t_var, L3v6_parser_meta_t_var);
        L3v6_micro_control_inst.apply(l3v6_hdr_t_var, out_param);
        L3v6_micro_deparser_inst.apply(msa_packet_struct_t_var, l3v6_hdr_t_var, L3v6_parser_meta_t_var);
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

control ModularRouterv6_micro_parser(inout msa_packet_struct_t p, out hdr_t hdr, out ModularRouterv6_parser_meta_t parser_meta) {
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

control ModularRouterv6_micro_control(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout hdr_t hdr) {
    @name(".NoAction") action NoAction_0() {
    }
    bit<16> nh_0;
    @name("ModularRouterv6.micro_control.l3_i") L3v6() l3_i_0;
    @name("ModularRouterv6.micro_control.forward") action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
        hdr.eth.dmac = dmac;
        hdr.eth.smac = smac;
        ig_intr_md_for_tm.ucast_egress_port = port;
    }
    @name("ModularRouterv6.micro_control.forward_tbl") table forward_tbl_0 {
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
        if (hdr.eth.ethType == 16w0x86dd) {
            l3_i_0.apply(msa_packet_struct_t_var, nh_0);
            forward_tbl_0.apply();
        }
        else 
            ig_intr_md_for_dprsr.drop_ctl = 3w0x1;
    }
}

control ModularRouterv6_micro_deparser(inout msa_packet_struct_t p, in hdr_t hdr, in ModularRouterv6_parser_meta_t parser_meta) {
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

control ModularRouterv6(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm) {
    ModularRouterv6_micro_parser() ModularRouterv6_micro_parser_inst;
    ModularRouterv6_micro_control() ModularRouterv6_micro_control_inst;
    ModularRouterv6_micro_deparser() ModularRouterv6_micro_deparser_inst;
    hdr_t hdr_t_var;
    ModularRouterv6_parser_meta_t ModularRouterv6_parser_meta_t_var;
    apply {
        ModularRouterv6_micro_parser_inst.apply(msa_packet_struct_t_var, hdr_t_var, ModularRouterv6_parser_meta_t_var);
        ModularRouterv6_micro_control_inst.apply(msa_packet_struct_t_var, ig_intr_md_for_dprsr, ig_intr_md_for_tm, hdr_t_var);
        ModularRouterv6_micro_deparser_inst.apply(msa_packet_struct_t_var, hdr_t_var, ModularRouterv6_parser_meta_t_var);
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
        pc0.set((bit<8>)27);
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
    ModularRouterv6() ModularRouterv6_inst;
    apply {
        ModularRouterv6_inst.apply(mpkt, ig_intr_md_for_dprsr, ig_intr_md_for_tm);
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
        pc0.set((bit<8>)27);
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

