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
    msa_twobytes_h[27] msa_hdr_stack_s0;
}

struct MicroP4Switch_parser_meta_t {
    bool   eth_v;
    bool   vlan_v;
    bit<1> packet_reject;
}

struct L3_parser_meta_t {
    bit<1> packet_reject;
}

struct IPv4NatACL_parser_meta_t {
    bool   ipv4nf_v;
    bool   tcpnf_v;
    bool   udpnf_v;
    bit<1> packet_reject;
}

struct IPv4ACL_parser_meta_t {
    bit<1> packet_reject;
}

struct IPv4ACL_hdr_vop_t {
}

struct IPv4NatACL_hdr_vop_t {
}

struct IPv4_parser_meta_t {
    bool   ipv4_v;
    bit<1> packet_reject;
}

struct IPv4_hdr_vop_t {
}

struct IPv6NatACL_parser_meta_t {
    bool   ipv6nf_v;
    bit<1> packet_reject;
}

struct IPv6ACL_parser_meta_t {
    bit<1> packet_reject;
}

struct IPv6ACL_hdr_vop_t {
}

struct IPv6NatACL_hdr_vop_t {
}

struct IPv6_parser_meta_t {
    bool   ipv6_v;
    bit<1> packet_reject;
}

struct IPv6_hdr_vop_t {
}

struct L3_hdr_vop_t {
}

struct MicroP4Switch_hdr_vop_t {
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

struct no_hdr_t {
}

control IPv4ACL_micro_parser(inout msa_packet_struct_t p, out IPv4ACL_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.packet_reject = 1w0b0;
    }
    action i_336_start_0() {
    }
    action i_432_start_0() {
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset: exact;
        }
        actions = {
            i_336_start_0();
            i_432_start_0();
            NoAction();
        }
        const entries = {
                        16w336 : i_336_start_0();

                        16w432 : i_432_start_0();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control IPv4ACL_micro_control(in ipv4_acl_in_t ia, inout acl_result_t ioa) {
    @name("IPv4ACL.micro_control.set_hard_drop") action set_hard_drop() {
        ioa.hard_drop = 1w1;
        ioa.soft_drop = 1w0;
    }
    @name("IPv4ACL.micro_control.set_soft_drop") action set_soft_drop() {
        ioa.hard_drop = 1w0;
        ioa.soft_drop = 1w1;
    }
    @name("IPv4ACL.micro_control.allow") action allow() {
        ioa.hard_drop = 1w0;
        ioa.soft_drop = 1w0;
    }
    @name("IPv4ACL.micro_control.ipv4_filter") table ipv4_filter_0 {
        key = {
            ia.sa: ternary @name("ia.sa") ;
            ia.da: ternary @name("ia.da") ;
        }
        actions = {
            set_hard_drop();
            set_soft_drop();
            allow();
        }
        default_action = allow();
    }
    apply {
        if (ioa.hard_drop == 1w0) 
            ipv4_filter_0.apply();
    }
}

control IPv4ACL_micro_deparser() {
    apply {
    }
}

control IPv4ACL(inout msa_packet_struct_t msa_packet_struct_t_var, in ipv4_acl_in_t in_param, inout acl_result_t inout_param) {
    IPv4ACL_micro_parser() IPv4ACL_micro_parser_inst;
    IPv4ACL_micro_control() IPv4ACL_micro_control_inst;
    IPv4ACL_micro_deparser() IPv4ACL_micro_deparser_inst;
    IPv4ACL_parser_meta_t IPv4ACL_parser_meta_t_var;
    apply {
        IPv4ACL_micro_parser_inst.apply(msa_packet_struct_t_var, IPv4ACL_parser_meta_t_var);
        IPv4ACL_micro_control_inst.apply(in_param, inout_param);
        IPv4ACL_micro_deparser_inst.apply();
    }
}

struct ipv4_nat_acl_h {
    bit<64> u1;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> checksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

struct tcp_nat_acl_h {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<96> unused;
    bit<16> checksum;
    bit<16> urgentPointer;
}

struct udp_nat_acl_h {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<16> len;
    bit<16> checksum;
}

struct ipv4_nat_acl_hdr_t {
    ipv4_nat_acl_h ipv4nf;
    tcp_nat_acl_h  tcpnf;
    udp_nat_acl_h  udpnf;
}

struct ipv4_nat_acl_meta_t {
    bit<16> sp;
    bit<16> dp;
}

control IPv4NatACL_micro_parser(inout msa_packet_struct_t p, out ipv4_nat_acl_hdr_t hdr, inout ipv4_nat_acl_meta_t meta, out IPv4NatACL_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.ipv4nf_v = false;
        parser_meta.tcpnf_v = false;
        parser_meta.udpnf_v = false;
        parser_meta.packet_reject = 1w0b0;
    }
    action micro_parser_reject() {
        parser_meta.packet_reject = 1w0b1;
    }
    action i_112_start_0() {
        parser_meta.ipv4nf_v = true;
        hdr.ipv4nf.u1 = p.msa_hdr_stack_s0[7].data ++ p.msa_hdr_stack_s0[8].data ++ p.msa_hdr_stack_s0[9].data ++ p.msa_hdr_stack_s0[10].data;
        hdr.ipv4nf.ttl = p.msa_hdr_stack_s0[11].data[15:8];
        hdr.ipv4nf.protocol = p.msa_hdr_stack_s0[11].data[7:0];
        hdr.ipv4nf.checksum = p.msa_hdr_stack_s0[12].data;
        hdr.ipv4nf.srcAddr = p.msa_hdr_stack_s0[13].data ++ p.msa_hdr_stack_s0[14].data;
        hdr.ipv4nf.dstAddr = p.msa_hdr_stack_s0[15].data ++ p.msa_hdr_stack_s0[16].data;
    }
    action i_112_parse_tcp_0() {
        parser_meta.tcpnf_v = true;
        hdr.tcpnf.srcPort = p.msa_hdr_stack_s0[17].data;
        hdr.tcpnf.dstPort = p.msa_hdr_stack_s0[18].data;
        hdr.tcpnf.unused = p.msa_hdr_stack_s0[19].data ++ p.msa_hdr_stack_s0[20].data ++ p.msa_hdr_stack_s0[21].data ++ p.msa_hdr_stack_s0[22].data ++ p.msa_hdr_stack_s0[23].data ++ p.msa_hdr_stack_s0[24].data;
        hdr.tcpnf.checksum = p.msa_hdr_stack_s0[25].data;
        hdr.tcpnf.urgentPointer = p.msa_hdr_stack_s0[26].data;
        meta.sp = hdr.tcpnf.srcPort;
        meta.dp = hdr.tcpnf.dstPort;
        parser_meta.ipv4nf_v = true;
        hdr.ipv4nf.u1 = p.msa_hdr_stack_s0[7].data ++ p.msa_hdr_stack_s0[8].data ++ p.msa_hdr_stack_s0[9].data ++ p.msa_hdr_stack_s0[10].data;
        hdr.ipv4nf.ttl = p.msa_hdr_stack_s0[11].data[15:8];
        hdr.ipv4nf.protocol = p.msa_hdr_stack_s0[11].data[7:0];
        hdr.ipv4nf.checksum = p.msa_hdr_stack_s0[12].data;
        hdr.ipv4nf.srcAddr = p.msa_hdr_stack_s0[13].data ++ p.msa_hdr_stack_s0[14].data;
        hdr.ipv4nf.dstAddr = p.msa_hdr_stack_s0[15].data ++ p.msa_hdr_stack_s0[16].data;
    }
    action i_112_parse_udp_0() {
        parser_meta.udpnf_v = true;
        hdr.udpnf.srcPort = p.msa_hdr_stack_s0[17].data;
        hdr.udpnf.dstPort = p.msa_hdr_stack_s0[18].data;
        hdr.udpnf.len = p.msa_hdr_stack_s0[19].data;
        hdr.udpnf.checksum = p.msa_hdr_stack_s0[20].data;
        meta.sp = hdr.udpnf.srcPort;
        meta.dp = hdr.udpnf.dstPort;
        parser_meta.ipv4nf_v = true;
        hdr.ipv4nf.u1 = p.msa_hdr_stack_s0[7].data ++ p.msa_hdr_stack_s0[8].data ++ p.msa_hdr_stack_s0[9].data ++ p.msa_hdr_stack_s0[10].data;
        hdr.ipv4nf.ttl = p.msa_hdr_stack_s0[11].data[15:8];
        hdr.ipv4nf.protocol = p.msa_hdr_stack_s0[11].data[7:0];
        hdr.ipv4nf.checksum = p.msa_hdr_stack_s0[12].data;
        hdr.ipv4nf.srcAddr = p.msa_hdr_stack_s0[13].data ++ p.msa_hdr_stack_s0[14].data;
        hdr.ipv4nf.dstAddr = p.msa_hdr_stack_s0[15].data ++ p.msa_hdr_stack_s0[16].data;
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset           : exact;
            p.msa_hdr_stack_s0[11].data[7:0]: ternary;
        }
        actions = {
            i_112_start_0();
            i_112_parse_udp_0();
            i_112_parse_tcp_0();
            micro_parser_reject();
            NoAction();
        }
        const entries = {
                        (16w112, 8w0x17) : i_112_parse_udp_0();

                        (16w112, 8w0x6) : i_112_parse_tcp_0();

                        (16w112, default) : micro_parser_reject();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control IPv4NatACL_micro_control(inout msa_packet_struct_t msa_packet_struct_t_var, inout ipv4_nat_acl_hdr_t hdr, inout ipv4_nat_acl_meta_t meta, inout acl_result_t ioa) {
    ipv4_acl_in_t ft_in_0;
    @name("IPv4NatACL.micro_control.acl_i") IPv4ACL() acl_i_0;
    @name("IPv4NatACL.micro_control.set_ipv4_src") action set_ipv4_src(bit<32> is) {
        hdr.ipv4nf.srcAddr = is;
        hdr.ipv4nf.checksum = 16w0x0;
    }
    @name("IPv4NatACL.micro_control.set_ipv4_dst") action set_ipv4_dst(bit<32> id) {
        hdr.ipv4nf.dstAddr = id;
        hdr.ipv4nf.checksum = 16w0x0;
    }
    @name("IPv4NatACL.micro_control.set_tcp_dst_src") action set_tcp_dst_src(bit<16> td, bit<16> ts) {
        hdr.tcpnf.dstPort = td;
        hdr.tcpnf.srcPort = ts;
        hdr.tcpnf.checksum = 16w0x0;
    }
    @name("IPv4NatACL.micro_control.set_tcp_dst") action set_tcp_dst(bit<16> td) {
        hdr.tcpnf.dstPort = td;
        hdr.tcpnf.checksum = 16w0x0;
    }
    @name("IPv4NatACL.micro_control.set_tcp_src") action set_tcp_src(bit<16> ts) {
        hdr.tcpnf.srcPort = ts;
        hdr.tcpnf.checksum = 16w0x0;
    }
    @name("IPv4NatACL.micro_control.set_udp_dst_src") action set_udp_dst_src(bit<16> ud, bit<16> us) {
        hdr.udpnf.dstPort = ud;
        hdr.udpnf.srcPort = us;
        hdr.udpnf.checksum = 16w0x0;
    }
    @name("IPv4NatACL.micro_control.set_udp_dst") action set_udp_dst(bit<16> ud) {
        hdr.udpnf.dstPort = ud;
        hdr.udpnf.checksum = 16w0x0;
    }
    @name("IPv4NatACL.micro_control.set_udp_src") action set_udp_src(bit<16> us) {
        hdr.udpnf.srcPort = us;
        hdr.udpnf.checksum = 16w0x0;
    }
    @name("IPv4NatACL.micro_control.na") action na() {
    }
    @name("IPv4NatACL.micro_control.ipv4_nat") table ipv4_nat_0 {
        key = {
            hdr.ipv4nf.srcAddr : exact @name("hdr.ipv4nf.srcAddr") ;
            hdr.ipv4nf.dstAddr : exact @name("hdr.ipv4nf.dstAddr") ;
            hdr.ipv4nf.protocol: exact @name("hdr.ipv4nf.protocol") ;
            meta.sp            : exact @name("meta.sp") ;
            meta.dp            : exact @name("meta.dp") ;
        }
        actions = {
            set_ipv4_src();
            set_ipv4_dst();
            set_tcp_src();
            set_tcp_dst();
            set_udp_dst();
            set_udp_src();
            set_tcp_dst_src();
            set_udp_dst_src();
            na();
        }
        default_action = na();
    }
    apply {
        ft_in_0.sa = hdr.ipv4nf.srcAddr;
        ipv4_nat_0.apply();
        ft_in_0.da = hdr.ipv4nf.dstAddr;
        acl_i_0.apply(msa_packet_struct_t_var, ft_in_0, ioa);
    }
}

control IPv4NatACL_micro_deparser(inout msa_packet_struct_t p, in ipv4_nat_acl_hdr_t h, in IPv4NatACL_parser_meta_t parser_meta) {
    action ipv4nf_14_34() {
        p.msa_hdr_stack_s0[12].data = h.ipv4nf.checksum;
        p.msa_hdr_stack_s0[13].data = h.ipv4nf.srcAddr[31:16];
        p.msa_hdr_stack_s0[14].data = h.ipv4nf.srcAddr[15:0];
        p.msa_hdr_stack_s0[15].data = h.ipv4nf.dstAddr[31:16];
        p.msa_hdr_stack_s0[16].data = h.ipv4nf.dstAddr[15:0];
    }
    action tcpnf_14_34() {
        p.msa_hdr_stack_s0[7].data = h.tcpnf.srcPort;
        p.msa_hdr_stack_s0[8].data = h.tcpnf.dstPort;
        p.msa_hdr_stack_s0[15].data = h.tcpnf.checksum;
    }
    action tcpnf_34_54() {
        p.msa_hdr_stack_s0[17].data = h.tcpnf.srcPort;
        p.msa_hdr_stack_s0[18].data = h.tcpnf.dstPort;
        p.msa_hdr_stack_s0[25].data = h.tcpnf.checksum;
    }
    action ipv4nf_14_34_tcpnf_34_54() {
        tcpnf_34_54();
        ipv4nf_14_34();
    }
    action udpnf_14_22() {
        p.msa_hdr_stack_s0[7].data = h.udpnf.srcPort;
        p.msa_hdr_stack_s0[8].data = h.udpnf.dstPort;
        p.msa_hdr_stack_s0[10].data = h.udpnf.checksum;
    }
    action udpnf_34_42() {
        p.msa_hdr_stack_s0[17].data = h.udpnf.srcPort;
        p.msa_hdr_stack_s0[18].data = h.udpnf.dstPort;
        p.msa_hdr_stack_s0[20].data = h.udpnf.checksum;
    }
    action ipv4nf_14_34_udpnf_34_42() {
        udpnf_34_42();
        ipv4nf_14_34();
    }
    table deparser_tbl {
        key = {
            p.indices.curr_offset: exact;
            parser_meta.ipv4nf_v : exact;
            parser_meta.tcpnf_v  : exact;
            parser_meta.udpnf_v  : exact;
        }
        actions = {
            ipv4nf_14_34();
            tcpnf_14_34();
            ipv4nf_14_34_tcpnf_34_54();
            udpnf_14_22();
            udpnf_34_42();
            ipv4nf_14_34_udpnf_34_42();
            NoAction();
        }
        const entries = {
                        (16w112, true, false, false) : ipv4nf_14_34();

                        (16w112, false, true, false) : tcpnf_14_34();

                        (16w112, true, true, false) : ipv4nf_14_34_tcpnf_34_54();

                        (16w112, false, false, true) : udpnf_14_22();

                        (16w112, true, false, true) : ipv4nf_14_34_udpnf_34_42();

        }

        const default_action = NoAction();
    }
    apply {
        deparser_tbl.apply();
    }
}

control IPv4NatACL(inout msa_packet_struct_t msa_packet_struct_t_var, inout acl_result_t inout_param) {
    IPv4NatACL_micro_parser() IPv4NatACL_micro_parser_inst;
    IPv4NatACL_micro_control() IPv4NatACL_micro_control_inst;
    IPv4NatACL_micro_deparser() IPv4NatACL_micro_deparser_inst;
    ipv4_nat_acl_hdr_t ipv4_nat_acl_hdr_t_var;
    ipv4_nat_acl_meta_t ipv4_nat_acl_meta_t_var;
    IPv4NatACL_parser_meta_t IPv4NatACL_parser_meta_t_var;
    apply {
        IPv4NatACL_micro_parser_inst.apply(msa_packet_struct_t_var, ipv4_nat_acl_hdr_t_var, ipv4_nat_acl_meta_t_var, IPv4NatACL_parser_meta_t_var);
        IPv4NatACL_micro_control_inst.apply(msa_packet_struct_t_var, ipv4_nat_acl_hdr_t_var, ipv4_nat_acl_meta_t_var, inout_param);
        IPv4NatACL_micro_deparser_inst.apply(msa_packet_struct_t_var, ipv4_nat_acl_hdr_t_var, IPv4NatACL_parser_meta_t_var);
    }
}

control IPv6ACL_micro_parser(inout msa_packet_struct_t p, out IPv6ACL_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.packet_reject = 1w0b0;
    }
    action i_432_start_0() {
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset: exact;
        }
        actions = {
            i_432_start_0();
            NoAction();
        }
        const entries = {
                        16w432 : i_432_start_0();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control IPv6ACL_micro_control(in ipv6_acl_in_t ia, inout acl_result_t ioa) {
    @name("IPv6ACL.micro_control.set_hard_drop") action set_hard_drop() {
        ioa.hard_drop = 1w1;
        ioa.soft_drop = 1w0;
    }
    @name("IPv6ACL.micro_control.set_soft_drop") action set_soft_drop() {
        ioa.hard_drop = 1w0;
        ioa.soft_drop = 1w1;
    }
    @name("IPv6ACL.micro_control.allow") action allow() {
        ioa.hard_drop = 1w0;
        ioa.soft_drop = 1w0;
    }
    @name("IPv6ACL.micro_control.ipv6_filter") table ipv6_filter_0 {
        key = {
            ia.sa: exact @name("ia.sa") ;
            ia.da: exact @name("ia.da") ;
        }
        actions = {
            set_hard_drop();
            set_soft_drop();
            allow();
        }
        default_action = allow();
    }
    apply {
        if (ioa.hard_drop == 1w0) 
            ipv6_filter_0.apply();
    }
}

control IPv6ACL_micro_deparser() {
    apply {
    }
}

control IPv6ACL(inout msa_packet_struct_t msa_packet_struct_t_var, in ipv6_acl_in_t in_param, inout acl_result_t inout_param) {
    IPv6ACL_micro_parser() IPv6ACL_micro_parser_inst;
    IPv6ACL_micro_control() IPv6ACL_micro_control_inst;
    IPv6ACL_micro_deparser() IPv6ACL_micro_deparser_inst;
    IPv6ACL_parser_meta_t IPv6ACL_parser_meta_t_var;
    apply {
        IPv6ACL_micro_parser_inst.apply(msa_packet_struct_t_var, IPv6ACL_parser_meta_t_var);
        IPv6ACL_micro_control_inst.apply(in_param, inout_param);
        IPv6ACL_micro_deparser_inst.apply();
    }
}

struct ipv6_nat_acl_h {
    bit<64>  u1;
    bit<128> srcAddr;
    bit<128> dstAddr;
}

struct ipv6_nat_acl_hdr_t {
    ipv6_nat_acl_h ipv6nf;
}

control IPv6NatACL_micro_parser(inout msa_packet_struct_t p, out ipv6_nat_acl_hdr_t hdr, out IPv6NatACL_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.ipv6nf_v = false;
        parser_meta.packet_reject = 1w0b0;
    }
    action i_112_start_0() {
        parser_meta.ipv6nf_v = true;
        hdr.ipv6nf.u1 = p.msa_hdr_stack_s0[7].data ++ p.msa_hdr_stack_s0[8].data ++ p.msa_hdr_stack_s0[9].data ++ p.msa_hdr_stack_s0[10].data;
        hdr.ipv6nf.srcAddr = p.msa_hdr_stack_s0[11].data ++ p.msa_hdr_stack_s0[12].data ++ p.msa_hdr_stack_s0[13].data ++ p.msa_hdr_stack_s0[14].data ++ p.msa_hdr_stack_s0[15].data ++ p.msa_hdr_stack_s0[16].data ++ p.msa_hdr_stack_s0[17].data ++ p.msa_hdr_stack_s0[18].data;
        hdr.ipv6nf.dstAddr = p.msa_hdr_stack_s0[19].data ++ p.msa_hdr_stack_s0[20].data ++ p.msa_hdr_stack_s0[21].data ++ p.msa_hdr_stack_s0[22].data ++ p.msa_hdr_stack_s0[23].data ++ p.msa_hdr_stack_s0[24].data ++ p.msa_hdr_stack_s0[25].data ++ p.msa_hdr_stack_s0[26].data;
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

control IPv6NatACL_micro_control(inout msa_packet_struct_t msa_packet_struct_t_var, inout ipv6_nat_acl_hdr_t hdr, inout acl_result_t ioa) {
    ipv6_acl_in_t ft_in_0;
    @name("IPv6NatACL.micro_control.acl_i") IPv6ACL() acl_i_0;
    @name("IPv6NatACL.micro_control.set_ipv6_src") action set_ipv6_src(bit<128> is) {
        hdr.ipv6nf.srcAddr = is;
    }
    @name("IPv6NatACL.micro_control.set_ipv6_dst") action set_ipv6_dst(bit<128> id) {
        hdr.ipv6nf.dstAddr = id;
    }
    @name("IPv6NatACL.micro_control.na") action na() {
    }
    @name("IPv6NatACL.micro_control.ipv6_nat") table ipv6_nat_0 {
        key = {
            hdr.ipv6nf.srcAddr: exact @name("hdr.ipv6nf.srcAddr") ;
            hdr.ipv6nf.dstAddr: exact @name("hdr.ipv6nf.dstAddr") ;
        }
        actions = {
            set_ipv6_src();
            set_ipv6_dst();
            na();
        }
        default_action = na();
    }
    apply {
        ft_in_0.sa = hdr.ipv6nf.srcAddr;
        ipv6_nat_0.apply();
        ft_in_0.da = hdr.ipv6nf.dstAddr;
        acl_i_0.apply(msa_packet_struct_t_var, ft_in_0, ioa);
    }
}

control IPv6NatACL_micro_deparser(inout msa_packet_struct_t p, in ipv6_nat_acl_hdr_t h, in IPv6NatACL_parser_meta_t parser_meta) {
    action ipv6nf_14_54() {
        p.msa_hdr_stack_s0[11].data = h.ipv6nf.srcAddr[127:112];
        p.msa_hdr_stack_s0[12].data = h.ipv6nf.srcAddr[111:96];
        p.msa_hdr_stack_s0[13].data = h.ipv6nf.srcAddr[95:80];
        p.msa_hdr_stack_s0[14].data = h.ipv6nf.srcAddr[79:64];
        p.msa_hdr_stack_s0[15].data = h.ipv6nf.srcAddr[63:48];
        p.msa_hdr_stack_s0[16].data = h.ipv6nf.srcAddr[47:32];
        p.msa_hdr_stack_s0[17].data = h.ipv6nf.srcAddr[31:16];
        p.msa_hdr_stack_s0[18].data = h.ipv6nf.srcAddr[15:0];
        p.msa_hdr_stack_s0[19].data = h.ipv6nf.dstAddr[127:112];
        p.msa_hdr_stack_s0[20].data = h.ipv6nf.dstAddr[111:96];
        p.msa_hdr_stack_s0[21].data = h.ipv6nf.dstAddr[95:80];
        p.msa_hdr_stack_s0[22].data = h.ipv6nf.dstAddr[79:64];
        p.msa_hdr_stack_s0[23].data = h.ipv6nf.dstAddr[63:48];
        p.msa_hdr_stack_s0[24].data = h.ipv6nf.dstAddr[47:32];
        p.msa_hdr_stack_s0[25].data = h.ipv6nf.dstAddr[31:16];
        p.msa_hdr_stack_s0[26].data = h.ipv6nf.dstAddr[15:0];
    }
    table deparser_tbl {
        key = {
            p.indices.curr_offset: exact;
            parser_meta.ipv6nf_v : exact;
        }
        actions = {
            ipv6nf_14_54();
            NoAction();
        }
        const entries = {
                        (16w112, true) : ipv6nf_14_54();

        }

        const default_action = NoAction();
    }
    apply {
        deparser_tbl.apply();
    }
}

control IPv6NatACL(inout msa_packet_struct_t msa_packet_struct_t_var, inout acl_result_t inout_param) {
    IPv6NatACL_micro_parser() IPv6NatACL_micro_parser_inst;
    IPv6NatACL_micro_control() IPv6NatACL_micro_control_inst;
    IPv6NatACL_micro_deparser() IPv6NatACL_micro_deparser_inst;
    ipv6_nat_acl_hdr_t ipv6_nat_acl_hdr_t_var;
    IPv6NatACL_parser_meta_t IPv6NatACL_parser_meta_t_var;
    apply {
        IPv6NatACL_micro_parser_inst.apply(msa_packet_struct_t_var, ipv6_nat_acl_hdr_t_var, IPv6NatACL_parser_meta_t_var);
        IPv6NatACL_micro_control_inst.apply(msa_packet_struct_t_var, ipv6_nat_acl_hdr_t_var, inout_param);
        IPv6NatACL_micro_deparser_inst.apply(msa_packet_struct_t_var, ipv6_nat_acl_hdr_t_var, IPv6NatACL_parser_meta_t_var);
    }
}

struct l3_hdr_t {
}

control L3_micro_parser(inout msa_packet_struct_t p, inout l3_inout_t ioa, out L3_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.packet_reject = 1w0b0;
    }
    action micro_parser_reject() {
        parser_meta.packet_reject = 1w0b1;
    }
    action i_112_start_0() {
    }
    table parser_tbl {
        key = {
            p.indices.curr_offset: exact;
            ioa.eth_type         : ternary;
        }
        actions = {
            i_112_start_0();
            micro_parser_reject();
            NoAction();
        }
        const entries = {
                        (16w112, default) : micro_parser_reject();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control L3_micro_control(inout msa_packet_struct_t msa_packet_struct_t_var, inout l3_inout_t ioa) {
    @name("L3.micro_control.ipv4_i") IPv4() ipv4_i_0;
    @name("L3.micro_control.ipv4_nat_acl_i") IPv4NatACL() ipv4_nat_acl_i_0;
    @name("L3.micro_control.ipv6_i") IPv6() ipv6_i_0;
    @name("L3.micro_control.ipv6_nat_acl_i") IPv6NatACL() ipv6_nat_acl_i_0;
    apply {
        if (ioa.eth_type == 16w0x800) {
            ipv4_nat_acl_i_0.apply(msa_packet_struct_t_var, ioa.acl);
            ipv4_i_0.apply(msa_packet_struct_t_var, ioa.next_hop);
        }
        else 
            if (ioa.eth_type == 16w0x86dd) {
                ipv6_nat_acl_i_0.apply(msa_packet_struct_t_var, ioa.acl);
                ipv6_i_0.apply(msa_packet_struct_t_var, ioa.next_hop);
            }
    }
}

control L3_micro_deparser() {
    apply {
    }
}

control L3(inout msa_packet_struct_t msa_packet_struct_t_var, inout l3_inout_t inout_param) {
    L3_micro_parser() L3_micro_parser_inst;
    L3_micro_control() L3_micro_control_inst;
    L3_micro_deparser() L3_micro_deparser_inst;
    L3_parser_meta_t L3_parser_meta_t_var;
    apply {
        L3_micro_parser_inst.apply(msa_packet_struct_t_var, inout_param, L3_parser_meta_t_var);
        L3_micro_control_inst.apply(msa_packet_struct_t_var, inout_param);
        L3_micro_deparser_inst.apply();
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

struct vlan_h {
    bit<16> tci;
    bit<16> ethType;
}

struct hdr_t {
    ethernet_h eth;
    vlan_h     vlan;
}

control MicroP4Switch_micro_parser(inout msa_packet_struct_t p, out hdr_t hdr, out MicroP4Switch_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.eth_v = false;
        parser_meta.vlan_v = false;
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

control MicroP4Switch_micro_control(inout msa_packet_struct_t msa_packet_struct_t_var, in ingress_intrinsic_metadata_t ig_intr_md, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout hdr_t hdr, inout meta_t m) {
    @name(".NoAction") action NoAction_0() {
    }
    @name(".NoAction") action NoAction_3() {
    }
    l3_inout_t l3ioa_0;
    @name("MicroP4Switch.micro_control.l3_i") L3() l3_i_0;
    @name("MicroP4Switch.micro_control.forward") action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
        hdr.eth.dmac = dmac;
        hdr.eth.smac = smac;
        ig_intr_md_for_tm.ucast_egress_port = port;
    }
    @name("MicroP4Switch.micro_control.forward_tbl") table forward_tbl_0 {
        key = {
            l3ioa_0.next_hop: exact @name("l3ioa.next_hop") ;
        }
        actions = {
            forward();
            @defaultonly NoAction_0();
        }
        default_action = NoAction_0();
    }
    @name("MicroP4Switch.micro_control.send_to") action send_to(PortId_t port) {
        ig_intr_md_for_tm.ucast_egress_port = port;
    }
    @name("MicroP4Switch.micro_control.switch_tbl") table switch_tbl_0 {
        key = {
            hdr.eth.dmac           : exact @name("hdr.eth.dmac") ;
            ig_intr_md.ingress_port: ternary @name("ingress_port") ;
        }
        actions = {
            send_to();
            @defaultonly NoAction_3();
        }
        default_action = NoAction_3();
    }
    apply {
        l3ioa_0.next_hop = 16w0;
        l3ioa_0.eth_type = m.ethType;
        l3ioa_0.acl.hard_drop = 1w0;
        l3ioa_0.acl.soft_drop = 1w0;
        if (l3ioa_0.eth_type == 16w0x800) {
            l3_i_0.apply(msa_packet_struct_t_var, l3ioa_0);
            if (l3ioa_0.acl.hard_drop == 1w0 && l3ioa_0.acl.soft_drop == 1w0) 
                forward_tbl_0.apply();
            else 
                if (l3ioa_0.next_hop == 16w0) 
                    switch_tbl_0.apply();
                else 
                    ig_intr_md_for_dprsr.drop_ctl = 3w0x1;
        }
    }
}

control MicroP4Switch_micro_deparser(inout msa_packet_struct_t p, in hdr_t hdr, in MicroP4Switch_parser_meta_t parser_meta) {
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
            parser_meta.eth_v : exact;
            parser_meta.vlan_v: exact;
        }
        actions = {
            eth_0_14();
            NoAction();
        }
        const entries = {
                        (true, false) : eth_0_14();

        }

        const default_action = NoAction();
    }
    apply {
        deparser_tbl.apply();
    }
}

control MicroP4Switch(inout msa_packet_struct_t msa_packet_struct_t_var, in ingress_intrinsic_metadata_t ig_intr_md, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm) {
    MicroP4Switch_micro_parser() MicroP4Switch_micro_parser_inst;
    MicroP4Switch_micro_control() MicroP4Switch_micro_control_inst;
    MicroP4Switch_micro_deparser() MicroP4Switch_micro_deparser_inst;
    hdr_t hdr_t_var;
    meta_t meta_t_var;
    MicroP4Switch_parser_meta_t MicroP4Switch_parser_meta_t_var;
    apply {
        MicroP4Switch_micro_parser_inst.apply(msa_packet_struct_t_var, hdr_t_var, MicroP4Switch_parser_meta_t_var);
        MicroP4Switch_micro_control_inst.apply(msa_packet_struct_t_var, ig_intr_md, ig_intr_md_for_dprsr, ig_intr_md_for_tm, hdr_t_var, meta_t_var);
        MicroP4Switch_micro_deparser_inst.apply(msa_packet_struct_t_var, hdr_t_var, MicroP4Switch_parser_meta_t_var);
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
    MicroP4Switch() MicroP4Switch_inst;
    apply {
        MicroP4Switch_inst.apply(mpkt, ig_intr_md, ig_intr_md_for_dprsr, ig_intr_md_for_tm);
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

