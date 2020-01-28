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
    msa_twobytes_h[31] msa_hdr_stack_s0;
}

struct ModularVlan_parser_meta_t {
    bool   eth_v;
    bit<1> packet_reject;
}

struct Vlan_parser_meta_t {
    bool   vlan_v;
    bit<1> packet_reject;
}

struct IPv4_parser_meta_t {
    bool   ipv4_v;
    bit<1> packet_reject;
}

struct IPv4_hdr_vop_t {
}

struct IPv6_parser_meta_t {
    bool   ipv6_v;
    bit<1> packet_reject;
}

struct IPv6_hdr_vop_t {
}

struct L2Vlan_parser_meta_t {
    bit<1> packet_reject;
}

struct VlanID_parser_meta_t {
    bit<1> packet_reject;
}

struct VlanID_hdr_vop_t {
}

struct L2Vlan_hdr_vop_t {
}

struct L3Vlan_parser_meta_t {
    bit<1> packet_reject;
}

struct L3Vlan_hdr_vop_t {
}

struct Vlan_hdr_vop_t {
    bool vlan_sv;
    bool vlan_siv;
}

struct ModularVlan_hdr_vop_t {
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

struct vlan_inout_t {
    bit<48> dstAddr;
    bit<16> invlan;
    bit<16> outvlan;
    bit<16> ethType;
}

struct sr6_inout_t {
    bit<16>  totalLen;
    bit<8>   nexthdr;
    bit<8>   hoplimit;
    bit<128> srcAddr;
    bit<128> dstAddr;
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

struct vlanid_meta_t {
}

struct vlanid_hdr_t {
}

control VlanID_micro_parser(inout msa_packet_struct_t p, out VlanID_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.packet_reject = 1w0b0;
    }
    action i_144_start_0() {
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset: exact;
        }
        actions = {
            i_144_start_0();
            NoAction();
        }
        const entries = {
                        16w144 : i_144_start_0();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control VlanID_micro_control(in ingress_intrinsic_metadata_t ig_intr_md, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout vlan_inout_t vlanInfo) {
    @name(".NoAction") action NoAction_0() {
    }
    @name(".NoAction") action NoAction_3() {
    }
    @name("VlanID.micro_control.set_invlan") action set_invlan(bit<16> tci) {
        vlanInfo.invlan = tci;
    }
    @name("VlanID.micro_control.identify_invlan") table identify_invlan_0 {
        key = {
            ig_intr_md.ingress_port: exact @name("ingress_port") ;
        }
        actions = {
            set_invlan();
            @defaultonly NoAction_0();
        }
        const entries = {
                        9w3 : set_invlan(16w20);

        }

        default_action = NoAction_0();
    }
    @name("VlanID.micro_control.set_outvlan") action set_outvlan(bit<16> tci) {
        vlanInfo.outvlan = tci;
    }
    @name("VlanID.micro_control.identify_outvlan") table identify_outvlan_0 {
        key = {
            ig_intr_md_for_tm.ucast_egress_port: exact @name("egress_port") ;
        }
        actions = {
            set_outvlan();
            @defaultonly NoAction_3();
        }
        const entries = {
                        9w4 : set_outvlan(16w20);

        }

        default_action = NoAction_3();
    }
    apply {
        identify_invlan_0.apply();
        identify_outvlan_0.apply();
    }
}

control VlanID_micro_deparser() {
    apply {
    }
}

control VlanID(inout msa_packet_struct_t msa_packet_struct_t_var, in ingress_intrinsic_metadata_t ig_intr_md, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout vlan_inout_t inout_param) {
    VlanID_micro_parser() VlanID_micro_parser_inst;
    VlanID_micro_control() VlanID_micro_control_inst;
    VlanID_micro_deparser() VlanID_micro_deparser_inst;
    VlanID_parser_meta_t VlanID_parser_meta_t_var;
    apply {
        VlanID_micro_parser_inst.apply(msa_packet_struct_t_var, VlanID_parser_meta_t_var);
        VlanID_micro_control_inst.apply(ig_intr_md, ig_intr_md_for_tm, inout_param);
        VlanID_micro_deparser_inst.apply();
    }
}

struct l2vlan_hdr_t {
}

control L2Vlan_micro_parser(inout msa_packet_struct_t p, out L2Vlan_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.packet_reject = 1w0b0;
    }
    action i_144_start_0() {
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset: exact;
        }
        actions = {
            i_144_start_0();
            NoAction();
        }
        const entries = {
                        16w144 : i_144_start_0();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control L2Vlan_micro_control(inout msa_packet_struct_t msa_packet_struct_t_var, in ingress_intrinsic_metadata_t ig_intr_md, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout vlan_inout_t ethInfo) {
    @name(".NoAction") action NoAction_0() {
    }
    @name("L2Vlan.micro_control.vlanid") VlanID() vlanid_0;
    @name("L2Vlan.micro_control.drop_action") action drop_action() {
        ig_intr_md_for_dprsr.drop_ctl = 3w0x1;
    }
    @name("L2Vlan.micro_control.drop_table") table drop_table_0 {
        key = {
        }
        actions = {
            drop_action();
        }
        default_action = drop_action();
    }
    @name("L2Vlan.micro_control.send_to") action send_to(PortId_t port) {
        ig_intr_md_for_tm.ucast_egress_port = port;
    }
    @name("L2Vlan.micro_control.switch_tbl") table switch_tbl_0 {
        key = {
            ethInfo.dstAddr        : exact @name("ethInfo.dstAddr") ;
            ig_intr_md.ingress_port: ternary @name("ingress_port") ;
        }
        actions = {
            send_to();
            @defaultonly NoAction_0();
        }
        const entries = {
                        (48w0x45090abc103, 9w5) : send_to(9w6);

        }

        default_action = NoAction_0();
    }
    apply {
        switch_tbl_0.apply();
        vlanid_0.apply(msa_packet_struct_t_var, ig_intr_md, ig_intr_md_for_tm, ethInfo);
        if (ethInfo.invlan != ethInfo.outvlan) 
            drop_table_0.apply();
    }
}

control L2Vlan_micro_deparser() {
    apply {
    }
}

control L2Vlan(inout msa_packet_struct_t msa_packet_struct_t_var, in ingress_intrinsic_metadata_t ig_intr_md, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout vlan_inout_t inout_param) {
    L2Vlan_micro_parser() L2Vlan_micro_parser_inst;
    L2Vlan_micro_control() L2Vlan_micro_control_inst;
    L2Vlan_micro_deparser() L2Vlan_micro_deparser_inst;
    L2Vlan_parser_meta_t L2Vlan_parser_meta_t_var;
    apply {
        L2Vlan_micro_parser_inst.apply(msa_packet_struct_t_var, L2Vlan_parser_meta_t_var);
        L2Vlan_micro_control_inst.apply(msa_packet_struct_t_var, ig_intr_md, ig_intr_md_for_dprsr, ig_intr_md_for_tm, inout_param);
        L2Vlan_micro_deparser_inst.apply();
    }
}

struct l3vlan_hdr_t {
}

control L3Vlan_micro_parser(inout msa_packet_struct_t p, out L3Vlan_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.packet_reject = 1w0b0;
    }
    action i_144_start_0() {
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset: exact;
        }
        actions = {
            i_144_start_0();
            NoAction();
        }
        const entries = {
                        16w144 : i_144_start_0();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control L3Vlan_micro_control(inout msa_packet_struct_t msa_packet_struct_t_var, in ingress_intrinsic_metadata_t ig_intr_md, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout vlan_inout_t ethInfo) {
    @name(".NoAction") action NoAction_0() {
    }
    @name(".NoAction") action NoAction_3() {
    }
    bit<1> is_l3_int_0;
    @name("L3Vlan.micro_control.vlanid") VlanID() vlanid_0;
    @name("L3Vlan.micro_control.is_l3") action is_l3() {
        is_l3_int_0 = 1w1;
    }
    @name("L3Vlan.micro_control.check_in_port_lvl") table check_in_port_lvl_0 {
        key = {
            ig_intr_md.ingress_port: exact @name("ingress_port") ;
        }
        actions = {
            is_l3();
            @defaultonly NoAction_0();
        }
        const entries = {
                        9w6 : is_l3();

        }

        default_action = NoAction_0();
    }
    @name("L3Vlan.micro_control.set_ivr") action set_ivr(bit<48> dstAddr) {
        ethInfo.dstAddr = dstAddr;
    }
    @name("L3Vlan.micro_control.set_vlan_ivr") table set_vlan_ivr_0 {
        key = {
            ethInfo.invlan: exact @name("ethInfo.invlan") ;
        }
        actions = {
            set_ivr();
            @defaultonly NoAction_3();
        }
        const entries = {
                        16w3 : set_ivr(48w0x45090abc1a0);

        }

        default_action = NoAction_3();
    }
    apply {
        check_in_port_lvl_0.apply();
        if (is_l3_int_0 == 1w1) 
            vlanid_0.apply(msa_packet_struct_t_var, ig_intr_md, ig_intr_md_for_tm, ethInfo);
        else 
            set_vlan_ivr_0.apply();
    }
}

control L3Vlan_micro_deparser() {
    apply {
    }
}

control L3Vlan(inout msa_packet_struct_t msa_packet_struct_t_var, in ingress_intrinsic_metadata_t ig_intr_md, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout vlan_inout_t inout_param) {
    L3Vlan_micro_parser() L3Vlan_micro_parser_inst;
    L3Vlan_micro_control() L3Vlan_micro_control_inst;
    L3Vlan_micro_deparser() L3Vlan_micro_deparser_inst;
    L3Vlan_parser_meta_t L3Vlan_parser_meta_t_var;
    apply {
        L3Vlan_micro_parser_inst.apply(msa_packet_struct_t_var, L3Vlan_parser_meta_t_var);
        L3Vlan_micro_control_inst.apply(msa_packet_struct_t_var, ig_intr_md, ig_intr_md_for_tm, inout_param);
        L3Vlan_micro_deparser_inst.apply();
    }
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
    action i_144_start_0() {
        parser_meta.ipv4_v = true;
        hdr.ipv4.ihl_version = p.msa_hdr_stack_s0[9].data[15:8];
        hdr.ipv4.diffserv = p.msa_hdr_stack_s0[9].data[7:0];
        hdr.ipv4.totalLen = p.msa_hdr_stack_s0[10].data;
        hdr.ipv4.identification = p.msa_hdr_stack_s0[11].data;
        hdr.ipv4.flags = p.msa_hdr_stack_s0[12].data[15:13];
        hdr.ipv4.fragOffset = p.msa_hdr_stack_s0[12].data[12:0];
        hdr.ipv4.ttl = p.msa_hdr_stack_s0[13].data[15:8];
        hdr.ipv4.protocol = p.msa_hdr_stack_s0[13].data[7:0];
        hdr.ipv4.hdrChecksum = p.msa_hdr_stack_s0[14].data;
        hdr.ipv4.srcAddr = p.msa_hdr_stack_s0[15].data ++ p.msa_hdr_stack_s0[16].data;
        hdr.ipv4.dstAddr = p.msa_hdr_stack_s0[17].data ++ p.msa_hdr_stack_s0[18].data;
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset: exact;
        }
        actions = {
            i_144_start_0();
            NoAction();
        }
        const entries = {
                        16w144 : i_144_start_0();

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
    action ipv4_18_38() {
        p.msa_hdr_stack_s0[13].data = h.ipv4.ttl ++ h.ipv4.protocol;
    }
    table deparser_tbl {
        key = {
            p.indices.curr_offset: exact;
            parser_meta.ipv4_v   : exact;
        }
        actions = {
            ipv4_18_38();
            NoAction();
        }
        const entries = {
                        (16w144, true) : ipv4_18_38();

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

control IPv6_micro_parser(inout msa_packet_struct_t p, out l3v6_hdr_t hdr, out IPv6_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.ipv6_v = false;
        parser_meta.packet_reject = 1w0b0;
    }
    action i_144_start_0() {
        parser_meta.ipv6_v = true;
        hdr.ipv6.version = p.msa_hdr_stack_s0[9].data[15:12];
        hdr.ipv6.class = p.msa_hdr_stack_s0[9].data[11:4];
        hdr.ipv6.label = p.msa_hdr_stack_s0[9].data[3:0] ++ p.msa_hdr_stack_s0[10].data;
        hdr.ipv6.totalLen = p.msa_hdr_stack_s0[11].data;
        hdr.ipv6.nexthdr = p.msa_hdr_stack_s0[12].data[15:8];
        hdr.ipv6.hoplimit = p.msa_hdr_stack_s0[12].data[7:0];
        hdr.ipv6.srcAddr = p.msa_hdr_stack_s0[13].data ++ p.msa_hdr_stack_s0[14].data ++ p.msa_hdr_stack_s0[15].data ++ p.msa_hdr_stack_s0[16].data ++ p.msa_hdr_stack_s0[17].data ++ p.msa_hdr_stack_s0[18].data ++ p.msa_hdr_stack_s0[19].data ++ p.msa_hdr_stack_s0[20].data;
        hdr.ipv6.dstAddr = p.msa_hdr_stack_s0[21].data ++ p.msa_hdr_stack_s0[22].data ++ p.msa_hdr_stack_s0[23].data ++ p.msa_hdr_stack_s0[24].data ++ p.msa_hdr_stack_s0[25].data ++ p.msa_hdr_stack_s0[26].data ++ p.msa_hdr_stack_s0[27].data ++ p.msa_hdr_stack_s0[28].data;
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset: exact;
        }
        actions = {
            i_144_start_0();
            NoAction();
        }
        const entries = {
                        16w144 : i_144_start_0();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control IPv6_micro_control(inout l3v6_hdr_t hdr, out bit<16> nexthop) {
    @name("IPv6.micro_control.process") action process(bit<16> nh) {
        hdr.ipv6.hoplimit = hdr.ipv6.hoplimit + 8w255;
        nexthop = nh;
    }
    @name("IPv6.micro_control.default_act") action default_act() {
        nexthop = 16w0;
    }
    @name("IPv6.micro_control.ipv6_lpm_tbl") table ipv6_lpm_tbl_0 {
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

control IPv6_micro_deparser(inout msa_packet_struct_t p, in l3v6_hdr_t h, in IPv6_parser_meta_t parser_meta) {
    action ipv6_18_58() {
        p.msa_hdr_stack_s0[12].data = h.ipv6.nexthdr ++ h.ipv6.hoplimit;
    }
    table deparser_tbl {
        key = {
            p.indices.curr_offset: exact;
            parser_meta.ipv6_v   : exact;
        }
        actions = {
            ipv6_18_58();
            NoAction();
        }
        const entries = {
                        (16w144, true) : ipv6_18_58();

        }

        const default_action = NoAction();
    }
    apply {
        deparser_tbl.apply();
    }
}

control IPv6(inout msa_packet_struct_t msa_packet_struct_t_var, out bit<16> out_param) {
    IPv6_micro_parser() IPv6_micro_parser_inst;
    IPv6_micro_control() IPv6_micro_control_inst;
    IPv6_micro_deparser() IPv6_micro_deparser_inst;
    l3v6_hdr_t l3v6_hdr_t_var;
    IPv6_parser_meta_t IPv6_parser_meta_t_var;
    apply {
        IPv6_micro_parser_inst.apply(msa_packet_struct_t_var, l3v6_hdr_t_var, IPv6_parser_meta_t_var);
        IPv6_micro_control_inst.apply(l3v6_hdr_t_var, out_param);
        IPv6_micro_deparser_inst.apply(msa_packet_struct_t_var, l3v6_hdr_t_var, IPv6_parser_meta_t_var);
    }
}

struct vlan_meta_t {
    bit<16> ethType;
}

struct vlan_h {
    bit<16> tci;
    bit<16> ethType;
}

struct vlan_hdr_t {
    vlan_h vlan;
}

control Vlan_micro_parser(inout msa_packet_struct_t p, out vlan_hdr_t hdr, inout vlan_meta_t meta, inout vlan_inout_t ethInfo, out Vlan_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.vlan_v = false;
        parser_meta.packet_reject = 1w0b0;
    }
    action micro_parser_reject() {
        parser_meta.packet_reject = 1w0b1;
    }
    action i_112_start_0() {
    }
    action i_112_parse_vlan_0() {
        parser_meta.vlan_v = true;
        hdr.vlan.tci = p.msa_hdr_stack_s0[7].data;
        hdr.vlan.ethType = p.msa_hdr_stack_s0[8].data;
        ethInfo.invlan = hdr.vlan.tci;
        meta.ethType = hdr.vlan.ethType;
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset: exact;
            ethInfo.ethType      : ternary;
        }
        actions = {
            i_112_start_0();
            i_112_parse_vlan_0();
            micro_parser_reject();
            NoAction();
        }
        const entries = {
                        (16w112, 16w0x8100) : i_112_parse_vlan_0();

                        (16w112, default) : micro_parser_reject();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control Vlan_micro_control(inout msa_packet_struct_t msa_packet_struct_t_var, in ingress_intrinsic_metadata_t ig_intr_md, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout vlan_hdr_t hdr, inout vlan_meta_t m, inout vlan_inout_t ethInfo, inout Vlan_hdr_vop_t hdr_vop) {
    @name(".NoAction") action NoAction_0() {
    }
    bit<16> nh_0;
    @name("Vlan.micro_control.l3v4_i") IPv4() l3v4_i_0;
    @name("Vlan.micro_control.l3v6_i") IPv6() l3v6_i_0;
    @name("Vlan.micro_control.l2vlan") L2Vlan() l2vlan_0;
    @name("Vlan.micro_control.l3vlan") L3Vlan() l3vlan_0;
    @name("Vlan.micro_control.drop_action") action drop_action() {
        ig_intr_md_for_dprsr.drop_ctl = 3w0x1;
    }
    @name("Vlan.micro_control.vlan_tag") action vlan_tag(bit<16> tci) {
        hdr_vop.vlan_sv = true;
        hdr_vop.vlan_siv = false;
        hdr.vlan.tci = tci;
        hdr.vlan.ethType = ethInfo.ethType;
        ethInfo.ethType = 16w0x8100;
    }
    @name("Vlan.micro_control.vlan_untag") action vlan_untag() {
        hdr_vop.vlan_sv = false;
        hdr_vop.vlan_siv = true;
        ethInfo.ethType = hdr.vlan.ethType;
    }
    @name("Vlan.micro_control.configure_outvlan") table configure_outvlan_0 {
        key = {
            ig_intr_md_for_tm.ucast_egress_port: exact @name("egress_port") ;
            ig_intr_md.ingress_port            : exact @name("ingress_port") ;
        }
        actions = {
            vlan_tag();
            vlan_untag();
            drop_action();
            @defaultonly NoAction_0();
        }
        const entries = {
                        (9w3, 9w4) : vlan_tag(16w21);

                        (9w4, 9w3) : vlan_untag();

                        (9w3, 9w5) : drop_action();

        }

        default_action = NoAction_0();
    }
    apply {
        nh_0 = 16w0;
        if (m.ethType == 16w0x800) 
            l3v4_i_0.apply(msa_packet_struct_t_var, nh_0);
        else 
            if (m.ethType == 16w0x86dd) 
                l3v6_i_0.apply(msa_packet_struct_t_var, nh_0);
        if (nh_0 == 16w0) 
            l2vlan_0.apply(msa_packet_struct_t_var, ig_intr_md, ig_intr_md_for_dprsr, ig_intr_md_for_tm, ethInfo);
        else 
            l3vlan_0.apply(msa_packet_struct_t_var, ig_intr_md, ig_intr_md_for_tm, ethInfo);
        configure_outvlan_0.apply();
    }
}

control Vlan_micro_deparser(inout msa_packet_struct_t p, in vlan_hdr_t hdr, in Vlan_parser_meta_t parser_meta, in Vlan_hdr_vop_t hdr_vop) {
    action vlan_14_18() {
        p.msa_hdr_stack_s0[7].data = hdr.vlan.tci;
        p.msa_hdr_stack_s0[8].data = hdr.vlan.ethType;
    }
    action move_14_4_44() {
        p.msa_hdr_stack_s0[30].data = p.msa_hdr_stack_s0[28].data;
        p.msa_hdr_stack_s0[29].data = p.msa_hdr_stack_s0[27].data;
        p.msa_hdr_stack_s0[28].data = p.msa_hdr_stack_s0[26].data;
        p.msa_hdr_stack_s0[27].data = p.msa_hdr_stack_s0[25].data;
        p.msa_hdr_stack_s0[26].data = p.msa_hdr_stack_s0[24].data;
        p.msa_hdr_stack_s0[25].data = p.msa_hdr_stack_s0[23].data;
        p.msa_hdr_stack_s0[24].data = p.msa_hdr_stack_s0[22].data;
        p.msa_hdr_stack_s0[23].data = p.msa_hdr_stack_s0[21].data;
        p.msa_hdr_stack_s0[22].data = p.msa_hdr_stack_s0[20].data;
        p.msa_hdr_stack_s0[21].data = p.msa_hdr_stack_s0[19].data;
        p.msa_hdr_stack_s0[20].data = p.msa_hdr_stack_s0[18].data;
        p.msa_hdr_stack_s0[19].data = p.msa_hdr_stack_s0[17].data;
        p.msa_hdr_stack_s0[18].data = p.msa_hdr_stack_s0[16].data;
        p.msa_hdr_stack_s0[17].data = p.msa_hdr_stack_s0[15].data;
        p.msa_hdr_stack_s0[16].data = p.msa_hdr_stack_s0[14].data;
        p.msa_hdr_stack_s0[15].data = p.msa_hdr_stack_s0[13].data;
        p.msa_hdr_stack_s0[14].data = p.msa_hdr_stack_s0[12].data;
        p.msa_hdr_stack_s0[13].data = p.msa_hdr_stack_s0[11].data;
        p.msa_hdr_stack_s0[12].data = p.msa_hdr_stack_s0[10].data;
        p.msa_hdr_stack_s0[11].data = p.msa_hdr_stack_s0[9].data;
        p.msa_hdr_stack_s0[10].data = p.msa_hdr_stack_s0[8].data;
        p.msa_hdr_stack_s0[9].data = p.msa_hdr_stack_s0[7].data;
    }
    action vlan_14_18_MO_Emit_4() {
        move_14_4_44();
        vlan_14_18();
    }
    action vlan_14_18_MO_Emit_mi0() {
        vlan_14_18();
    }
    action MO_Emit_mi0() {
    }
    action move_18_mi4_44() {
        p.msa_hdr_stack_s0[7].data = p.msa_hdr_stack_s0[9].data;
        p.msa_hdr_stack_s0[8].data = p.msa_hdr_stack_s0[10].data;
        p.msa_hdr_stack_s0[9].data = p.msa_hdr_stack_s0[11].data;
        p.msa_hdr_stack_s0[10].data = p.msa_hdr_stack_s0[12].data;
        p.msa_hdr_stack_s0[11].data = p.msa_hdr_stack_s0[13].data;
        p.msa_hdr_stack_s0[12].data = p.msa_hdr_stack_s0[14].data;
        p.msa_hdr_stack_s0[13].data = p.msa_hdr_stack_s0[15].data;
        p.msa_hdr_stack_s0[14].data = p.msa_hdr_stack_s0[16].data;
        p.msa_hdr_stack_s0[15].data = p.msa_hdr_stack_s0[17].data;
        p.msa_hdr_stack_s0[16].data = p.msa_hdr_stack_s0[18].data;
        p.msa_hdr_stack_s0[17].data = p.msa_hdr_stack_s0[19].data;
        p.msa_hdr_stack_s0[18].data = p.msa_hdr_stack_s0[20].data;
        p.msa_hdr_stack_s0[19].data = p.msa_hdr_stack_s0[21].data;
        p.msa_hdr_stack_s0[20].data = p.msa_hdr_stack_s0[22].data;
        p.msa_hdr_stack_s0[21].data = p.msa_hdr_stack_s0[23].data;
        p.msa_hdr_stack_s0[22].data = p.msa_hdr_stack_s0[24].data;
        p.msa_hdr_stack_s0[23].data = p.msa_hdr_stack_s0[25].data;
        p.msa_hdr_stack_s0[24].data = p.msa_hdr_stack_s0[26].data;
        p.msa_hdr_stack_s0[25].data = p.msa_hdr_stack_s0[27].data;
        p.msa_hdr_stack_s0[26].data = p.msa_hdr_stack_s0[28].data;
        p.msa_hdr_stack_s0[27].data = p.msa_hdr_stack_s0[29].data;
        p.msa_hdr_stack_s0[28].data = p.msa_hdr_stack_s0[30].data;
    }
    action MO_Emit_mi4() {
        move_18_mi4_44();
    }
    table deparser_tbl {
        key = {
            p.indices.curr_offset: exact;
            parser_meta.vlan_v   : exact;
            hdr_vop.vlan_sv      : exact;
            hdr_vop.vlan_siv     : exact;
        }
        actions = {
            vlan_14_18();
            move_14_4_44();
            vlan_14_18_MO_Emit_4();
            vlan_14_18_MO_Emit_mi0();
            MO_Emit_mi0();
            move_18_mi4_44();
            MO_Emit_mi4();
            NoAction();
        }
        const entries = {
                        (16w112, false, true, false) : vlan_14_18_MO_Emit_4();

                        (16w112, true, true, false) : vlan_14_18_MO_Emit_mi0();

                        (16w112, false, true, false) : vlan_14_18_MO_Emit_4();

                        (16w112, true, true, false) : vlan_14_18_MO_Emit_mi0();

                        (16w112, false, true, false) : vlan_14_18_MO_Emit_4();

                        (16w112, true, true, false) : vlan_14_18_MO_Emit_mi0();

                        (16w112, false, true, false) : vlan_14_18_MO_Emit_4();

                        (16w112, true, true, false) : vlan_14_18_MO_Emit_mi0();

                        (16w112, false, true, false) : vlan_14_18_MO_Emit_4();

                        (16w112, true, true, false) : vlan_14_18_MO_Emit_mi0();

                        (16w112, false, true, false) : vlan_14_18_MO_Emit_4();

                        (16w112, true, true, false) : vlan_14_18_MO_Emit_mi0();

                        (16w112, false, true, false) : vlan_14_18_MO_Emit_4();

                        (16w112, true, true, false) : vlan_14_18_MO_Emit_mi0();

                        (16w112, false, true, false) : vlan_14_18_MO_Emit_4();

                        (16w112, true, true, false) : vlan_14_18_MO_Emit_mi0();

                        (16w112, false, false, true) : MO_Emit_mi0();

                        (16w112, true, false, true) : MO_Emit_mi4();

                        (16w112, false, false, true) : MO_Emit_mi0();

                        (16w112, true, false, true) : MO_Emit_mi4();

                        (16w112, false, false, true) : MO_Emit_mi0();

                        (16w112, true, false, true) : MO_Emit_mi4();

                        (16w112, false, false, true) : MO_Emit_mi0();

                        (16w112, true, false, true) : MO_Emit_mi4();

                        (16w112, false, false, true) : MO_Emit_mi0();

                        (16w112, true, false, true) : MO_Emit_mi4();

                        (16w112, false, false, true) : MO_Emit_mi0();

                        (16w112, true, false, true) : MO_Emit_mi4();

                        (16w112, false, false, true) : MO_Emit_mi0();

                        (16w112, true, false, true) : MO_Emit_mi4();

                        (16w112, false, false, true) : MO_Emit_mi0();

                        (16w112, true, false, true) : MO_Emit_mi4();

        }

        const default_action = NoAction();
    }
    apply {
        deparser_tbl.apply();
    }
}

control Vlan(inout msa_packet_struct_t msa_packet_struct_t_var, in ingress_intrinsic_metadata_t ig_intr_md, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout vlan_inout_t inout_param) {
    Vlan_micro_parser() Vlan_micro_parser_inst;
    Vlan_micro_control() Vlan_micro_control_inst;
    Vlan_micro_deparser() Vlan_micro_deparser_inst;
    vlan_hdr_t vlan_hdr_t_var;
    vlan_meta_t vlan_meta_t_var;
    Vlan_parser_meta_t Vlan_parser_meta_t_var;
    Vlan_hdr_vop_t Vlan_hdr_vop_t_var;
    apply {
        Vlan_micro_parser_inst.apply(msa_packet_struct_t_var, vlan_hdr_t_var, vlan_meta_t_var, inout_param, Vlan_parser_meta_t_var);
        Vlan_micro_control_inst.apply(msa_packet_struct_t_var, ig_intr_md, ig_intr_md_for_dprsr, ig_intr_md_for_tm, vlan_hdr_t_var, vlan_meta_t_var, inout_param, Vlan_hdr_vop_t_var);
        Vlan_micro_deparser_inst.apply(msa_packet_struct_t_var, vlan_hdr_t_var, Vlan_parser_meta_t_var, Vlan_hdr_vop_t_var);
    }
}

struct meta_t {
    bit<16> ethType;
}

struct ethernet_h {
    bit<48> dmac;
    bit<48> smac;
    bit<16> ethType;
}

struct hdr_t {
    ethernet_h eth;
}

control ModularVlan_micro_parser(inout msa_packet_struct_t p, out hdr_t hdr, inout meta_t m, out ModularVlan_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.eth_v = false;
        parser_meta.packet_reject = 1w0b0;
    }
    action i_0_start_0() {
        parser_meta.eth_v = true;
        hdr.eth.dmac = p.msa_hdr_stack_s0[0].data ++ p.msa_hdr_stack_s0[1].data ++ p.msa_hdr_stack_s0[2].data;
        hdr.eth.smac = p.msa_hdr_stack_s0[3].data ++ p.msa_hdr_stack_s0[4].data ++ p.msa_hdr_stack_s0[5].data;
        hdr.eth.ethType = p.msa_hdr_stack_s0[6].data;
        m.ethType = hdr.eth.ethType;
    }
    apply {
        micro_parser_init();
        i_0_start_0();
    }
}

control ModularVlan_micro_control(inout msa_packet_struct_t msa_packet_struct_t_var, in ingress_intrinsic_metadata_t ig_intr_md, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout hdr_t hdr) {
    @name(".NoAction") action NoAction_0() {
    }
    vlan_inout_t vlaninfo_0;
    bit<16> nh_0;
    @name("ModularVlan.micro_control.vlan") Vlan() vlan_0;
    @name("ModularVlan.micro_control.forward") action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
        hdr.eth.dmac = dmac;
        hdr.eth.smac = smac;
        hdr.eth.ethType = vlaninfo_0.ethType;
        ig_intr_md_for_tm.ucast_egress_port = port;
    }
    @name("ModularVlan.micro_control.forward_tbl") table forward_tbl_0 {
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
        vlaninfo_0.ethType = hdr.eth.ethType;
        vlaninfo_0.dstAddr = hdr.eth.dmac;
        vlan_0.apply(msa_packet_struct_t_var, ig_intr_md, ig_intr_md_for_dprsr, ig_intr_md_for_tm, vlaninfo_0);
        forward_tbl_0.apply();
    }
}

control ModularVlan_micro_deparser(inout msa_packet_struct_t p, in hdr_t hdr, in ModularVlan_parser_meta_t parser_meta) {
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

control ModularVlan(inout msa_packet_struct_t msa_packet_struct_t_var, in ingress_intrinsic_metadata_t ig_intr_md, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm) {
    ModularVlan_micro_parser() ModularVlan_micro_parser_inst;
    ModularVlan_micro_control() ModularVlan_micro_control_inst;
    ModularVlan_micro_deparser() ModularVlan_micro_deparser_inst;
    hdr_t hdr_t_var;
    meta_t meta_t_var;
    ModularVlan_parser_meta_t ModularVlan_parser_meta_t_var;
    apply {
        ModularVlan_micro_parser_inst.apply(msa_packet_struct_t_var, hdr_t_var, meta_t_var, ModularVlan_parser_meta_t_var);
        ModularVlan_micro_control_inst.apply(msa_packet_struct_t_var, ig_intr_md, ig_intr_md_for_dprsr, ig_intr_md_for_tm, hdr_t_var);
        ModularVlan_micro_deparser_inst.apply(msa_packet_struct_t_var, hdr_t_var, ModularVlan_parser_meta_t_var);
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
        pc0.set((bit<8>)29);
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
    ModularVlan() ModularVlan_inst;
    apply {
        ModularVlan_inst.apply(mpkt, ig_intr_md, ig_intr_md_for_dprsr, ig_intr_md_for_tm);
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
        pc0.set((bit<8>)29);
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

