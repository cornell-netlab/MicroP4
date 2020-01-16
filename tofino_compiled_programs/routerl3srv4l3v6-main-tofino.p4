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

struct L3SRv4_parser_meta_t {
    bool   ipv4_v;
    bit<1> packet_reject;
}

struct SRv4_parser_meta_t {
    bool   option_v;
    bool   sr_v;
    bit<1> packet_reject;
}

struct SRv4_hdr_vop_t {
}

struct L3SRv4_hdr_vop_t {
}

struct L3v6_parser_meta_t {
    bool   ipv6_v;
    bit<1> packet_reject;
}

struct L3v6_hdr_vop_t {
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

struct sr4_meta_t {
}

struct option_h {
    bit<8> useless;
    bit<8> option_num;
    bit<8> len;
    bit<8> data_pointer;
}

struct sr4_h {
    bit<32> addr1;
    bit<32> addr2;
    bit<32> addr3;
    bit<32> addr4;
    bit<32> addr5;
    bit<32> addr6;
}

struct sr4_hdr_t {
    option_h option;
    sr4_h    sr;
}

control SRv4_micro_parser(inout msa_packet_struct_t p, out sr4_hdr_t hdr, out SRv4_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.option_v = false;
        parser_meta.sr_v = false;
        parser_meta.packet_reject = 1w0b0;
    }
    action micro_parser_reject() {
        parser_meta.packet_reject = 1w0b1;
    }
    action i_272_start_0() {
        parser_meta.option_v = true;
        hdr.option.useless = p.msa_hdr_stack_s0[17].data[15:8];
        hdr.option.option_num = p.msa_hdr_stack_s0[17].data[7:0];
        hdr.option.len = p.msa_hdr_stack_s0[18].data[15:8];
        hdr.option.data_pointer = p.msa_hdr_stack_s0[18].data[7:0];
    }
    action i_272_parse_src_routing_0() {
        parser_meta.sr_v = true;
        hdr.sr.addr1 = p.msa_hdr_stack_s0[19].data ++ p.msa_hdr_stack_s0[20].data;
        hdr.sr.addr2 = p.msa_hdr_stack_s0[21].data ++ p.msa_hdr_stack_s0[22].data;
        hdr.sr.addr3 = p.msa_hdr_stack_s0[23].data ++ p.msa_hdr_stack_s0[24].data;
        hdr.sr.addr4 = p.msa_hdr_stack_s0[25].data ++ p.msa_hdr_stack_s0[26].data;
        hdr.sr.addr5 = p.msa_hdr_stack_s0[27].data ++ p.msa_hdr_stack_s0[28].data;
        hdr.sr.addr6 = p.msa_hdr_stack_s0[29].data ++ p.msa_hdr_stack_s0[30].data;
        parser_meta.option_v = true;
        hdr.option.useless = p.msa_hdr_stack_s0[17].data[15:8];
        hdr.option.option_num = p.msa_hdr_stack_s0[17].data[7:0];
        hdr.option.len = p.msa_hdr_stack_s0[18].data[15:8];
        hdr.option.data_pointer = p.msa_hdr_stack_s0[18].data[7:0];
    }
    action i_272_parse_src_routing_1() {
        parser_meta.sr_v = true;
        hdr.sr.addr1 = p.msa_hdr_stack_s0[19].data ++ p.msa_hdr_stack_s0[20].data;
        hdr.sr.addr2 = p.msa_hdr_stack_s0[21].data ++ p.msa_hdr_stack_s0[22].data;
        hdr.sr.addr3 = p.msa_hdr_stack_s0[23].data ++ p.msa_hdr_stack_s0[24].data;
        hdr.sr.addr4 = p.msa_hdr_stack_s0[25].data ++ p.msa_hdr_stack_s0[26].data;
        hdr.sr.addr5 = p.msa_hdr_stack_s0[27].data ++ p.msa_hdr_stack_s0[28].data;
        hdr.sr.addr6 = p.msa_hdr_stack_s0[29].data ++ p.msa_hdr_stack_s0[30].data;
        parser_meta.option_v = true;
        hdr.option.useless = p.msa_hdr_stack_s0[17].data[15:8];
        hdr.option.option_num = p.msa_hdr_stack_s0[17].data[7:0];
        hdr.option.len = p.msa_hdr_stack_s0[18].data[15:8];
        hdr.option.data_pointer = p.msa_hdr_stack_s0[18].data[7:0];
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset           : exact;
            p.msa_hdr_stack_s0[17].data[7:0]: ternary;
        }
        actions = {
            i_272_start_0();
            i_272_parse_src_routing_0();
            i_272_parse_src_routing_1();
            micro_parser_reject();
            NoAction();
        }
        const entries = {
                        (16w272, 8w0x3) : i_272_parse_src_routing_0();

                        (16w272, 8w0x9) : i_272_parse_src_routing_1();

                        (16w272, default) : micro_parser_reject();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control SRv4_micro_control(inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout sr4_hdr_t hdr, out bit<16> nh) {
    @name(".NoAction") action NoAction_0() {
    }
    @name(".NoAction") action NoAction_3() {
    }
    bit<32> neighbour_0;
    @name("SRv4.micro_control.drop_action") action drop_action() {
        ig_intr_md_for_dprsr.drop_ctl = 3w0x1;
    }
    @name("SRv4.micro_control.set_nexthop") action set_nexthop(bit<32> nextHopAddr) {
        neighbour_0 = nextHopAddr;
    }
    @name("SRv4.micro_control.set_nexthop_addr2") action set_nexthop_addr2() {
        neighbour_0 = hdr.sr.addr2;
    }
    @name("SRv4.micro_control.set_nexthop_addr3") action set_nexthop_addr3() {
        neighbour_0 = hdr.sr.addr3;
    }
    @name("SRv4.micro_control.set_nexthop_addr4") action set_nexthop_addr4() {
        neighbour_0 = hdr.sr.addr4;
    }
    @name("SRv4.micro_control.set_nexthop_addr5") action set_nexthop_addr5() {
        neighbour_0 = hdr.sr.addr5;
    }
    @name("SRv4.micro_control.set_nexthop_addr6") action set_nexthop_addr6() {
        neighbour_0 = hdr.sr.addr6;
    }
    @name("SRv4.micro_control.sr4_tbl") table sr4_tbl_0 {
        key = {
            hdr.option.option_num: exact @name("hdr.option.option_num") ;
            hdr.sr.addr1         : exact @name("hdr.sr.addr1") ;
            hdr.sr.addr2         : exact @name("hdr.sr.addr2") ;
            hdr.sr.addr3         : exact @name("hdr.sr.addr3") ;
            hdr.sr.addr4         : exact @name("hdr.sr.addr4") ;
            hdr.sr.addr5         : exact @name("hdr.sr.addr5") ;
            hdr.sr.addr6         : exact @name("hdr.sr.addr6") ;
        }
        actions = {
            drop_action();
            set_nexthop_addr2();
            set_nexthop_addr3();
            set_nexthop_addr4();
            set_nexthop_addr5();
            set_nexthop_addr6();
            set_nexthop();
            @defaultonly NoAction_0();
        }
        const entries = {
                        (8w0x3, 32w0xa000256, default, default, default, default, default) : set_nexthop_addr2();

                        (8w0x3, default, 32w0xa000256, default, default, default, default) : set_nexthop_addr3();

                        (8w0x3, default, default, 32w0xa000256, default, default, default) : set_nexthop_addr4();

                        (8w0x3, default, default, default, 32w0xa000256, default, default) : set_nexthop_addr5();

                        (8w0x3, default, default, default, default, 32w0xa000256, default) : set_nexthop_addr6();

                        (8w0x3, 32w0xa000256, default, default, default, default, default) : set_nexthop(32w0xa000256);

                        (8w0x3, default, 32w0xa000256, default, default, default, default) : set_nexthop(32w0xa000256);

                        (8w0x3, default, default, 32w0xa000256, default, default, default) : set_nexthop(32w0xa000256);

                        (8w0x3, 32w0xa000256, default, default, default, default, default) : set_nexthop(32w0xa000256);

                        (8w0x3, default, 32w0xa000256, default, default, default, default) : set_nexthop(32w0xa000256);

                        (8w0x3, default, default, 32w0xa000256, default, default, default) : set_nexthop(32w0xa000256);

                        (8w0x9, 32w0xa000256, default, default, default, default, default) : set_nexthop_addr2();

                        (8w0x9, default, 32w0xa000256, default, default, default, default) : set_nexthop_addr3();

                        (8w0x9, default, default, 32w0xa000256, default, default, default) : set_nexthop_addr4();

                        (8w0x9, default, default, default, 32w0xa000256, default, default) : set_nexthop_addr5();

                        (8w0x9, default, default, default, default, 32w0xa000256, default) : set_nexthop_addr6();

                        (8w0x9, default, default, default, default, default, default) : drop_action();

        }

        default_action = NoAction_0();
    }
    @name("SRv4.micro_control.set_out_arg") action set_out_arg(bit<16> n) {
        nh = n;
    }
    @name("SRv4.micro_control.set_out_nh_tbl") table set_out_nh_tbl_0 {
        key = {
            neighbour_0: exact @name("neighbour") ;
        }
        actions = {
            set_out_arg();
            @defaultonly NoAction_3();
        }
        default_action = NoAction_3();
    }
    apply {
        neighbour_0 = 32w0;
        nh = 16w0;
        sr4_tbl_0.apply();
        set_out_nh_tbl_0.apply();
    }
}

control SRv4_micro_deparser(inout msa_packet_struct_t p, in sr4_hdr_t hdr, in SRv4_parser_meta_t parser_meta) {
    action option_34_38() {
    }
    action sr_34_58() {
    }
    action sr_38_62() {
    }
    action option_34_38_sr_38_62() {
        sr_38_62();
        option_34_38();
    }
    table deparser_tbl {
        key = {
            p.indices.curr_offset: exact;
            parser_meta.option_v : exact;
            parser_meta.sr_v     : exact;
        }
        actions = {
            option_34_38();
            sr_34_58();
            sr_38_62();
            option_34_38_sr_38_62();
            NoAction();
        }
        const entries = {
                        (16w272, true, false) : option_34_38();

                        (16w272, false, true) : sr_34_58();

                        (16w272, true, true) : option_34_38_sr_38_62();

        }

        const default_action = NoAction();
    }
    apply {
        deparser_tbl.apply();
    }
}

control SRv4(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, out bit<16> out_param) {
    SRv4_micro_parser() SRv4_micro_parser_inst;
    SRv4_micro_control() SRv4_micro_control_inst;
    SRv4_micro_deparser() SRv4_micro_deparser_inst;
    sr4_hdr_t sr4_hdr_t_var;
    SRv4_parser_meta_t SRv4_parser_meta_t_var;
    apply {
        SRv4_micro_parser_inst.apply(msa_packet_struct_t_var, sr4_hdr_t_var, SRv4_parser_meta_t_var);
        SRv4_micro_control_inst.apply(ig_intr_md_for_dprsr, sr4_hdr_t_var, out_param);
        SRv4_micro_deparser_inst.apply(msa_packet_struct_t_var, sr4_hdr_t_var, SRv4_parser_meta_t_var);
    }
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

control L3SRv4_micro_parser(inout msa_packet_struct_t p, out l3v4_hdr_t hdr, out L3SRv4_parser_meta_t parser_meta) {
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

control L3SRv4_micro_control(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout l3v4_hdr_t hdr, out bit<16> nexthop) {
    @name("L3SRv4.micro_control.srv4") SRv4() srv4_0;
    @name("L3SRv4.micro_control.process") action process(bit<16> nh) {
        hdr.ipv4.ttl = hdr.ipv4.ttl + 8w255;
        nexthop = nh;
    }
    @name("L3SRv4.micro_control.default_act") action default_act() {
        nexthop = 16w0;
    }
    @name("L3SRv4.micro_control.ipv4_lpm_tbl") table ipv4_lpm_tbl_0 {
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
        if (hdr.ipv4.ihl != 4w0x5) 
            srv4_0.apply(msa_packet_struct_t_var, ig_intr_md_for_dprsr, nexthop);
        else 
            ipv4_lpm_tbl_0.apply();
    }
}

control L3SRv4_micro_deparser(inout msa_packet_struct_t p, in l3v4_hdr_t h, in L3SRv4_parser_meta_t parser_meta) {
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

control L3SRv4(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, out bit<16> out_param) {
    L3SRv4_micro_parser() L3SRv4_micro_parser_inst;
    L3SRv4_micro_control() L3SRv4_micro_control_inst;
    L3SRv4_micro_deparser() L3SRv4_micro_deparser_inst;
    l3v4_hdr_t l3v4_hdr_t_var;
    L3SRv4_parser_meta_t L3SRv4_parser_meta_t_var;
    apply {
        L3SRv4_micro_parser_inst.apply(msa_packet_struct_t_var, l3v4_hdr_t_var, L3SRv4_parser_meta_t_var);
        L3SRv4_micro_control_inst.apply(msa_packet_struct_t_var, ig_intr_md_for_dprsr, l3v4_hdr_t_var, out_param);
        L3SRv4_micro_deparser_inst.apply(msa_packet_struct_t_var, l3v4_hdr_t_var, L3SRv4_parser_meta_t_var);
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
    @name("MPRouter.micro_control.l3srv4_i") L3SRv4() l3srv4_i_0;
    @name("MPRouter.micro_control.l3v6_i") L3v6() l3v6_i_0;
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
            l3srv4_i_0.apply(msa_packet_struct_t_var, ig_intr_md_for_dprsr, nh_0);
        else 
            if (hdr.eth.ethType == 16w0x86dd) 
                l3v6_i_0.apply(msa_packet_struct_t_var, nh_0);
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
        pc0.set((bit<8>)31);
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
        pc0.set((bit<8>)31);
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

