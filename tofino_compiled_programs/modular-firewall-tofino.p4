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
    msa_twobytes_h[32] msa_hdr_stack_s0;
    msa_twobytes_h[5]  msa_hdr_stack_s1;
}

struct ModularFirewall_parser_meta_t {
    bool   eth_v;
    bool   ipv4_v;
    bool   ipv6_v;
    bit<1> packet_reject;
}

struct Filter_L4_parser_meta_t {
    bool   tcp_v;
    bool   udp_v;
    bit<1> packet_reject;
}

struct Filter_L4_hdr_vop_t {
}

struct L3v4_parser_meta_t {
    bool   ipv4_v;
    bit<1> packet_reject;
}

struct L3v4_hdr_vop_t {
}

struct ModularFirewall_hdr_vop_t {
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
    bit<32> srcAddr;
    bit<32> dstAddr;
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
    action i_432_parse_ipv4_0() {
        parser_meta.ipv4_v = true;
        hdr.ipv4.version = p.msa_hdr_stack_s0[27].data[15:12];
        hdr.ipv4.ihl = p.msa_hdr_stack_s0[27].data[11:8];
        hdr.ipv4.diffserv = p.msa_hdr_stack_s0[27].data[7:0];
        hdr.ipv4.totalLen = p.msa_hdr_stack_s0[28].data;
        hdr.ipv4.identification = p.msa_hdr_stack_s0[29].data;
        hdr.ipv4.flags = p.msa_hdr_stack_s0[30].data[15:13];
        hdr.ipv4.fragOffset = p.msa_hdr_stack_s0[30].data[12:0];
        hdr.ipv4.ttl = p.msa_hdr_stack_s0[31].data[15:8];
        hdr.ipv4.protocol = p.msa_hdr_stack_s0[31].data[7:0];
        hdr.ipv4.hdrChecksum = p.msa_hdr_stack_s1[0].data;
        hdr.ipv4.srcAddr = p.msa_hdr_stack_s1[1].data ++ p.msa_hdr_stack_s1[2].data;
        hdr.ipv4.dstAddr = p.msa_hdr_stack_s1[3].data ++ p.msa_hdr_stack_s1[4].data;
    }
    action i_272_parse_ipv4_0() {
        parser_meta.ipv4_v = true;
        hdr.ipv4.version = p.msa_hdr_stack_s0[17].data[15:12];
        hdr.ipv4.ihl = p.msa_hdr_stack_s0[17].data[11:8];
        hdr.ipv4.diffserv = p.msa_hdr_stack_s0[17].data[7:0];
        hdr.ipv4.totalLen = p.msa_hdr_stack_s0[18].data;
        hdr.ipv4.identification = p.msa_hdr_stack_s0[19].data;
        hdr.ipv4.flags = p.msa_hdr_stack_s0[20].data[15:13];
        hdr.ipv4.fragOffset = p.msa_hdr_stack_s0[20].data[12:0];
        hdr.ipv4.ttl = p.msa_hdr_stack_s0[21].data[15:8];
        hdr.ipv4.protocol = p.msa_hdr_stack_s0[21].data[7:0];
        hdr.ipv4.hdrChecksum = p.msa_hdr_stack_s0[22].data;
        hdr.ipv4.srcAddr = p.msa_hdr_stack_s0[23].data ++ p.msa_hdr_stack_s0[24].data;
        hdr.ipv4.dstAddr = p.msa_hdr_stack_s0[25].data ++ p.msa_hdr_stack_s0[26].data;
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset: exact;
            ethType              : ternary;
        }
        actions = {
            i_432_parse_ipv4_0();
            micro_parser_reject();
            i_272_parse_ipv4_0();
            NoAction();
        }
        const entries = {
                        (16w272, 16w0x800) : i_272_parse_ipv4_0();

                        (16w272, default) : micro_parser_reject();

                        (16w432, 16w0x800) : i_432_parse_ipv4_0();

                        (16w432, default) : micro_parser_reject();

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
    action ipv4_54_74() {
        p.msa_hdr_stack_s0[31].data = h.ipv4.ttl ++ h.ipv4.protocol;
    }
    action ipv4_34_54() {
        p.msa_hdr_stack_s0[21].data = h.ipv4.ttl ++ h.ipv4.protocol;
    }
    table deparser_tbl {
        key = {
            p.indices.curr_offset: exact;
            parser_meta.ipv4_v   : exact;
        }
        actions = {
            ipv4_54_74();
            ipv4_34_54();
            NoAction();
        }
        const entries = {
                        (16w432, true) : ipv4_54_74();

                        (16w272, true) : ipv4_34_54();

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

struct filter_meta_t {
    bit<16> sport;
    bit<16> dport;
}

struct udp_h {
    bit<16> sport;
    bit<16> dport;
}

struct tcp_h {
    bit<16> sport;
    bit<16> dport;
}

struct callee_hdr_t {
    tcp_h tcp;
    udp_h udp;
}

control Filter_L4_micro_parser(inout msa_packet_struct_t p, out callee_hdr_t hdr, inout filter_meta_t meta, inout bit<8> l4proto, out Filter_L4_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.tcp_v = false;
        parser_meta.udp_v = false;
        parser_meta.packet_reject = 1w0b0;
    }
    action micro_parser_reject() {
        parser_meta.packet_reject = 1w0b1;
    }
    action i_432_parse_udp_0() {
        parser_meta.udp_v = true;
        hdr.udp.sport = p.msa_hdr_stack_s0[27].data;
        hdr.udp.dport = p.msa_hdr_stack_s0[28].data;
        meta.sport = hdr.udp.sport;
        meta.dport = hdr.udp.dport;
    }
    action i_272_parse_udp_0() {
        parser_meta.udp_v = true;
        hdr.udp.sport = p.msa_hdr_stack_s0[17].data;
        hdr.udp.dport = p.msa_hdr_stack_s0[18].data;
        meta.sport = hdr.udp.sport;
        meta.dport = hdr.udp.dport;
    }
    action i_432_parse_tcp_0() {
        parser_meta.tcp_v = true;
        hdr.tcp.sport = p.msa_hdr_stack_s0[27].data;
        hdr.tcp.dport = p.msa_hdr_stack_s0[28].data;
        meta.sport = hdr.tcp.sport;
        meta.dport = hdr.tcp.dport;
    }
    action i_272_parse_tcp_0() {
        parser_meta.tcp_v = true;
        hdr.tcp.sport = p.msa_hdr_stack_s0[17].data;
        hdr.tcp.dport = p.msa_hdr_stack_s0[18].data;
        meta.sport = hdr.tcp.sport;
        meta.dport = hdr.tcp.dport;
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset: exact;
            l4proto              : ternary;
        }
        actions = {
            i_432_parse_tcp_0();
            i_432_parse_udp_0();
            micro_parser_reject();
            i_272_parse_tcp_0();
            i_272_parse_udp_0();
            NoAction();
        }
        const entries = {
                        (16w272, 8w0x6) : i_272_parse_tcp_0();

                        (16w272, 8w0x17) : i_272_parse_udp_0();

                        (16w272, default) : micro_parser_reject();

                        (16w432, 8w0x6) : i_432_parse_tcp_0();

                        (16w432, 8w0x17) : i_432_parse_udp_0();

                        (16w432, default) : micro_parser_reject();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control Filter_L4_micro_control(inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout filter_meta_t m) {
    @name(".NoAction") action NoAction_0() {
    }
    @name("Filter_L4.micro_control.drop_action") action drop_action() {
        ig_intr_md_for_dprsr.drop_ctl = 3w0x1;
    }
    @name("Filter_L4.micro_control.filter_tbl") table filter_tbl_0 {
        key = {
            m.sport: exact @name("m.sport") ;
            m.dport: exact @name("m.dport") ;
        }
        actions = {
            drop_action();
            @defaultonly NoAction_0();
        }
        const entries = {
                        (16w0x4000, default) : drop_action();

                        (default, 16w0x4000) : drop_action();

        }

        default_action = NoAction_0();
    }
    apply {
        filter_tbl_0.apply();
    }
}

control Filter_L4_micro_deparser(inout msa_packet_struct_t p, in callee_hdr_t hdr, in Filter_L4_parser_meta_t parser_meta) {
    action tcp_54_58() {
    }
    action tcp_34_38() {
    }
    action udp_54_58() {
    }
    action udp_34_38() {
    }
    table deparser_tbl {
        key = {
            p.indices.curr_offset: exact;
            parser_meta.tcp_v    : exact;
            parser_meta.udp_v    : exact;
        }
        actions = {
            tcp_54_58();
            tcp_34_38();
            udp_54_58();
            udp_34_38();
            NoAction();
        }
        const entries = {
                        (16w432, true, false) : tcp_54_58();

                        (16w272, true, false) : tcp_34_38();

                        (16w432, false, true) : udp_54_58();

                        (16w272, false, true) : udp_34_38();

        }

        const default_action = NoAction();
    }
    apply {
        deparser_tbl.apply();
    }
}

control Filter_L4(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout bit<8> inout_param) {
    Filter_L4_micro_parser() Filter_L4_micro_parser_inst;
    Filter_L4_micro_control() Filter_L4_micro_control_inst;
    Filter_L4_micro_deparser() Filter_L4_micro_deparser_inst;
    callee_hdr_t callee_hdr_t_var;
    filter_meta_t filter_meta_t_var;
    Filter_L4_parser_meta_t Filter_L4_parser_meta_t_var;
    apply {
        Filter_L4_micro_parser_inst.apply(msa_packet_struct_t_var, callee_hdr_t_var, filter_meta_t_var, inout_param, Filter_L4_parser_meta_t_var);
        Filter_L4_micro_control_inst.apply(ig_intr_md_for_dprsr, filter_meta_t_var);
        Filter_L4_micro_deparser_inst.apply(msa_packet_struct_t_var, callee_hdr_t_var, Filter_L4_parser_meta_t_var);
    }
}

struct meta_t {
    bit<8> l4proto;
}

struct ethernet_h {
    bit<48> dmac;
    bit<48> smac;
    bit<16> ethType;
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

struct hdr_t {
    ethernet_h eth;
    ipv4_h     ipv4;
    ipv6_h     ipv6;
}

control ModularFirewall_micro_parser(inout msa_packet_struct_t p, out hdr_t hdr, inout meta_t m, out ModularFirewall_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.eth_v = false;
        parser_meta.ipv4_v = false;
        parser_meta.ipv6_v = false;
        parser_meta.packet_reject = 1w0b0;
    }
    action micro_parser_reject() {
        parser_meta.packet_reject = 1w0b1;
    }
    action i_0_parse_ipv6_0() {
        parser_meta.ipv6_v = true;
        hdr.ipv6.version = p.msa_hdr_stack_s0[7].data[15:12];
        hdr.ipv6.class = p.msa_hdr_stack_s0[7].data[11:4];
        hdr.ipv6.label = p.msa_hdr_stack_s0[7].data[3:0] ++ p.msa_hdr_stack_s0[8].data;
        hdr.ipv6.totalLen = p.msa_hdr_stack_s0[9].data;
        hdr.ipv6.nexthdr = p.msa_hdr_stack_s0[10].data[15:8];
        hdr.ipv6.hoplimit = p.msa_hdr_stack_s0[10].data[7:0];
        hdr.ipv6.srcAddr = p.msa_hdr_stack_s0[11].data ++ p.msa_hdr_stack_s0[12].data ++ p.msa_hdr_stack_s0[13].data ++ p.msa_hdr_stack_s0[14].data ++ p.msa_hdr_stack_s0[15].data ++ p.msa_hdr_stack_s0[16].data ++ p.msa_hdr_stack_s0[17].data ++ p.msa_hdr_stack_s0[18].data;
        hdr.ipv6.dstAddr = p.msa_hdr_stack_s0[19].data ++ p.msa_hdr_stack_s0[20].data ++ p.msa_hdr_stack_s0[21].data ++ p.msa_hdr_stack_s0[22].data ++ p.msa_hdr_stack_s0[23].data ++ p.msa_hdr_stack_s0[24].data ++ p.msa_hdr_stack_s0[25].data ++ p.msa_hdr_stack_s0[26].data;
        m.l4proto = hdr.ipv6.nexthdr;
        parser_meta.eth_v = true;
        hdr.eth.dmac = p.msa_hdr_stack_s0[0].data ++ p.msa_hdr_stack_s0[1].data ++ p.msa_hdr_stack_s0[2].data;
        hdr.eth.smac = p.msa_hdr_stack_s0[3].data ++ p.msa_hdr_stack_s0[4].data ++ p.msa_hdr_stack_s0[5].data;
        hdr.eth.ethType = p.msa_hdr_stack_s0[6].data;
    }
    action i_0_parse_ipv4_0() {
        parser_meta.ipv4_v = true;
        hdr.ipv4.version = p.msa_hdr_stack_s0[7].data[15:12];
        hdr.ipv4.ihl = p.msa_hdr_stack_s0[7].data[11:8];
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
        m.l4proto = hdr.ipv4.protocol;
        parser_meta.eth_v = true;
        hdr.eth.dmac = p.msa_hdr_stack_s0[0].data ++ p.msa_hdr_stack_s0[1].data ++ p.msa_hdr_stack_s0[2].data;
        hdr.eth.smac = p.msa_hdr_stack_s0[3].data ++ p.msa_hdr_stack_s0[4].data ++ p.msa_hdr_stack_s0[5].data;
        hdr.eth.ethType = p.msa_hdr_stack_s0[6].data;
    }
    table parser_tbl {
        key = {
            p.msa_hdr_stack_s0[6].data: ternary;
        }
        actions = {
            i_0_parse_ipv4_0();
            i_0_parse_ipv6_0();
            micro_parser_reject();
            NoAction();
        }
        const entries = {
                        16w0x800 : i_0_parse_ipv4_0();

                        16w0x86dd : i_0_parse_ipv6_0();

                        default : micro_parser_reject();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control ModularFirewall_micro_control(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout hdr_t hdr, inout meta_t m) {
    @name(".NoAction") action NoAction_0() {
    }
    bit<16> nh_0;
    @name("ModularFirewall.micro_control.filter") Filter_L4() filter_0;
    @name("ModularFirewall.micro_control.l3_i") L3v4() l3_i_0;
    @name("ModularFirewall.micro_control.forward") action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
        hdr.eth.dmac = dmac;
        hdr.eth.smac = smac;
        ig_intr_md_for_tm.ucast_egress_port = port;
    }
    @name("ModularFirewall.micro_control.forward_tbl") table forward_tbl_0 {
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
        filter_0.apply(msa_packet_struct_t_var, ig_intr_md_for_dprsr, m.l4proto);
        l3_i_0.apply(msa_packet_struct_t_var, nh_0, hdr.eth.ethType);
        forward_tbl_0.apply();
    }
}

control ModularFirewall_micro_deparser(inout msa_packet_struct_t p, in hdr_t hdr, in ModularFirewall_parser_meta_t parser_meta) {
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

control ModularFirewall(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm) {
    ModularFirewall_micro_parser() ModularFirewall_micro_parser_inst;
    ModularFirewall_micro_control() ModularFirewall_micro_control_inst;
    ModularFirewall_micro_deparser() ModularFirewall_micro_deparser_inst;
    hdr_t hdr_t_var;
    meta_t meta_t_var;
    ModularFirewall_parser_meta_t ModularFirewall_parser_meta_t_var;
    apply {
        ModularFirewall_micro_parser_inst.apply(msa_packet_struct_t_var, hdr_t_var, meta_t_var, ModularFirewall_parser_meta_t_var);
        ModularFirewall_micro_control_inst.apply(msa_packet_struct_t_var, ig_intr_md_for_dprsr, ig_intr_md_for_tm, hdr_t_var, meta_t_var);
        ModularFirewall_micro_deparser_inst.apply(msa_packet_struct_t_var, hdr_t_var, ModularFirewall_parser_meta_t_var);
    }
}

struct msa_user_metadata_t {
    empty_t in_param;
    empty_t out_param;
    empty_t inout_param;
}

parser msa_tofino_ig_parser(packet_in pin, out msa_packet_struct_t mpkt, out msa_user_metadata_t msa_um, out ingress_intrinsic_metadata_t ig_intr_md) {
    ParserCounter() pc0;
    ParserCounter() pc1;
    state start {
        pc0.set((bit<8>)32);
        pc1.set((bit<8>)5);
        transition parse_msa_hdr_stack_s0;
    }
    state parse_msa_hdr_stack_s0 {
        pc0.decrement(8w1);
        pin.extract(mpkt.msa_hdr_stack_s0.next);
        transition select(pc0.is_zero()) {
            false: parse_msa_hdr_stack_s0;
            true: parse_msa_hdr_stack_s1;
        }
    }
    state parse_msa_hdr_stack_s1 {
        pc1.decrement(8w1);
        pin.extract(mpkt.msa_hdr_stack_s1.next);
        transition select(pc1.is_zero()) {
            false: parse_msa_hdr_stack_s1;
            true: accept;
        }
    }
}

control msa_tofino_ig_control(inout msa_packet_struct_t mpkt, inout msa_user_metadata_t msa_um, in ingress_intrinsic_metadata_t ig_intr_md, in ingress_intrinsic_metadata_from_parser_t ig_intr_md_from_prsr, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm) {
    ModularFirewall() ModularFirewall_inst;
    apply {
        ModularFirewall_inst.apply(mpkt, ig_intr_md_for_dprsr, ig_intr_md_for_tm);
    }
}

control msa_tofino_ig_deparser(packet_out po, inout msa_packet_struct_t mpkt, in msa_user_metadata_t msa_um, in ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr) {
    apply {
        po.emit(mpkt.msa_hdr_stack_s0);
        po.emit(mpkt.msa_hdr_stack_s1);
        po.emit(mpkt.msa_byte);
    }
}

parser msa_tofino_eg_parser(packet_in pin, out msa_packet_struct_t mpkt, out msa_user_metadata_t msa_um, out egress_intrinsic_metadata_t eg_intr_md) {
    ParserCounter() pc0;
    ParserCounter() pc1;
    state start {
        pc0.set((bit<8>)32);
        pc1.set((bit<8>)5);
        transition parse_msa_hdr_stack_s0;
    }
    state parse_msa_hdr_stack_s0 {
        pc0.decrement(8w1);
        pin.extract(mpkt.msa_hdr_stack_s0.next);
        transition select(pc0.is_zero()) {
            false: parse_msa_hdr_stack_s0;
            true: parse_msa_hdr_stack_s1;
        }
    }
    state parse_msa_hdr_stack_s1 {
        pc1.decrement(8w1);
        pin.extract(mpkt.msa_hdr_stack_s1.next);
        transition select(pc1.is_zero()) {
            false: parse_msa_hdr_stack_s1;
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
        pkt_out.emit(mpkt.msa_hdr_stack_s1);
        pkt_out.emit(mpkt.msa_byte);
    }
}

Pipeline(msa_tofino_ig_parser(), msa_tofino_ig_control(), msa_tofino_ig_deparser(), msa_tofino_eg_parser(), msa_tofino_eg_control(), msa_tofino_eg_deparser()) pipe;

Switch(pipe) main;

