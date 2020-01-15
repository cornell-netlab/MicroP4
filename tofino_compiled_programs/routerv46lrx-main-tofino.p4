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
    msa_twobytes_h[31] msa_hdr_stack_s0;
}

struct MPRouter_parser_meta_t {
    bool   eth_v;
    bit<1> packet_reject;
}

struct L3v4_parser_meta_t {
    bool   ipv4_v;
    bit<1> packet_reject;
}

struct L3v4_hdr_vop_t {
}

struct L3v6_parser_meta_t {
    bool   ipv6_v;
    bit<1> packet_reject;
}

struct L3v6_hdr_vop_t {
}

struct MplsLR_parser_meta_t {
    bool   mpls0_v;
    bool   mpls1_v;
    bit<1> packet_reject;
}

struct MplsLR_hdr_vop_t {
    bool mpls1_sv;
    bool mpls1_siv;
    bool mpls0_sv;
    bool mpls0_siv;
}

struct MPRouter_hdr_vop_t {
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

control L3v4_micro_parser(inout msa_packet_struct_t p, out l3v4_hdr_t hdr, out L3v4_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.ipv4_v = false;
        parser_meta.packet_reject = 1w0b0;
    }
    action i_112_start_0() {
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

control L3v4_micro_deparser(inout msa_packet_struct_t p, in l3v4_hdr_t h, in L3v4_parser_meta_t parser_meta) {
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

control L3v4(inout msa_packet_struct_t msa_packet_struct_t_var, out bit<16> out_param) {
    L3v4_micro_parser() L3v4_micro_parser_inst;
    L3v4_micro_control() L3v4_micro_control_inst;
    L3v4_micro_deparser() L3v4_micro_deparser_inst;
    l3v4_hdr_t l3v4_hdr_t_var;
    L3v4_parser_meta_t L3v4_parser_meta_t_var;
    apply {
        L3v4_micro_parser_inst.apply(msa_packet_struct_t_var, l3v4_hdr_t_var, L3v4_parser_meta_t_var);
        L3v4_micro_control_inst.apply(l3v4_hdr_t_var, out_param);
        L3v4_micro_deparser_inst.apply(msa_packet_struct_t_var, l3v4_hdr_t_var, L3v4_parser_meta_t_var);
    }
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

struct mpls_h {
    bit<32> label;
    bit<16> exp;
    bit<8>  bos;
    bit<8>  ttl;
}

struct mpls_hdr_t {
    mpls_h mpls0;
    mpls_h mpls1;
}

control MplsLR_micro_parser(inout msa_packet_struct_t p, out mpls_hdr_t hdr, inout mplslr_inout_t ioa, out MplsLR_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.mpls0_v = false;
        parser_meta.mpls1_v = false;
        parser_meta.packet_reject = 1w0b0;
    }
    action micro_parser_reject() {
        parser_meta.packet_reject = 1w0b1;
    }
    action i_112_start_0() {
    }
    action i_112_parse_mpls0_0() {
        parser_meta.mpls0_v = true;
        hdr.mpls0.label = p.msa_hdr_stack_s0[7].data ++ p.msa_hdr_stack_s0[8].data;
        hdr.mpls0.exp = p.msa_hdr_stack_s0[9].data;
        hdr.mpls0.bos = p.msa_hdr_stack_s0[10].data[15:8];
        hdr.mpls0.ttl = p.msa_hdr_stack_s0[10].data[7:0];
    }
    action i_112_parse_mpls1_0() {
        parser_meta.mpls1_v = true;
        hdr.mpls1.label = p.msa_hdr_stack_s0[11].data ++ p.msa_hdr_stack_s0[12].data;
        hdr.mpls1.exp = p.msa_hdr_stack_s0[13].data;
        hdr.mpls1.bos = p.msa_hdr_stack_s0[14].data[15:8];
        hdr.mpls1.ttl = p.msa_hdr_stack_s0[14].data[7:0];
        parser_meta.mpls0_v = true;
        hdr.mpls0.label = p.msa_hdr_stack_s0[7].data ++ p.msa_hdr_stack_s0[8].data;
        hdr.mpls0.exp = p.msa_hdr_stack_s0[9].data;
        hdr.mpls0.bos = p.msa_hdr_stack_s0[10].data[15:8];
        hdr.mpls0.ttl = p.msa_hdr_stack_s0[10].data[7:0];
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset            : exact;
            ioa.eth_type                     : ternary;
            p.msa_hdr_stack_s0[10].data[15:8]: ternary;
        }
        actions = {
            i_112_start_0();
            i_112_parse_mpls0_0();
            i_112_parse_mpls1_0();
            micro_parser_reject();
            NoAction();
        }
        const entries = {
                        (16w112, 16w0x8847, 8w0) : i_112_parse_mpls1_0();

                        (16w112, 16w0x8847, default) : micro_parser_reject();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control MplsLR_micro_control(inout ingress_intrinsic_metadata_for_deparser_t
ig_intr_md_for_dprsr, inout mpls_hdr_t hdr, inout mplslr_inout_t ioa, in
MplsLR_parser_meta_t parser_meta, inout MplsLR_hdr_vop_t hdr_vop) {
    @name(".NoAction") action NoAction_0() {
    }
    @name("MplsLR.micro_control.drop_action") action drop_action() {
        ig_intr_md_for_dprsr.drop_ctl = 3w0x1;
    }
    @name("MplsLR.micro_control.encap1") action encap1() {
        ioa.eth_type = 16w0x8847;
        hdr_vop.mpls1_sv = true;
        hdr_vop.mpls1_siv = false;
        hdr.mpls1.label = hdr.mpls0.label;
        hdr.mpls1.ttl = hdr.mpls0.ttl;
        hdr.mpls1.exp = hdr.mpls0.exp;
        hdr.mpls0.label = 32w0x400;
        hdr.mpls0.ttl = 8w32;
        hdr.mpls1.bos = 8w0;
        ioa.next_hop = 16w10;
    }
    @name("MplsLR.micro_control.encap0") action encap0() {
        ioa.eth_type = 16w0x8847;
        hdr_vop.mpls0_sv = true;
        hdr_vop.mpls0_siv = false;
        hdr.mpls0.label = 32w0x4000;
        hdr.mpls0.ttl = 8w32;
        ioa.next_hop = 16w10;
    }
    @name("MplsLR.micro_control.decap") action decap() {
        ioa.eth_type = 16w0x800;
        hdr_vop.mpls0_sv = false;
        hdr_vop.mpls0_siv = true;
        ioa.next_hop = 16w10;
    }
    @name("MplsLR.micro_control.replace") action replace() {
        hdr.mpls0.ttl = hdr.mpls0.ttl + 8w255;
        ioa.next_hop = 16w10;
    }
    @name("MplsLR.micro_control.mpls_tbl") table mpls_tbl_0 {
        key = {
            parser_meta.mpls0_v || hdr_vop.mpls0_sv: exact @name("hdr.mpls0.$valid$") ;
            hdr.mpls0.ttl                          : exact @name("hdr.mpls0.ttl") ;
            hdr.mpls0.label                        : exact @name("hdr.mpls0.label") ;
            ioa.next_hop                           : exact @name("ioa.next_hop") ;
            ioa.eth_type                           : exact @name("ioa.eth_type") ;
        }
        actions = {
            drop_action();
            encap0();
            encap1();
            decap();
            replace();
            @defaultonly NoAction_0();
        }
        default_action = NoAction_0();
    }
    apply {
        mpls_tbl_0.apply();
    }
}

control MplsLR_micro_deparser(inout msa_packet_struct_t p, in mpls_hdr_t hdr, in MplsLR_parser_meta_t parser_meta, in MplsLR_hdr_vop_t hdr_vop) {
    action mpls0_14_22() {
        p.msa_hdr_stack_s0[7].data = hdr.mpls0.label[31:16];
        p.msa_hdr_stack_s0[8].data = hdr.mpls0.label[15:0];
        p.msa_hdr_stack_s0[10].data = hdr.mpls0.bos ++ hdr.mpls0.ttl;
    }
    action mpls1_14_22() {
        p.msa_hdr_stack_s0[7].data = hdr.mpls1.label[31:16];
        p.msa_hdr_stack_s0[8].data = hdr.mpls1.label[15:0];
        p.msa_hdr_stack_s0[9].data = hdr.mpls1.exp;
        p.msa_hdr_stack_s0[10].data = hdr.mpls1.bos ++ hdr.mpls1.ttl;
    }
    action mpls1_22_30() {
        p.msa_hdr_stack_s0[11].data = hdr.mpls1.label[31:16];
        p.msa_hdr_stack_s0[12].data = hdr.mpls1.label[15:0];
        p.msa_hdr_stack_s0[13].data = hdr.mpls1.exp;
        p.msa_hdr_stack_s0[14].data = hdr.mpls1.bos ++ hdr.mpls1.ttl;
    }
    action move_14_8_40() {
        p.msa_hdr_stack_s0[30].data = p.msa_hdr_stack_s0[26].data;
        p.msa_hdr_stack_s0[29].data = p.msa_hdr_stack_s0[25].data;
        p.msa_hdr_stack_s0[28].data = p.msa_hdr_stack_s0[24].data;
        p.msa_hdr_stack_s0[27].data = p.msa_hdr_stack_s0[23].data;
        p.msa_hdr_stack_s0[26].data = p.msa_hdr_stack_s0[22].data;
        p.msa_hdr_stack_s0[25].data = p.msa_hdr_stack_s0[21].data;
        p.msa_hdr_stack_s0[24].data = p.msa_hdr_stack_s0[20].data;
        p.msa_hdr_stack_s0[23].data = p.msa_hdr_stack_s0[19].data;
        p.msa_hdr_stack_s0[22].data = p.msa_hdr_stack_s0[18].data;
        p.msa_hdr_stack_s0[21].data = p.msa_hdr_stack_s0[17].data;
        p.msa_hdr_stack_s0[20].data = p.msa_hdr_stack_s0[16].data;
        p.msa_hdr_stack_s0[19].data = p.msa_hdr_stack_s0[15].data;
        p.msa_hdr_stack_s0[18].data = p.msa_hdr_stack_s0[14].data;
        p.msa_hdr_stack_s0[17].data = p.msa_hdr_stack_s0[13].data;
        p.msa_hdr_stack_s0[16].data = p.msa_hdr_stack_s0[12].data;
        p.msa_hdr_stack_s0[15].data = p.msa_hdr_stack_s0[11].data;
        p.msa_hdr_stack_s0[14].data = p.msa_hdr_stack_s0[10].data;
        p.msa_hdr_stack_s0[13].data = p.msa_hdr_stack_s0[9].data;
        p.msa_hdr_stack_s0[12].data = p.msa_hdr_stack_s0[8].data;
        p.msa_hdr_stack_s0[11].data = p.msa_hdr_stack_s0[7].data;
    }
    action mpls0_14_22_MO_Emit_8() {
        move_14_8_40();
        mpls0_14_22();
    }
    action mpls0_14_22_MO_Emit_mi0() {
        mpls0_14_22();
    }
    action move_14_8_8() {
    }
    action move_22_8_32() {
        p.msa_hdr_stack_s0[30].data = p.msa_hdr_stack_s0[26].data;
        p.msa_hdr_stack_s0[29].data = p.msa_hdr_stack_s0[25].data;
        p.msa_hdr_stack_s0[28].data = p.msa_hdr_stack_s0[24].data;
        p.msa_hdr_stack_s0[27].data = p.msa_hdr_stack_s0[23].data;
        p.msa_hdr_stack_s0[26].data = p.msa_hdr_stack_s0[22].data;
        p.msa_hdr_stack_s0[25].data = p.msa_hdr_stack_s0[21].data;
        p.msa_hdr_stack_s0[24].data = p.msa_hdr_stack_s0[20].data;
        p.msa_hdr_stack_s0[23].data = p.msa_hdr_stack_s0[19].data;
        p.msa_hdr_stack_s0[22].data = p.msa_hdr_stack_s0[18].data;
        p.msa_hdr_stack_s0[21].data = p.msa_hdr_stack_s0[17].data;
        p.msa_hdr_stack_s0[20].data = p.msa_hdr_stack_s0[16].data;
        p.msa_hdr_stack_s0[19].data = p.msa_hdr_stack_s0[15].data;
        p.msa_hdr_stack_s0[18].data = p.msa_hdr_stack_s0[14].data;
        p.msa_hdr_stack_s0[17].data = p.msa_hdr_stack_s0[13].data;
        p.msa_hdr_stack_s0[16].data = p.msa_hdr_stack_s0[12].data;
        p.msa_hdr_stack_s0[15].data = p.msa_hdr_stack_s0[11].data;
    }
    action mpls0_14_22_mpls1_14_22_MO_Emit_8() {
        move_22_8_32();
        move_14_8_8();
        mpls1_22_30();
        mpls0_14_22();
    }
    action mpls0_14_22_mpls1_22_30_MO_Emit_mi0() {
        mpls1_22_30();
        mpls0_14_22();
    }
    action mpls1_14_22_MO_Emit_8() {
        move_14_8_40();
        mpls1_14_22();
    }
    action mpls0_14_22_mpls1_22_30_MO_Emit_8() {
        move_22_8_32();
        mpls1_22_30();
        mpls0_14_22();
    }
    action mpls1_14_22_MO_Emit_mi0() {
        mpls1_14_22();
    }
    action MO_Emit_mi0() {
    }
    action move_22_mi8_40() {
        p.msa_hdr_stack_s0[7].data = p.msa_hdr_stack_s0[11].data;
        p.msa_hdr_stack_s0[8].data = p.msa_hdr_stack_s0[12].data;
        p.msa_hdr_stack_s0[9].data = p.msa_hdr_stack_s0[13].data;
        p.msa_hdr_stack_s0[10].data = p.msa_hdr_stack_s0[14].data;
        p.msa_hdr_stack_s0[11].data = p.msa_hdr_stack_s0[15].data;
        p.msa_hdr_stack_s0[12].data = p.msa_hdr_stack_s0[16].data;
        p.msa_hdr_stack_s0[13].data = p.msa_hdr_stack_s0[17].data;
        p.msa_hdr_stack_s0[14].data = p.msa_hdr_stack_s0[18].data;
        p.msa_hdr_stack_s0[15].data = p.msa_hdr_stack_s0[19].data;
        p.msa_hdr_stack_s0[16].data = p.msa_hdr_stack_s0[20].data;
        p.msa_hdr_stack_s0[17].data = p.msa_hdr_stack_s0[21].data;
        p.msa_hdr_stack_s0[18].data = p.msa_hdr_stack_s0[22].data;
        p.msa_hdr_stack_s0[19].data = p.msa_hdr_stack_s0[23].data;
        p.msa_hdr_stack_s0[20].data = p.msa_hdr_stack_s0[24].data;
        p.msa_hdr_stack_s0[21].data = p.msa_hdr_stack_s0[25].data;
        p.msa_hdr_stack_s0[22].data = p.msa_hdr_stack_s0[26].data;
        p.msa_hdr_stack_s0[23].data = p.msa_hdr_stack_s0[27].data;
        p.msa_hdr_stack_s0[24].data = p.msa_hdr_stack_s0[28].data;
        p.msa_hdr_stack_s0[25].data = p.msa_hdr_stack_s0[29].data;
        p.msa_hdr_stack_s0[26].data = p.msa_hdr_stack_s0[30].data;
    }
    action MO_Emit_mi8() {
        move_22_mi8_40();
    }
    action move_30_mi8_32() {
        p.msa_hdr_stack_s0[11].data = p.msa_hdr_stack_s0[15].data;
        p.msa_hdr_stack_s0[12].data = p.msa_hdr_stack_s0[16].data;
        p.msa_hdr_stack_s0[13].data = p.msa_hdr_stack_s0[17].data;
        p.msa_hdr_stack_s0[14].data = p.msa_hdr_stack_s0[18].data;
        p.msa_hdr_stack_s0[15].data = p.msa_hdr_stack_s0[19].data;
        p.msa_hdr_stack_s0[16].data = p.msa_hdr_stack_s0[20].data;
        p.msa_hdr_stack_s0[17].data = p.msa_hdr_stack_s0[21].data;
        p.msa_hdr_stack_s0[18].data = p.msa_hdr_stack_s0[22].data;
        p.msa_hdr_stack_s0[19].data = p.msa_hdr_stack_s0[23].data;
        p.msa_hdr_stack_s0[20].data = p.msa_hdr_stack_s0[24].data;
        p.msa_hdr_stack_s0[21].data = p.msa_hdr_stack_s0[25].data;
        p.msa_hdr_stack_s0[22].data = p.msa_hdr_stack_s0[26].data;
        p.msa_hdr_stack_s0[23].data = p.msa_hdr_stack_s0[27].data;
        p.msa_hdr_stack_s0[24].data = p.msa_hdr_stack_s0[28].data;
        p.msa_hdr_stack_s0[25].data = p.msa_hdr_stack_s0[29].data;
        p.msa_hdr_stack_s0[26].data = p.msa_hdr_stack_s0[30].data;
    }
    action move_22_mi8_8() {
    }
    action mpls1_22_30_MO_Emit_mi8() {
        move_22_mi8_8();
        mpls1_14_22();
        move_30_mi8_32();
    }
    table deparser_tbl {
        key = {
            p.indices.curr_offset: exact;
            parser_meta.mpls0_v  : exact;
            parser_meta.mpls1_v  : exact;
            hdr_vop.mpls1_sv     : exact;
            hdr_vop.mpls0_sv     : exact;
            hdr_vop.mpls0_siv    : exact;
        }
        actions = {
            mpls0_14_22();
            move_14_8_40();
            mpls0_14_22_MO_Emit_8();
            mpls0_14_22_MO_Emit_mi0();
            mpls1_22_30();
            move_14_8_8();
            move_22_8_32();
            mpls0_14_22_mpls1_14_22_MO_Emit_8();
            mpls0_14_22_mpls1_22_30_MO_Emit_mi0();
            mpls1_14_22();
            mpls1_14_22_MO_Emit_8();
            mpls0_14_22_mpls1_22_30_MO_Emit_8();
            mpls1_14_22_MO_Emit_mi0();
            MO_Emit_mi0();
            move_22_mi8_40();
            MO_Emit_mi8();
            move_30_mi8_32();
            move_22_mi8_8();
            mpls1_22_30_MO_Emit_mi8();
            NoAction();
        }
        const entries = {
                        (16w112, false, false, false, true, false) : mpls0_14_22_MO_Emit_8();

                        (16w112, true, false, false, true, false) : mpls0_14_22_MO_Emit_mi0();

                        (16w112, false, true, false, true, false) : mpls0_14_22_mpls1_14_22_MO_Emit_8();

                        (16w112, true, true, false, true, false) : mpls0_14_22_mpls1_22_30_MO_Emit_mi0();

                        (16w112, false, false, true, false, false) : mpls1_14_22_MO_Emit_8();

                        (16w112, true, false, true, false, false) : mpls0_14_22_mpls1_22_30_MO_Emit_8();

                        (16w112, false, true, true, false, false) : mpls1_14_22_MO_Emit_mi0();

                        (16w112, true, true, true, false, false) : mpls0_14_22_mpls1_22_30_MO_Emit_mi0();

                        (16w112, false, false, false, false, true) : MO_Emit_mi0();

                        (16w112, true, false, false, false, true) : MO_Emit_mi8();

                        (16w112, false, true, false, false, true) : mpls1_14_22_MO_Emit_mi0();

                        (16w112, true, true, false, false, true) : mpls1_22_30_MO_Emit_mi8();

        }

        const default_action = NoAction();
    }
    apply {
        deparser_tbl.apply();
    }
}

control MplsLR(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout mplslr_inout_t inout_param) {
    MplsLR_micro_parser() MplsLR_micro_parser_inst;
    MplsLR_micro_control() MplsLR_micro_control_inst;
    MplsLR_micro_deparser() MplsLR_micro_deparser_inst;
    mpls_hdr_t mpls_hdr_t_var;
    MplsLR_parser_meta_t MplsLR_parser_meta_t_var;
    MplsLR_hdr_vop_t MplsLR_hdr_vop_t_var;
    apply {
        MplsLR_hdr_vop_t_var.mpls1_sv = false;
        MplsLR_hdr_vop_t_var.mpls1_siv = false;
        MplsLR_hdr_vop_t_var.mpls0_sv = false;
        MplsLR_hdr_vop_t_var.mpls0_siv = false;
        MplsLR_micro_parser_inst.apply(msa_packet_struct_t_var, mpls_hdr_t_var, inout_param, MplsLR_parser_meta_t_var);
        MplsLR_micro_control_inst.apply(ig_intr_md_for_dprsr, mpls_hdr_t_var, inout_param, MplsLR_parser_meta_t_var, MplsLR_hdr_vop_t_var);
        MplsLR_micro_deparser_inst.apply(msa_packet_struct_t_var, mpls_hdr_t_var, MplsLR_parser_meta_t_var, MplsLR_hdr_vop_t_var);
    }
}

struct ethernet_h {
    bit<48> dmac;
    bit<48> smac;
    bit<16> ethType;
}

struct hdr_t {
    ethernet_h eth;
}

control MPRouter_micro_parser(inout msa_packet_struct_t p, out hdr_t hdr, out MPRouter_parser_meta_t parser_meta) {
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

control MPRouter_micro_control(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout hdr_t hdr) {
    @name(".NoAction") action NoAction_0() {
    }
    bit<16> nh_0;
    mplslr_inout_t mplsio_0;
    @name("MPRouter.micro_control.l3v4_i") L3v4() l3v4_i_0;
    @name("MPRouter.micro_control.l3v6_i") L3v6() l3v6_i_0;
    @name("MPRouter.micro_control.mpls_i") MplsLR() mpls_i_0;
    @name("MPRouter.micro_control.forward") action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
        hdr.eth.dmac = dmac;
        hdr.eth.smac = smac;
        ig_intr_md_for_tm.ucast_egress_port = port;
    }
    @name("MPRouter.micro_control.forward_tbl") table forward_tbl_0 {
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
        nh_0 = 16w0;
        if (hdr.eth.ethType == 16w0x800) 
            l3v4_i_0.apply(msa_packet_struct_t_var, nh_0);
        else 
            if (hdr.eth.ethType == 16w0x86dd) 
                l3v6_i_0.apply(msa_packet_struct_t_var, nh_0);
        mplsio_0.eth_type = hdr.eth.ethType;
        mplsio_0.next_hop = nh_0;
        if (nh_0 == 16w0) 
            mpls_i_0.apply(msa_packet_struct_t_var, ig_intr_md_for_dprsr, mplsio_0);
        hdr.eth.ethType = mplsio_0.eth_type;
        nh_0 = mplsio_0.next_hop;
        forward_tbl_0.apply();
    }
}

control MPRouter_micro_deparser(inout msa_packet_struct_t p, in hdr_t hdr, in MPRouter_parser_meta_t parser_meta) {
    action eth_0_14() {
        p.msa_hdr_stack_s0[0].data = hdr.eth.dmac[47:32];
        p.msa_hdr_stack_s0[1].data = hdr.eth.dmac[31:16];
        p.msa_hdr_stack_s0[2].data = hdr.eth.dmac[15:0];
        p.msa_hdr_stack_s0[3].data = hdr.eth.smac[47:32];
        p.msa_hdr_stack_s0[4].data = hdr.eth.smac[31:16];
        p.msa_hdr_stack_s0[5].data = hdr.eth.smac[15:0];
        p.msa_hdr_stack_s0[6].data = hdr.eth.ethType;
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

control MPRouter(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm) {
    MPRouter_micro_parser() MPRouter_micro_parser_inst;
    MPRouter_micro_control() MPRouter_micro_control_inst;
    MPRouter_micro_deparser() MPRouter_micro_deparser_inst;
    hdr_t hdr_t_var;
    MPRouter_parser_meta_t MPRouter_parser_meta_t_var;
    apply {
        MPRouter_micro_parser_inst.apply(msa_packet_struct_t_var, hdr_t_var, MPRouter_parser_meta_t_var);
        MPRouter_micro_control_inst.apply(msa_packet_struct_t_var, ig_intr_md_for_dprsr, ig_intr_md_for_tm, hdr_t_var);
        MPRouter_micro_deparser_inst.apply(msa_packet_struct_t_var, hdr_t_var, MPRouter_parser_meta_t_var);
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
    MPRouter() MPRouter_inst;
    apply {
        MPRouter_inst.apply(mpkt, ig_intr_md_for_dprsr, ig_intr_md_for_tm);
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

