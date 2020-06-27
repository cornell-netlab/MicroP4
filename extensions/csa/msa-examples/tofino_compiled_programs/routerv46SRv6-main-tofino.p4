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
    msa_twobytes_h[15] msa_hdr_stack_s1;
}

struct RouterV46SRv6_parser_meta_t {
    bool   eth_v;
    bit<1> packet_reject;
}

struct IPv4_parser_meta_t {
    bool   ipv4_v;
    bit<1> packet_reject;
}

struct IPv4_hdr_vop_t {
}

struct SR_v6_Simple_parser_meta_t {
    bool   ipv6_v;
    bool   routing_ext0_v;
    bool   sr6_v;
    bool   seg1_v;
    bool   seg2_v;
    bit<1> packet_reject;
}

struct SR_v6_Simple_hdr_vop_t {
}

struct IPv6_parser_meta_t {
    bool   ipv6_v;
    bit<1> packet_reject;
}

struct IPv6_hdr_vop_t {
}

struct RouterV46SRv6_hdr_vop_t {
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
        p.msa_hdr_stack_s0[19].data = h.ipv6.dstAddr[127:112];
        p.msa_hdr_stack_s0[20].data = h.ipv6.dstAddr[111:96];
        p.msa_hdr_stack_s0[21].data = h.ipv6.dstAddr[95:80];
        p.msa_hdr_stack_s0[22].data = h.ipv6.dstAddr[79:64];
        p.msa_hdr_stack_s0[23].data = h.ipv6.dstAddr[63:48];
        p.msa_hdr_stack_s0[24].data = h.ipv6.dstAddr[47:32];
        p.msa_hdr_stack_s0[25].data = h.ipv6.dstAddr[31:16];
        p.msa_hdr_stack_s0[26].data = h.ipv6.dstAddr[15:0];
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

struct vxlan_inout_t {
    bit<48> dmac;
    bit<48> smac;
    bit<16> ethType;
}

struct vlan_inout_t {
    bit<48> dstAddr;
    bit<16> invlan;
    bit<16> outvlan;
    bit<16> ethType;
}

struct routing_ext_h {
    bit<8> nexthdr;
    bit<8> hdr_ext_len;
    bit<8> routing_type;
}

struct sr6_h {
    bit<8>  seg_left;
    bit<8>  last_entry;
    bit<8>  flags;
    bit<16> tag;
}

struct seg1_h {
    bit<128> seg;
}

struct seg2_h {
    bit<128> seg;
}

struct seg3_h {
    bit<128> seg;
}

struct seg4_h {
    bit<128> seg;
}

struct sr6_simple_hdr_t {
    ipv6_h        ipv6;
    routing_ext_h routing_ext0;
    sr6_h         sr6;
    seg1_h        seg1;
    seg2_h        seg2;
}

control SR_v6_Simple_micro_parser(inout msa_packet_struct_t p, out sr6_simple_hdr_t hdr, out SR_v6_Simple_parser_meta_t parser_meta) {
    action micro_parser_init() {
        parser_meta.ipv6_v = false;
        parser_meta.routing_ext0_v = false;
        parser_meta.sr6_v = false;
        parser_meta.seg1_v = false;
        parser_meta.seg2_v = false;
        parser_meta.packet_reject = 1w0b0;
    }
    action micro_parser_reject() {
        parser_meta.packet_reject = 1w0b1;
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
    action i_112_parse_routing_ext_0() {
        parser_meta.routing_ext0_v = true;
        hdr.routing_ext0.nexthdr = p.msa_hdr_stack_s0[27].data[15:8];
        hdr.routing_ext0.hdr_ext_len = p.msa_hdr_stack_s0[27].data[7:0];
        hdr.routing_ext0.routing_type = p.msa_hdr_stack_s0[28].data[15:8];
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
    action i_112_check_seg_routing_0() {
        parser_meta.routing_ext0_v = true;
        hdr.routing_ext0.nexthdr = p.msa_hdr_stack_s0[27].data[15:8];
        hdr.routing_ext0.hdr_ext_len = p.msa_hdr_stack_s0[27].data[7:0];
        hdr.routing_ext0.routing_type = p.msa_hdr_stack_s0[28].data[15:8];
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
    action i_112_parse_seg_routing_0() {
        parser_meta.sr6_v = true;
        hdr.sr6.seg_left = p.msa_hdr_stack_s0[28].data[7:0];
        hdr.sr6.last_entry = p.msa_hdr_stack_s0[29].data[15:8];
        hdr.sr6.flags = p.msa_hdr_stack_s0[29].data[7:0];
        hdr.sr6.tag = p.msa_hdr_stack_s0[30].data;
        parser_meta.routing_ext0_v = true;
        hdr.routing_ext0.nexthdr = p.msa_hdr_stack_s0[27].data[15:8];
        hdr.routing_ext0.hdr_ext_len = p.msa_hdr_stack_s0[27].data[7:0];
        hdr.routing_ext0.routing_type = p.msa_hdr_stack_s0[28].data[15:8];
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
    action i_112_parse_seg2_0() {
        parser_meta.seg1_v = true;
        hdr.seg1.seg = p.msa_hdr_stack_s0[31].data ++ p.msa_hdr_stack_s1[0].data ++ p.msa_hdr_stack_s1[1].data ++ p.msa_hdr_stack_s1[2].data ++ p.msa_hdr_stack_s1[3].data ++ p.msa_hdr_stack_s1[4].data ++ p.msa_hdr_stack_s1[5].data ++ p.msa_hdr_stack_s1[6].data;
        parser_meta.seg2_v = true;
        hdr.seg2.seg = p.msa_hdr_stack_s1[7].data ++ p.msa_hdr_stack_s1[8].data ++ p.msa_hdr_stack_s1[9].data ++ p.msa_hdr_stack_s1[10].data ++ p.msa_hdr_stack_s1[11].data ++ p.msa_hdr_stack_s1[12].data ++ p.msa_hdr_stack_s1[13].data ++ p.msa_hdr_stack_s1[14].data;
        parser_meta.sr6_v = true;
        hdr.sr6.seg_left = p.msa_hdr_stack_s0[28].data[7:0];
        hdr.sr6.last_entry = p.msa_hdr_stack_s0[29].data[15:8];
        hdr.sr6.flags = p.msa_hdr_stack_s0[29].data[7:0];
        hdr.sr6.tag = p.msa_hdr_stack_s0[30].data;
        parser_meta.routing_ext0_v = true;
        hdr.routing_ext0.nexthdr = p.msa_hdr_stack_s0[27].data[15:8];
        hdr.routing_ext0.hdr_ext_len = p.msa_hdr_stack_s0[27].data[7:0];
        hdr.routing_ext0.routing_type = p.msa_hdr_stack_s0[28].data[15:8];
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
    action i_112_parse_seg1_0() {
        parser_meta.seg1_v = true;
        hdr.seg1.seg = p.msa_hdr_stack_s0[31].data ++ p.msa_hdr_stack_s1[0].data ++ p.msa_hdr_stack_s1[1].data ++ p.msa_hdr_stack_s1[2].data ++ p.msa_hdr_stack_s1[3].data ++ p.msa_hdr_stack_s1[4].data ++ p.msa_hdr_stack_s1[5].data ++ p.msa_hdr_stack_s1[6].data;
        parser_meta.sr6_v = true;
        hdr.sr6.seg_left = p.msa_hdr_stack_s0[28].data[7:0];
        hdr.sr6.last_entry = p.msa_hdr_stack_s0[29].data[15:8];
        hdr.sr6.flags = p.msa_hdr_stack_s0[29].data[7:0];
        hdr.sr6.tag = p.msa_hdr_stack_s0[30].data;
        parser_meta.routing_ext0_v = true;
        hdr.routing_ext0.nexthdr = p.msa_hdr_stack_s0[27].data[15:8];
        hdr.routing_ext0.hdr_ext_len = p.msa_hdr_stack_s0[27].data[7:0];
        hdr.routing_ext0.routing_type = p.msa_hdr_stack_s0[28].data[15:8];
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
            p.indices.curr_offset            : exact;
            p.msa_hdr_stack_s0[10].data[15:8]: ternary;
            p.msa_hdr_stack_s0[28].data[15:8]: ternary;
            hdr.ipv6.dstAddr                 : ternary;
            p.msa_hdr_stack_s0[28].data[7:0] : ternary;
        }
        actions = {
            i_112_start_0();
            i_112_parse_routing_ext_0();
            micro_parser_reject();
            i_112_check_seg_routing_0();
            i_112_parse_seg_routing_0();
            i_112_parse_seg1_0();
            i_112_parse_seg2_0();
            NoAction();
        }
        const entries = {
                        (16w112, 8w43, 8w4, 128w0x20010a0b0c025660a0b0f5670dbbfe01, 8w1) : i_112_parse_seg1_0();

                        (16w112, 8w43, 8w4, 128w0x20010a0b0c025660a0b0f5670dbbfe01, 8w2) : i_112_parse_seg2_0();

                        (16w112, 8w43, 8w4, 128w0x20010a0b0c025660a0b0f5670dbbfe01, default) : micro_parser_reject();

                        (16w112, 8w43, 8w4, default, default) : micro_parser_reject();

                        (16w112, 8w43, default, default, default) : micro_parser_reject();

                        (16w112, default, default, default, default) : micro_parser_reject();

        }

        const default_action = NoAction();
    }
    apply {
        micro_parser_init();
        parser_tbl.apply();
    }
}

control SR_v6_Simple_micro_control(inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout sr6_simple_hdr_t hdr) {
    @name(".NoAction") action NoAction_0() {
    }
    @name("SR_v6_Simple.micro_control.drop_action") action drop_action() {
        ig_intr_md_for_dprsr.drop_ctl = 3w0x1;
    }
    @name("SR_v6_Simple.micro_control.copy_frm_first_seg") action copy_frm_first_seg() {
        hdr.ipv6.dstAddr = hdr.seg1.seg;
        hdr.sr6.seg_left = hdr.sr6.seg_left + 8w255;
    }
    @name("SR_v6_Simple.micro_control.copy_frm_second_seg") action copy_frm_second_seg() {
        hdr.ipv6.dstAddr = hdr.seg2.seg;
        hdr.sr6.seg_left = hdr.sr6.seg_left + 8w255;
    }
    @name("SR_v6_Simple.micro_control.srv6_table") table srv6_table_0 {
        key = {
            hdr.routing_ext0.routing_type: exact @name("hdr.routing_ext0.routing_type") ;
            hdr.sr6.last_entry           : ternary @name("hdr.sr6.last_entry") ;
            hdr.sr6.seg_left             : ternary @name("hdr.sr6.seg_left") ;
        }
        actions = {
            drop_action();
            copy_frm_first_seg();
            copy_frm_second_seg();
            @defaultonly NoAction_0();
        }
        default_action = NoAction_0();
    }
    apply {
        srv6_table_0.apply();
    }
}

control SR_v6_Simple_micro_deparser(inout msa_packet_struct_t p, in sr6_simple_hdr_t hdr, in SR_v6_Simple_parser_meta_t parser_meta) {
    action ipv6_14_54() {
        p.msa_hdr_stack_s0[10].data = hdr.ipv6.nexthdr ++ hdr.ipv6.hoplimit;
        p.msa_hdr_stack_s0[19].data = hdr.ipv6.dstAddr[127:112];
        p.msa_hdr_stack_s0[20].data = hdr.ipv6.dstAddr[111:96];
        p.msa_hdr_stack_s0[21].data = hdr.ipv6.dstAddr[95:80];
        p.msa_hdr_stack_s0[22].data = hdr.ipv6.dstAddr[79:64];
        p.msa_hdr_stack_s0[23].data = hdr.ipv6.dstAddr[63:48];
        p.msa_hdr_stack_s0[24].data = hdr.ipv6.dstAddr[47:32];
        p.msa_hdr_stack_s0[25].data = hdr.ipv6.dstAddr[31:16];
        p.msa_hdr_stack_s0[26].data = hdr.ipv6.dstAddr[15:0];
    }
    action routing_ext0_14_17() {
    }
    action routing_ext0_54_57() {
    }
    action ipv6_14_54_routing_ext0_54_57() {
        routing_ext0_54_57();
        ipv6_14_54();
    }
    action sr6_14_19() {
        p.msa_hdr_stack_s0[7].data = hdr.sr6.seg_left ++ hdr.sr6.last_entry;
    }
    action sr6_54_59() {
        p.msa_hdr_stack_s0[27].data = hdr.sr6.seg_left ++ hdr.sr6.last_entry;
    }
    action ipv6_14_54_sr6_54_59() {
        sr6_54_59();
        ipv6_14_54();
    }
    action sr6_17_22() {
        p.msa_hdr_stack_s0[8].data = hdr.sr6.last_entry ++ hdr.sr6.seg_left;
    }
    action routing_ext0_14_17_sr6_17_22() {
        sr6_17_22();
        routing_ext0_14_17();
    }
    action sr6_57_62() {
        p.msa_hdr_stack_s0[28].data = hdr.sr6.last_entry ++ hdr.sr6.seg_left;
    }
    action ipv6_14_54_routing_ext0_54_57_sr6_57_62() {
        sr6_57_62();
        ipv6_14_54_routing_ext0_54_57();
    }
    action seg1_14_30() {
    }
    action seg1_54_70() {
    }
    action ipv6_14_54_seg1_54_70() {
        seg1_54_70();
        ipv6_14_54();
    }
    action seg1_17_33() {
    }
    action routing_ext0_14_17_seg1_17_33() {
        seg1_17_33();
        routing_ext0_14_17();
    }
    action seg1_57_73() {
    }
    action ipv6_14_54_routing_ext0_54_57_seg1_57_73() {
        seg1_57_73();
        ipv6_14_54_routing_ext0_54_57();
    }
    action seg1_19_35() {
    }
    action sr6_14_19_seg1_19_35() {
        seg1_19_35();
        sr6_14_19();
    }
    action seg1_59_75() {
    }
    action ipv6_14_54_sr6_54_59_seg1_59_75() {
        seg1_59_75();
        ipv6_14_54_sr6_54_59();
    }
    action seg1_22_38() {
    }
    action routing_ext0_14_17_sr6_17_22_seg1_22_38() {
        seg1_22_38();
        routing_ext0_14_17_sr6_17_22();
    }
    action seg1_62_78() {
    }
    action ipv6_14_54_routing_ext0_54_57_sr6_57_62_seg1_62_78() {
        seg1_62_78();
        ipv6_14_54_routing_ext0_54_57_sr6_57_62();
    }
    table deparser_tbl {
        key = {
            p.indices.curr_offset     : exact;
            parser_meta.ipv6_v        : exact;
            parser_meta.routing_ext0_v: exact;
            parser_meta.sr6_v         : exact;
            parser_meta.seg1_v        : exact;
        }
        actions = {
            ipv6_14_54();
            routing_ext0_14_17();
            ipv6_14_54_routing_ext0_54_57();
            sr6_14_19();
            ipv6_14_54_sr6_54_59();
            routing_ext0_14_17_sr6_17_22();
            ipv6_14_54_routing_ext0_54_57_sr6_57_62();
            seg1_14_30();
            seg1_54_70();
            ipv6_14_54_seg1_54_70();
            seg1_17_33();
            routing_ext0_14_17_seg1_17_33();
            seg1_57_73();
            ipv6_14_54_routing_ext0_54_57_seg1_57_73();
            seg1_19_35();
            sr6_14_19_seg1_19_35();
            seg1_59_75();
            ipv6_14_54_sr6_54_59_seg1_59_75();
            seg1_22_38();
            routing_ext0_14_17_sr6_17_22_seg1_22_38();
            seg1_62_78();
            ipv6_14_54_routing_ext0_54_57_sr6_57_62_seg1_62_78();
            NoAction();
        }
        const entries = {
                        (16w112, true, false, false, false) : ipv6_14_54();

                        (16w112, false, true, false, false) : routing_ext0_14_17();

                        (16w112, true, true, false, false) : ipv6_14_54_routing_ext0_54_57();

                        (16w112, false, false, true, false) : sr6_14_19();

                        (16w112, true, false, true, false) : ipv6_14_54_sr6_54_59();

                        (16w112, false, true, true, false) : routing_ext0_14_17_sr6_17_22();

                        (16w112, true, true, true, false) : ipv6_14_54_routing_ext0_54_57_sr6_57_62();

                        (16w112, false, false, false, true) : seg1_14_30();

                        (16w112, true, false, false, true) : ipv6_14_54_seg1_54_70();

                        (16w112, false, true, false, true) : routing_ext0_14_17_seg1_17_33();

                        (16w112, true, true, false, true) : ipv6_14_54_routing_ext0_54_57_seg1_57_73();

                        (16w112, false, false, true, true) : sr6_14_19_seg1_19_35();

                        (16w112, true, false, true, true) : ipv6_14_54_sr6_54_59_seg1_59_75();

                        (16w112, false, true, true, true) : routing_ext0_14_17_sr6_17_22_seg1_22_38();

                        (16w112, true, true, true, true) : ipv6_14_54_routing_ext0_54_57_sr6_57_62_seg1_62_78();

        }

        const default_action = NoAction();
    }
    apply {
        deparser_tbl.apply();
    }
}

control SR_v6_Simple(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr) {
    SR_v6_Simple_micro_parser() SR_v6_Simple_micro_parser_inst;
    SR_v6_Simple_micro_control() SR_v6_Simple_micro_control_inst;
    SR_v6_Simple_micro_deparser() SR_v6_Simple_micro_deparser_inst;
    sr6_simple_hdr_t sr6_simple_hdr_t_var;
    SR_v6_Simple_parser_meta_t SR_v6_Simple_parser_meta_t_var;
    apply {
        SR_v6_Simple_micro_parser_inst.apply(msa_packet_struct_t_var, sr6_simple_hdr_t_var, SR_v6_Simple_parser_meta_t_var);
        SR_v6_Simple_micro_control_inst.apply(ig_intr_md_for_dprsr, sr6_simple_hdr_t_var);
        SR_v6_Simple_micro_deparser_inst.apply(msa_packet_struct_t_var, sr6_simple_hdr_t_var, SR_v6_Simple_parser_meta_t_var);
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

struct hdr_t {
    ethernet_h eth;
}

control RouterV46SRv6_micro_parser(inout msa_packet_struct_t p, out hdr_t hdr, out RouterV46SRv6_parser_meta_t parser_meta) {
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

control RouterV46SRv6_micro_control(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm, inout hdr_t hdr) {
    @name(".NoAction") action NoAction_0() {
    }
    bit<16> nh_0;
    @name("RouterV46SRv6.micro_control.ipv4_i") IPv4() ipv4_i_0;
    @name("RouterV46SRv6.micro_control.ipv6_i") IPv6() ipv6_i_0;
    @name("RouterV46SRv6.micro_control.sr_v6_simple_i") SR_v6_Simple() sr_v6_simple_i_0;
    @name("RouterV46SRv6.micro_control.forward") action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
        hdr.eth.dmac = dmac;
        hdr.eth.smac = smac;
        ig_intr_md_for_tm.ucast_egress_port = port;
    }
    @name("RouterV46SRv6.micro_control.forward_tbl") table forward_tbl_0 {
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
            ipv4_i_0.apply(msa_packet_struct_t_var, nh_0);
        else 
            if (hdr.eth.ethType == 16w0x86dd) {
                sr_v6_simple_i_0.apply(msa_packet_struct_t_var, ig_intr_md_for_dprsr);
                ipv6_i_0.apply(msa_packet_struct_t_var, nh_0);
            }
        forward_tbl_0.apply();
    }
}

control RouterV46SRv6_micro_deparser(inout msa_packet_struct_t p, in hdr_t hdr, in RouterV46SRv6_parser_meta_t parser_meta) {
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

control RouterV46SRv6(inout msa_packet_struct_t msa_packet_struct_t_var, inout ingress_intrinsic_metadata_for_deparser_t ig_intr_md_for_dprsr, inout ingress_intrinsic_metadata_for_tm_t ig_intr_md_for_tm) {
    RouterV46SRv6_micro_parser() RouterV46SRv6_micro_parser_inst;
    RouterV46SRv6_micro_control() RouterV46SRv6_micro_control_inst;
    RouterV46SRv6_micro_deparser() RouterV46SRv6_micro_deparser_inst;
    hdr_t hdr_t_var;
    RouterV46SRv6_parser_meta_t RouterV46SRv6_parser_meta_t_var;
    apply {
        RouterV46SRv6_micro_parser_inst.apply(msa_packet_struct_t_var, hdr_t_var, RouterV46SRv6_parser_meta_t_var);
        RouterV46SRv6_micro_control_inst.apply(msa_packet_struct_t_var, ig_intr_md_for_dprsr, ig_intr_md_for_tm, hdr_t_var);
        RouterV46SRv6_micro_deparser_inst.apply(msa_packet_struct_t_var, hdr_t_var, RouterV46SRv6_parser_meta_t_var);
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
        pc1.set((bit<8>)15);
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
    RouterV46SRv6() RouterV46SRv6_inst;
    apply {
        RouterV46SRv6_inst.apply(mpkt, ig_intr_md_for_dprsr, ig_intr_md_for_tm);
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
        pc1.set((bit<8>)15);
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

