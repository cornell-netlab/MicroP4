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

struct swtrace_inout_t {
    bit<4>  ipv4_ihl;
    bit<16> ipv4_total_len;
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

struct l3_hdr_t {
    ipv6_h ipv6;
}

control L3v6_micro_parser(inout msa_packet_struct_t p, out l3_hdr_t hdr, inout bit<16> ethType, out L3v6_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.ipv6_v = false;
        parser_meta.packet_reject = 1w0b0;
    }
    action micro_parser_reject() {
        parser_meta.packet_reject = 1w0b1;
    }
    action i_112_parse_ipv6_0() {
        parser_meta.ipv6_v = true;
        hdr.ipv6.version = p.msa_hdr_stack_s0[7].data[15:12];
        hdr.ipv6.class = p.msa_hdr_stack_s0[7].data[11:4];
        hdr.ipv6.label = p.msa_hdr_stack_s0[7].data[3:0] ++ p.msa_hdr_stack_s0[8].data[15:0];
        hdr.ipv6.totalLen = p.msa_hdr_stack_s0[9].data[15:0];
        hdr.ipv6.nexthdr = p.msa_hdr_stack_s0[10].data[15:8];
        hdr.ipv6.hoplimit = p.msa_hdr_stack_s0[10].data[7:0];
        hdr.ipv6.srcAddr = p.msa_hdr_stack_s0[11].data[15:0] ++ p.msa_hdr_stack_s0[12].data[15:0] ++ p.msa_hdr_stack_s0[13].data[15:0] ++ p.msa_hdr_stack_s0[14].data[15:0] ++ p.msa_hdr_stack_s0[15].data[15:0] ++ p.msa_hdr_stack_s0[16].data[15:0] ++ p.msa_hdr_stack_s0[17].data[15:0] ++ p.msa_hdr_stack_s0[18].data[15:0];
        hdr.ipv6.dstAddr = p.msa_hdr_stack_s0[19].data[15:0] ++ p.msa_hdr_stack_s0[20].data[15:0] ++ p.msa_hdr_stack_s0[21].data[15:0] ++ p.msa_hdr_stack_s0[22].data[15:0] ++ p.msa_hdr_stack_s0[23].data[15:0] ++ p.msa_hdr_stack_s0[24].data[15:0] ++ p.msa_hdr_stack_s0[25].data[15:0] ++ p.msa_hdr_stack_s0[26].data[15:0];
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset: exact;
            ethType              : ternary;
        }
        actions = {
            i_112_parse_ipv6_0();
            micro_parser_reject();
            NoAction();
        }
        const entries = {
                        (16w112, 16w0x86dd) : i_112_parse_ipv6_0();

                        (16w112, default) : micro_parser_reject();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control L3v6_micro_control(inout l3_hdr_t hdr, out bit<128> nexthop) {
    @name(".NoAction") action NoAction_0() {
    }
    @name("L3v6.micro_control.process") action process(bit<128> nexthop_ipv6_addr) {
        hdr.ipv6.hoplimit = hdr.ipv6.hoplimit + 8w255;
        nexthop = nexthop_ipv6_addr;
    }
    @name("L3v6.micro_control.ipv6_lpm_tbl") table ipv6_lpm_tbl_0 {
        key = {
            hdr.ipv6.dstAddr: lpm @name("hdr.ipv6.dstAddr") ;
        }
        actions = {
            process();
            @defaultonly NoAction_0();
        }
        default_action = NoAction_0();
    }
    apply {
        ipv6_lpm_tbl_0.apply();
    }
}

control L3v6_micro_deparser(inout msa_packet_struct_t p, in l3_hdr_t h, in L3v6_parser_meta_t parser_meta) {
    action ipv6_14_54() {
        p.msa_hdr_stack_s0[7].data[15:0] = h.ipv6.version[3:0] ++ h.ipv6.class[7:0] ++ h.ipv6.label[19:16];
        p.msa_hdr_stack_s0[8].data[15:0] = h.ipv6.label[15:0];
        p.msa_hdr_stack_s0[9].data[15:0] = h.ipv6.totalLen[15:0];
        p.msa_hdr_stack_s0[10].data[15:0] = h.ipv6.nexthdr[7:0] ++ h.ipv6.hoplimit[7:0];
        p.msa_hdr_stack_s0[11].data[15:0] = h.ipv6.srcAddr[127:112];
        p.msa_hdr_stack_s0[12].data[15:0] = h.ipv6.srcAddr[111:96];
        p.msa_hdr_stack_s0[13].data[15:0] = h.ipv6.srcAddr[95:80];
        p.msa_hdr_stack_s0[14].data[15:0] = h.ipv6.srcAddr[79:64];
        p.msa_hdr_stack_s0[15].data[15:0] = h.ipv6.srcAddr[63:48];
        p.msa_hdr_stack_s0[16].data[15:0] = h.ipv6.srcAddr[47:32];
        p.msa_hdr_stack_s0[17].data[15:0] = h.ipv6.srcAddr[31:16];
        p.msa_hdr_stack_s0[18].data[15:0] = h.ipv6.srcAddr[15:0];
        p.msa_hdr_stack_s0[19].data[15:0] = h.ipv6.dstAddr[127:112];
        p.msa_hdr_stack_s0[20].data[15:0] = h.ipv6.dstAddr[111:96];
        p.msa_hdr_stack_s0[21].data[15:0] = h.ipv6.dstAddr[95:80];
        p.msa_hdr_stack_s0[22].data[15:0] = h.ipv6.dstAddr[79:64];
        p.msa_hdr_stack_s0[23].data[15:0] = h.ipv6.dstAddr[63:48];
        p.msa_hdr_stack_s0[24].data[15:0] = h.ipv6.dstAddr[47:32];
        p.msa_hdr_stack_s0[25].data[15:0] = h.ipv6.dstAddr[31:16];
        p.msa_hdr_stack_s0[26].data[15:0] = h.ipv6.dstAddr[15:0];
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

control L3v6(inout msa_packet_struct_t msa_packet_struct_t_var, out bit<128> out_param, inout bit<16> inout_param) {
    L3v6_micro_parser() L3v6_micro_parser_inst;
    L3v6_micro_control() L3v6_micro_control_inst;
    L3v6_micro_deparser() L3v6_micro_deparser_inst;
    l3_hdr_t l3_hdr_t_var;
    L3v6_parser_meta_t L3v6_parser_meta_t_var;
    apply {
        L3v6_micro_parser_inst.apply(msa_packet_struct_t_var, l3_hdr_t_var, inout_param, L3v6_parser_meta_t_var);
        L3v6_micro_control_inst.apply(l3_hdr_t_var, out_param);
        L3v6_micro_deparser_inst.apply(msa_packet_struct_t_var, l3_hdr_t_var, L3v6_parser_meta_t_var);
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
        hdr.eth.dmac = p.msa_hdr_stack_s0[0].data[15:0] ++ p.msa_hdr_stack_s0[1].data[15:0] ++ p.msa_hdr_stack_s0[2].data[15:0];
        hdr.eth.smac = p.msa_hdr_stack_s0[3].data[15:0] ++ p.msa_hdr_stack_s0[4].data[15:0] ++ p.msa_hdr_stack_s0[5].data[15:0];
        hdr.eth.ethType = p.msa_hdr_stack_s0[6].data[15:0];
    }
    apply {
        micro_parser_init();
        i_0_start_0();
    }
}

control ModularRouterv6_micro_control(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout hdr_t hdr) {
    @name(".NoAction") action NoAction_0() {
    }
    bit<128> nh_0;
    @name("ModularRouterv6.micro_control.l3_i") L3v6() l3_i_0;
    @name("ModularRouterv6.micro_control.forward") action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
        hdr.eth.dmac = dmac;
        hdr.eth.smac = smac;
        ig_intr_md_for_tm.ucast_egress_port = port;
    }
    @name("ModularRouterv6.micro_control.forward_tbl") table forward_tbl_0 {
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

control ModularRouterv6_micro_deparser(inout msa_packet_struct_t p, in hdr_t hdr, in ModularRouterv6_parser_meta_t parser_meta) {
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

control ModularRouterv6(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm) {
    ModularRouterv6_micro_parser() ModularRouterv6_micro_parser_inst;
    ModularRouterv6_micro_control() ModularRouterv6_micro_control_inst;
    ModularRouterv6_micro_deparser() ModularRouterv6_micro_deparser_inst;
    hdr_t hdr_t_var;
    ModularRouterv6_parser_meta_t ModularRouterv6_parser_meta_t_var;
    apply {
        ModularRouterv6_micro_parser_inst.apply(msa_packet_struct_t_var, hdr_t_var, ModularRouterv6_parser_meta_t_var);
        ModularRouterv6_micro_control_inst.apply(msa_packet_struct_t_var, ig_intr_md_for_tm, hdr_t_var);
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
        ModularRouterv6_inst.apply(mpkt, ig_intr_md_for_tm);
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

