header csa_byte_h {
    bit<8> data;
}

header csa_indices_h {
    bit<16> pkt_len;
    bit<16> curr_offset;
}

struct msa_packet_struct_t {
    csa_byte_h[12] msa_packet;
    csa_indices_h  indices;
}

#include <core.p4>

typedef bit<8> PortId_t;
typedef bit<16> PktInstId_t;
typedef bit<16> GroupId_t;
enum metadata_fields_t {
    QUEUE_DEPTH_AT_DEQUEUE
}

extern pkt {
    void copy_from(pkt p);
    bit<32> get_length();
    bit<9> get_in_port();
}

extern im_t {
    void set_out_port(in PortId_t out_port);
    PortId_t get_out_port();
    bit<32> get_value(metadata_fields_t field_type);
    void copy_from(im_t im);
}

extern emitter {
    void emit<H/14>(pkt p, in H hdrs);
}

extern extractor {
    void extract<H/16>(pkt p, out H hdrs);
    T lookahead<T/17>();
}

extern in_buf<I/19> {
    void dequeue(pkt p, im_t im, out I in_param);
}

extern out_buf<O/21> {
    void enqueue(pkt p, im_t im, in O out_param);
    void to_in_buf(in_buf<O> ib);
    void merge(out_buf<O> ob);
}

extern mc_buf<H/23, O/24> {
    void enqueue(pkt p, im_t im, in H hdrs, in O param);
}

extern multicast_engine<O/26> {
    void set_multicast_group(GroupId_t gid);
    void apply(im_t im, out PktInstId_t id);
    void set_buf(out_buf<O> ob);
    void apply(pkt p, im_t im, out O o);
}

cpackage Unicast<H/28, M/29, I/30, O/31, IO/32>(pkt p, im_t im, in I in_param, out O out_param, inout IO inout_param)() {
    parser micro_parser(extractor ex, pkt p, im_t im, out H hdrs, inout M meta, in I in_param, inout IO inout_param);
    control micro_control(pkt p, im_t im, inout H hdrs, inout M meta, in I in_param, out O out_param, inout IO inout_param);
    control micro_deparser(emitter em, pkt p, in H hdrs);
}

struct empty_t {
}

struct swtrace_inout_t {
    bit<4>  ipv4_ihl;
    bit<16> ipv4_total_len;
}

struct filter_meta_t {
    bit<16> sport;
    bit<16> dport;
}

header udp_h {
    bit<16> sport;
    bit<16> dport;
}

header tcp_h {
    bit<16> sport;
    bit<16> dport;
}

struct callee_hdr_t {
    tcp_h tcp;
    udp_h udp;
}

cpackage Unicast(extern pkt {
    void copy_from(pkt p);
    bit<32> get_length();
    bit<9> get_in_port();
}
p, extern im_t {
    void set_out_port(in bit<8> out_port);
    bit<8> get_out_port();
    bit<32> get_value(enum metadata_fields_t {
        QUEUE_DEPTH_AT_DEQUEUE
    }
field_type);
    void copy_from(im_t im);
}
im, in struct empty_t {
}
in_param, out struct empty_t {
}
out_param, inout bit<8> inout_param)() {
    parser micro_parser(extern extractor {
        void extract<H/16>(extern pkt {
            void copy_from(pkt p);
            bit<32> get_length();
            bit<9> get_in_port();
        }
p, out H/16 hdrs);
        T/17 lookahead<T/17>();
    }
ex, extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, out struct callee_hdr_t {
        header tcp_h {
    bit<16> sport;
    bit<16> dport;
}
 tcp;
        header udp_h {
    bit<16> sport;
    bit<16> dport;
}
 udp;
    }
hdrs, inout struct filter_meta_t {
        bit<16> sport;
        bit<16> dport;
    }
meta, in struct empty_t {
    }
in_param, inout bit<8> inout_param);
    control micro_control(extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, inout struct callee_hdr_t {
        header tcp_h {
    bit<16> sport;
    bit<16> dport;
}
 tcp;
        header udp_h {
    bit<16> sport;
    bit<16> dport;
}
 udp;
    }
hdrs, inout struct filter_meta_t {
        bit<16> sport;
        bit<16> dport;
    }
meta, in struct empty_t {
    }
in_param, out struct empty_t {
    }
out_param, inout bit<8> inout_param);
    control micro_deparser(extern emitter {
        void emit<H/14>(extern pkt {
            void copy_from(pkt p);
            bit<32> get_length();
            bit<9> get_in_port();
        }
p, in H/14 hdrs);
    }
em, extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, in struct callee_hdr_t {
        header tcp_h {
    bit<16> sport;
    bit<16> dport;
}
 tcp;
        header udp_h {
    bit<16> sport;
    bit<16> dport;
}
 udp;
    }
hdrs);
}
cpackage Filter_L4 : implements Unicast<callee_hdr_t, filter_meta_t, empty_t, empty_t, bit<8>> {
    control micro_parser(inout msa_packet_struct_t p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, out struct callee_hdr_t {
        header tcp_h {
    bit<16> sport;
    bit<16> dport;
}
 tcp;
        header udp_h {
    bit<16> sport;
    bit<16> dport;
}
 udp;
    }
hdr, inout struct filter_meta_t {
        bit<16> sport;
        bit<16> dport;
    }
meta, in struct empty_t {
    }
ia, inout bit<8> l4proto) {
        action csa_micro_parser_invalid_headers() {
            hdr.tcp.setInvalid();
            hdr.udp.setInvalid();
        }
        action i_432_start_0() {
        }
        action i_280_start_0() {
        }
        action i_432_parse_udp_0() {
            hdr.udp.setValid();
            hdr.udp.sport = p.msa_packet[54].data ++ p.msa_packet[55].data;
            hdr.udp.dport = p.msa_packet[56].data ++ p.msa_packet[57].data;
            meta.sport = hdr.udp.sport;
            meta.dport = hdr.udp.dport;
        }
        action i_280_parse_udp_0() {
            hdr.udp.setValid();
            hdr.udp.sport = p.msa_packet[35].data ++ p.msa_packet[36].data;
            hdr.udp.dport = p.msa_packet[37].data ++ p.msa_packet[38].data;
            meta.sport = hdr.udp.sport;
            meta.dport = hdr.udp.dport;
        }
        action i_432_parse_tcp_0() {
            hdr.tcp.setValid();
            hdr.tcp.sport = p.msa_packet[54].data ++ p.msa_packet[55].data;
            hdr.tcp.dport = p.msa_packet[56].data ++ p.msa_packet[57].data;
            meta.sport = hdr.tcp.sport;
            meta.dport = hdr.tcp.dport;
        }
        action i_280_parse_tcp_0() {
            hdr.tcp.setValid();
            hdr.tcp.sport = p.msa_packet[35].data ++ p.msa_packet[36].data;
            hdr.tcp.dport = p.msa_packet[37].data ++ p.msa_packet[38].data;
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
                i_432_csa_reject();
                i_280_parse_tcp_0();
                i_280_parse_udp_0();
                i_280_csa_reject();
            }
            const entries = {
                                (280, 8w0x6) : i_280_parse_tcp_0();

                                (280, 8w0x17) : i_280_parse_udp_0();

                                (280, default) : i_280_csa_reject();

                                (432, 8w0x6) : i_432_parse_tcp_0();

                                (432, 8w0x17) : i_432_parse_udp_0();

                                (432, default) : i_432_csa_reject();

            }

            const default_action = NoAction();
        }
        apply {
            csa_micro_parser_invalid_headers();
            parser_tbl.apply();
        }
    }

    control micro_deparser(extern emitter {
        void emit<H/14>(extern pkt {
            void copy_from(pkt p);
            bit<32> get_length();
            bit<9> get_in_port();
        }
p, in H/14 hdrs);
    }
em, extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, in struct callee_hdr_t {
        header tcp_h {
    bit<16> sport;
    bit<16> dport;
}
 tcp;
        header udp_h {
    bit<16> sport;
    bit<16> dport;
}
 udp;
    }
hdr) {
        apply {
            em.emit<tcp_h>(p, hdr.tcp);
            em.emit<udp_h>(p, hdr.udp);
        }
    }

    control micro_control(extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, inout struct callee_hdr_t {
        header tcp_h {
    bit<16> sport;
    bit<16> dport;
}
 tcp;
        header udp_h {
    bit<16> sport;
    bit<16> dport;
}
 udp;
    }
hdr, inout struct filter_meta_t {
        bit<16> sport;
        bit<16> dport;
    }
m, in struct empty_t {
    }
ia, out struct empty_t {
    }
oa, inout bit<8> ioa) {
        @name(".NoAction") action NoAction_0() {
        }
        @name("Filter_L4.micro_control.drop_action") action drop_action() {
            im.set_out_port(8w0x0);
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
}

cpackage Nat_L4(pkt p, im_t im, in empty_t ia, out empty_t oa, inout bit<1> change, inout bit<8> l4proto)() {
}

struct meta_t {
}

header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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

struct hdr_t {
    ipv4_h ipv4;
}

cpackage Unicast(extern pkt {
    void copy_from(pkt p);
    bit<32> get_length();
    bit<9> get_in_port();
}
p, extern im_t {
    void set_out_port(in bit<8> out_port);
    bit<8> get_out_port();
    bit<32> get_value(enum metadata_fields_t {
        QUEUE_DEPTH_AT_DEQUEUE
    }
field_type);
    void copy_from(im_t im);
}
im, in struct empty_t {
}
in_param, out struct empty_t {
}
out_param, inout bit<16> inout_param)() {
    parser micro_parser(extern extractor {
        void extract<H/16>(extern pkt {
            void copy_from(pkt p);
            bit<32> get_length();
            bit<9> get_in_port();
        }
p, out H/16 hdrs);
        T/17 lookahead<T/17>();
    }
ex, extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, out struct hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
hdrs, inout struct empty_t {
    }
meta, in struct empty_t {
    }
in_param, inout bit<16> inout_param);
    control micro_control(extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, inout struct hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
hdrs, inout struct empty_t {
    }
meta, in struct empty_t {
    }
in_param, out struct empty_t {
    }
out_param, inout bit<16> inout_param);
    control micro_deparser(extern emitter {
        void emit<H/14>(extern pkt {
            void copy_from(pkt p);
            bit<32> get_length();
            bit<9> get_in_port();
        }
p, in H/14 hdrs);
    }
em, extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, in struct hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
hdrs);
}
cpackage Nat_L3 : implements Unicast<hdr_t, empty_t, empty_t, empty_t, bit<16>> {
    control micro_parser(inout msa_packet_struct_t p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, out struct hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
hdr, inout struct meta_t {
    }
meta, in struct empty_t {
    }
ia, inout bit<16> etherType) {
        action csa_micro_parser_invalid_headers() {
            hdr.ipv4.setInvalid();
        }
        action i_432_start_0() {
        }
        action i_280_start_0() {
        }
        action i_432_parse_ipv4_0() {
            hdr.ipv4.setValid();
            hdr.ipv4.version = p.msa_packet[54].data[3:0];
            hdr.ipv4.ihl = p.msa_packet[54].data[7:4];
            hdr.ipv4.diffserv = p.msa_packet[55].data;
            hdr.ipv4.ecn = p.msa_packet[56].data;
            hdr.ipv4.totalLen = p.msa_packet[57].data ++ p.msa_packet[58].data;
            hdr.ipv4.identification = p.msa_packet[59].data ++ p.msa_packet[60].data;
            hdr.ipv4.flags = p.msa_packet[61].data[2:0];
            hdr.ipv4.fragOffset = p.msa_packet[61].data[7:3] ++ p.msa_packet[62].data;
            hdr.ipv4.ttl = p.msa_packet[63].data;
            hdr.ipv4.protocol = p.msa_packet[64].data;
            hdr.ipv4.hdrChecksum = p.msa_packet[65].data ++ p.msa_packet[66].data;
            hdr.ipv4.srcAddr = p.msa_packet[67].data ++ (p.msa_packet[68].data ++ (p.msa_packet[69].data ++ p.msa_packet[70].data));
            hdr.ipv4.dstAddr = p.msa_packet[71].data ++ (p.msa_packet[72].data ++ (p.msa_packet[73].data ++ p.msa_packet[74].data));
        }
        action i_280_parse_ipv4_0() {
            hdr.ipv4.setValid();
            hdr.ipv4.version = p.msa_packet[35].data[3:0];
            hdr.ipv4.ihl = p.msa_packet[35].data[7:4];
            hdr.ipv4.diffserv = p.msa_packet[36].data;
            hdr.ipv4.ecn = p.msa_packet[37].data;
            hdr.ipv4.totalLen = p.msa_packet[38].data ++ p.msa_packet[39].data;
            hdr.ipv4.identification = p.msa_packet[40].data ++ p.msa_packet[41].data;
            hdr.ipv4.flags = p.msa_packet[42].data[2:0];
            hdr.ipv4.fragOffset = p.msa_packet[42].data[7:3] ++ p.msa_packet[43].data;
            hdr.ipv4.ttl = p.msa_packet[44].data;
            hdr.ipv4.protocol = p.msa_packet[45].data;
            hdr.ipv4.hdrChecksum = p.msa_packet[46].data ++ p.msa_packet[47].data;
            hdr.ipv4.srcAddr = p.msa_packet[48].data ++ (p.msa_packet[49].data ++ (p.msa_packet[50].data ++ p.msa_packet[51].data));
            hdr.ipv4.dstAddr = p.msa_packet[52].data ++ (p.msa_packet[53].data ++ (p.msa_packet[54].data ++ p.msa_packet[55].data));
        }
        table parser_tbl {
            key = {
                p.indices.curr_offset: exact;
                etherType            : ternary;
            }
            actions = {
                i_432_parse_ipv4_0();
                i_432_csa_reject();
                i_280_parse_ipv4_0();
                i_280_csa_reject();
            }
            const entries = {
                                (280, 16w0x800) : i_280_parse_ipv4_0();

                                (280, default) : i_280_csa_reject();

                                (432, 16w0x800) : i_432_parse_ipv4_0();

                                (432, default) : i_432_csa_reject();

            }

            const default_action = NoAction();
        }
        apply {
            csa_micro_parser_invalid_headers();
            parser_tbl.apply();
        }
    }

    control micro_deparser(extern emitter {
        void emit<H/14>(extern pkt {
            void copy_from(pkt p);
            bit<32> get_length();
            bit<9> get_in_port();
        }
p, in H/14 hdrs);
    }
em, extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, in struct hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
hdr) {
        apply {
            em.emit<ipv4_h>(p, hdr.ipv4);
        }
    }

    control micro_control(extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, inout struct hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
hdr, inout struct meta_t {
    }
m, in struct empty_t {
    }
ia, out struct empty_t {
    }
oa, inout bit<16> etherType) {
        @name(".NoAction") action NoAction_0() {
        }
        bit<1> change_0;
        @name("Nat_L3.micro_control.nat4_i") Nat_L4() nat4_i_0;
        @name("Nat_L3.micro_control.change_srcAddr") action change_srcAddr() {
            change_0 = 1w1;
        }
        @name("Nat_L3.micro_control.srcAddr_tbl") table srcAddr_tbl_0 {
            key = {
                hdr.ipv4.srcAddr: lpm @name("hdr.ipv4.srcAddr") ;
            }
            actions = {
                change_srcAddr();
                @defaultonly NoAction_0();
            }
            const entries = {
                                32w0xa000200 &&& 32w0xffffff00 : change_srcAddr();

            }

            default_action = NoAction_0();
        }
        apply {
            change_0 = 1w0;
            srcAddr_tbl_0.apply();
            nat4_i_0.apply(p, im, ia, oa, change_0, hdr.ipv4.protocol);
        }
    }
}

struct ecn_meta_t {
}

struct ecn_hdr_t {
    ipv4_h ipv4;
}

cpackage Unicast(extern pkt {
    void copy_from(pkt p);
    bit<32> get_length();
    bit<9> get_in_port();
}
p, extern im_t {
    void set_out_port(in bit<8> out_port);
    bit<8> get_out_port();
    bit<32> get_value(enum metadata_fields_t {
        QUEUE_DEPTH_AT_DEQUEUE
    }
field_type);
    void copy_from(im_t im);
}
im, in struct empty_t {
}
in_param, out struct empty_t {
}
out_param, inout bit<16> inout_param)() {
    parser micro_parser(extern extractor {
        void extract<H/16>(extern pkt {
            void copy_from(pkt p);
            bit<32> get_length();
            bit<9> get_in_port();
        }
p, out H/16 hdrs);
        T/17 lookahead<T/17>();
    }
ex, extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, out struct ecn_hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
hdrs, inout struct ecn_meta_t {
    }
meta, in struct empty_t {
    }
in_param, inout bit<16> inout_param);
    control micro_control(extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, inout struct ecn_hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
hdrs, inout struct ecn_meta_t {
    }
meta, in struct empty_t {
    }
in_param, out struct empty_t {
    }
out_param, inout bit<16> inout_param);
    control micro_deparser(extern emitter {
        void emit<H/14>(extern pkt {
            void copy_from(pkt p);
            bit<32> get_length();
            bit<9> get_in_port();
        }
p, in H/14 hdrs);
    }
em, extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, in struct ecn_hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
hdrs);
}
cpackage ecnv4 : implements Unicast<ecn_hdr_t, ecn_meta_t, empty_t, empty_t, bit<16>> {
    control micro_parser(inout msa_packet_struct_t p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, out struct ecn_hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
hdr, inout struct ecn_meta_t {
    }
meta, in struct empty_t {
    }
ia, inout bit<16> ethType) {
        action csa_micro_parser_invalid_headers() {
            hdr.ipv4.setInvalid();
        }
        action i_432_start_0() {
        }
        action i_280_start_0() {
        }
        action i_432_parse_ipv4_0() {
            hdr.ipv4.setValid();
            hdr.ipv4.version = p.msa_packet[54].data[3:0];
            hdr.ipv4.ihl = p.msa_packet[54].data[7:4];
            hdr.ipv4.diffserv = p.msa_packet[55].data;
            hdr.ipv4.ecn = p.msa_packet[56].data;
            hdr.ipv4.totalLen = p.msa_packet[57].data ++ p.msa_packet[58].data;
            hdr.ipv4.identification = p.msa_packet[59].data ++ p.msa_packet[60].data;
            hdr.ipv4.flags = p.msa_packet[61].data[2:0];
            hdr.ipv4.fragOffset = p.msa_packet[61].data[7:3] ++ p.msa_packet[62].data;
            hdr.ipv4.ttl = p.msa_packet[63].data;
            hdr.ipv4.protocol = p.msa_packet[64].data;
            hdr.ipv4.hdrChecksum = p.msa_packet[65].data ++ p.msa_packet[66].data;
            hdr.ipv4.srcAddr = p.msa_packet[67].data ++ (p.msa_packet[68].data ++ (p.msa_packet[69].data ++ p.msa_packet[70].data));
            hdr.ipv4.dstAddr = p.msa_packet[71].data ++ (p.msa_packet[72].data ++ (p.msa_packet[73].data ++ p.msa_packet[74].data));
        }
        action i_280_parse_ipv4_0() {
            hdr.ipv4.setValid();
            hdr.ipv4.version = p.msa_packet[35].data[3:0];
            hdr.ipv4.ihl = p.msa_packet[35].data[7:4];
            hdr.ipv4.diffserv = p.msa_packet[36].data;
            hdr.ipv4.ecn = p.msa_packet[37].data;
            hdr.ipv4.totalLen = p.msa_packet[38].data ++ p.msa_packet[39].data;
            hdr.ipv4.identification = p.msa_packet[40].data ++ p.msa_packet[41].data;
            hdr.ipv4.flags = p.msa_packet[42].data[2:0];
            hdr.ipv4.fragOffset = p.msa_packet[42].data[7:3] ++ p.msa_packet[43].data;
            hdr.ipv4.ttl = p.msa_packet[44].data;
            hdr.ipv4.protocol = p.msa_packet[45].data;
            hdr.ipv4.hdrChecksum = p.msa_packet[46].data ++ p.msa_packet[47].data;
            hdr.ipv4.srcAddr = p.msa_packet[48].data ++ (p.msa_packet[49].data ++ (p.msa_packet[50].data ++ p.msa_packet[51].data));
            hdr.ipv4.dstAddr = p.msa_packet[52].data ++ (p.msa_packet[53].data ++ (p.msa_packet[54].data ++ p.msa_packet[55].data));
        }
        table parser_tbl {
            key = {
                p.indices.curr_offset: exact;
                ethType              : ternary;
            }
            actions = {
                i_432_parse_ipv4_0();
                i_432_csa_reject();
                i_280_parse_ipv4_0();
                i_280_csa_reject();
            }
            const entries = {
                                (280, 16w0x800) : i_280_parse_ipv4_0();

                                (280, default) : i_280_csa_reject();

                                (432, 16w0x800) : i_432_parse_ipv4_0();

                                (432, default) : i_432_csa_reject();

            }

            const default_action = NoAction();
        }
        apply {
            csa_micro_parser_invalid_headers();
            parser_tbl.apply();
        }
    }

    control micro_deparser(extern emitter {
        void emit<H/14>(extern pkt {
            void copy_from(pkt p);
            bit<32> get_length();
            bit<9> get_in_port();
        }
p, in H/14 hdrs);
    }
em, extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, in struct ecn_hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
h) {
        apply {
            em.emit<ipv4_h>(p, h.ipv4);
        }
    }

    control micro_control(extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, inout struct ecn_hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
hdr, inout struct ecn_meta_t {
    }
m, in struct empty_t {
    }
e, out struct empty_t {
    }
oa, inout bit<16> ioa) {
        @name(".NoAction") action NoAction_0() {
        }
        @name("ecnv4.micro_control.set_ecn") action set_ecn() {
            hdr.ipv4.ecn = 8w3;
        }
        @name("ecnv4.micro_control.ecn_tbl") table ecn_tbl_0 {
            key = {
                hdr.ipv4.ecn: exact @name("hdr.ipv4.ecn") ;
            }
            actions = {
                set_ecn();
                @defaultonly NoAction_0();
            }
            const entries = {
                                8w0o1 : set_ecn();

                                8w0o2 : set_ecn();

            }

            default_action = NoAction_0();
        }
        apply {
            ecn_tbl_0.apply();
        }
    }
}

struct l3_meta_t {
}

struct l3_hdr_t {
    ipv4_h ipv4;
}

cpackage Unicast(extern pkt {
    void copy_from(pkt p);
    bit<32> get_length();
    bit<9> get_in_port();
}
p, extern im_t {
    void set_out_port(in bit<8> out_port);
    bit<8> get_out_port();
    bit<32> get_value(enum metadata_fields_t {
        QUEUE_DEPTH_AT_DEQUEUE
    }
field_type);
    void copy_from(im_t im);
}
im, in struct empty_t {
}
in_param, out bit<16> out_param, inout bit<16> inout_param)() {
    parser micro_parser(extern extractor {
        void extract<H/16>(extern pkt {
            void copy_from(pkt p);
            bit<32> get_length();
            bit<9> get_in_port();
        }
p, out H/16 hdrs);
        T/17 lookahead<T/17>();
    }
ex, extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, out struct l3_hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
hdrs, inout struct l3_meta_t {
    }
meta, in struct empty_t {
    }
in_param, inout bit<16> inout_param);
    control micro_control(extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, inout struct l3_hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
hdrs, inout struct l3_meta_t {
    }
meta, in struct empty_t {
    }
in_param, out bit<16> out_param, inout bit<16> inout_param);
    control micro_deparser(extern emitter {
        void emit<H/14>(extern pkt {
            void copy_from(pkt p);
            bit<32> get_length();
            bit<9> get_in_port();
        }
p, in H/14 hdrs);
    }
em, extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, in struct l3_hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
hdrs);
}
cpackage L3v4 : implements Unicast<l3_hdr_t, l3_meta_t, empty_t, bit<16>, bit<16>> {
    control micro_parser(inout msa_packet_struct_t p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, out struct l3_hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
hdr, inout struct l3_meta_t {
    }
meta, in struct empty_t {
    }
ia, inout bit<16> ethType) {
        action csa_micro_parser_invalid_headers() {
            hdr.ipv4.setInvalid();
        }
        action i_432_start_0() {
        }
        action i_280_start_0() {
        }
        action i_432_parse_ipv4_0() {
            hdr.ipv4.setValid();
            hdr.ipv4.version = p.msa_packet[54].data[3:0];
            hdr.ipv4.ihl = p.msa_packet[54].data[7:4];
            hdr.ipv4.diffserv = p.msa_packet[55].data;
            hdr.ipv4.ecn = p.msa_packet[56].data;
            hdr.ipv4.totalLen = p.msa_packet[57].data ++ p.msa_packet[58].data;
            hdr.ipv4.identification = p.msa_packet[59].data ++ p.msa_packet[60].data;
            hdr.ipv4.flags = p.msa_packet[61].data[2:0];
            hdr.ipv4.fragOffset = p.msa_packet[61].data[7:3] ++ p.msa_packet[62].data;
            hdr.ipv4.ttl = p.msa_packet[63].data;
            hdr.ipv4.protocol = p.msa_packet[64].data;
            hdr.ipv4.hdrChecksum = p.msa_packet[65].data ++ p.msa_packet[66].data;
            hdr.ipv4.srcAddr = p.msa_packet[67].data ++ (p.msa_packet[68].data ++ (p.msa_packet[69].data ++ p.msa_packet[70].data));
            hdr.ipv4.dstAddr = p.msa_packet[71].data ++ (p.msa_packet[72].data ++ (p.msa_packet[73].data ++ p.msa_packet[74].data));
        }
        action i_280_parse_ipv4_0() {
            hdr.ipv4.setValid();
            hdr.ipv4.version = p.msa_packet[35].data[3:0];
            hdr.ipv4.ihl = p.msa_packet[35].data[7:4];
            hdr.ipv4.diffserv = p.msa_packet[36].data;
            hdr.ipv4.ecn = p.msa_packet[37].data;
            hdr.ipv4.totalLen = p.msa_packet[38].data ++ p.msa_packet[39].data;
            hdr.ipv4.identification = p.msa_packet[40].data ++ p.msa_packet[41].data;
            hdr.ipv4.flags = p.msa_packet[42].data[2:0];
            hdr.ipv4.fragOffset = p.msa_packet[42].data[7:3] ++ p.msa_packet[43].data;
            hdr.ipv4.ttl = p.msa_packet[44].data;
            hdr.ipv4.protocol = p.msa_packet[45].data;
            hdr.ipv4.hdrChecksum = p.msa_packet[46].data ++ p.msa_packet[47].data;
            hdr.ipv4.srcAddr = p.msa_packet[48].data ++ (p.msa_packet[49].data ++ (p.msa_packet[50].data ++ p.msa_packet[51].data));
            hdr.ipv4.dstAddr = p.msa_packet[52].data ++ (p.msa_packet[53].data ++ (p.msa_packet[54].data ++ p.msa_packet[55].data));
        }
        table parser_tbl {
            key = {
                p.indices.curr_offset: exact;
                ethType              : ternary;
            }
            actions = {
                i_432_parse_ipv4_0();
                i_432_csa_reject();
                i_280_parse_ipv4_0();
                i_280_csa_reject();
            }
            const entries = {
                                (280, 16w0x800) : i_280_parse_ipv4_0();

                                (280, default) : i_280_csa_reject();

                                (432, 16w0x800) : i_432_parse_ipv4_0();

                                (432, default) : i_432_csa_reject();

            }

            const default_action = NoAction();
        }
        apply {
            csa_micro_parser_invalid_headers();
            parser_tbl.apply();
        }
    }

    control micro_deparser(extern emitter {
        void emit<H/14>(extern pkt {
            void copy_from(pkt p);
            bit<32> get_length();
            bit<9> get_in_port();
        }
p, in H/14 hdrs);
    }
em, extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, in struct l3_hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
h) {
        apply {
            em.emit<ipv4_h>(p, h.ipv4);
        }
    }

    control micro_control(extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, inout struct l3_hdr_t {
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
    }
hdr, inout struct l3_meta_t {
    }
m, in struct empty_t {
    }
e, out bit<16> nexthop, inout bit<16> ethType) {
        @name(".NoAction") action NoAction_0() {
        }
        @name("L3v4.micro_control.process") action process(bit<16> nh) {
            hdr.ipv4.ttl = hdr.ipv4.ttl + 8w255;
            nexthop = nh;
        }
        @name("L3v4.micro_control.ipv4_lpm_tbl") table ipv4_lpm_tbl_0 {
            key = {
                hdr.ipv4.dstAddr: lpm @name("hdr.ipv4.dstAddr") ;
            }
            actions = {
                process();
                @defaultonly NoAction_0();
            }
            default_action = NoAction_0();
        }
        apply {
            ipv4_lpm_tbl_0.apply();
        }
    }
}

struct main_meta_t {
    bit<8> l4proto;
}

header ethernet_h {
    bit<48> dmac;
    bit<48> smac;
    bit<16> ethType;
}

header ipv6_h {
    bit<4>   version;
    bit<8>   class;
    bit<20>  label;
    bit<16>  totalLen;
    bit<8>   nexthdr;
    bit<8>   hoplimit;
    bit<128> srcAddr;
    bit<128> dstAddr;
}

struct main_hdr_t {
    ethernet_h eth;
    ipv4_h     ipv4;
    ipv6_h     ipv6;
}

cpackage Unicast(extern pkt {
    void copy_from(pkt p);
    bit<32> get_length();
    bit<9> get_in_port();
}
p, extern im_t {
    void set_out_port(in bit<8> out_port);
    bit<8> get_out_port();
    bit<32> get_value(enum metadata_fields_t {
        QUEUE_DEPTH_AT_DEQUEUE
    }
field_type);
    void copy_from(im_t im);
}
im, in struct empty_t {
}
in_param, out struct empty_t {
}
out_param, inout struct empty_t {
}
inout_param)() {
    parser micro_parser(extern extractor {
        void extract<H/16>(extern pkt {
            void copy_from(pkt p);
            bit<32> get_length();
            bit<9> get_in_port();
        }
p, out H/16 hdrs);
        T/17 lookahead<T/17>();
    }
ex, extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, out struct main_hdr_t {
        header ethernet_h {
    bit<48> dmac;
    bit<48> smac;
    bit<16> ethType;
}
                                                                                                                                                                                                                        eth;
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
        header ipv6_h {
    bit<4>   version;
    bit<8>   class;
    bit<20>  label;
    bit<16>  totalLen;
    bit<8>   nexthdr;
    bit<8>   hoplimit;
    bit<128> srcAddr;
    bit<128> dstAddr;
}
                                                                                                       ipv6;
    }
hdrs, inout struct main_meta_t {
        bit<8> l4proto;
    }
meta, in struct empty_t {
    }
in_param, inout struct empty_t {
    }
inout_param);
    control micro_control(extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, inout struct main_hdr_t {
        header ethernet_h {
    bit<48> dmac;
    bit<48> smac;
    bit<16> ethType;
}
                                                                                                                                                                                                                        eth;
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
        header ipv6_h {
    bit<4>   version;
    bit<8>   class;
    bit<20>  label;
    bit<16>  totalLen;
    bit<8>   nexthdr;
    bit<8>   hoplimit;
    bit<128> srcAddr;
    bit<128> dstAddr;
}
                                                                                                       ipv6;
    }
hdrs, inout struct main_meta_t {
        bit<8> l4proto;
    }
meta, in struct empty_t {
    }
in_param, out struct empty_t {
    }
out_param, inout struct empty_t {
    }
inout_param);
    control micro_deparser(extern emitter {
        void emit<H/14>(extern pkt {
            void copy_from(pkt p);
            bit<32> get_length();
            bit<9> get_in_port();
        }
p, in H/14 hdrs);
    }
em, extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, in struct main_hdr_t {
        header ethernet_h {
    bit<48> dmac;
    bit<48> smac;
    bit<16> ethType;
}
                                                                                                                                                                                                                        eth;
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
        header ipv6_h {
    bit<4>   version;
    bit<8>   class;
    bit<20>  label;
    bit<16>  totalLen;
    bit<8>   nexthdr;
    bit<8>   hoplimit;
    bit<128> srcAddr;
    bit<128> dstAddr;
}
                                                                                                       ipv6;
    }
hdrs);
}
cpackage ModularMultiFunction : implements Unicast<main_hdr_t, main_meta_t, empty_t, empty_t, empty_t> {
    control micro_parser(inout msa_packet_struct_t p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, out struct main_hdr_t {
        header ethernet_h {
    bit<48> dmac;
    bit<48> smac;
    bit<16> ethType;
}
                                                                                                                                                                                                                        eth;
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
        header ipv6_h {
    bit<4>   version;
    bit<8>   class;
    bit<20>  label;
    bit<16>  totalLen;
    bit<8>   nexthdr;
    bit<8>   hoplimit;
    bit<128> srcAddr;
    bit<128> dstAddr;
}
                                                                                                       ipv6;
    }
main_hdr, inout struct main_meta_t {
        bit<8> l4proto;
    }
m, in struct empty_t {
    }
ia, inout struct empty_t {
    }
ioa) {
        action csa_micro_parser_invalid_headers() {
            main_hdr.eth.setInvalid();
            main_hdr.ipv4.setInvalid();
            main_hdr.ipv6.setInvalid();
        }
        action i_0_start_0() {
            main_hdr.eth.setValid();
            main_hdr.eth.dmac = p.msa_packet[0].data ++ (p.msa_packet[1].data ++ (p.msa_packet[2].data ++ (p.msa_packet[3].data ++ (p.msa_packet[4].data ++ p.msa_packet[5].data))));
            main_hdr.eth.smac = p.msa_packet[6].data ++ (p.msa_packet[7].data ++ (p.msa_packet[8].data ++ (p.msa_packet[9].data ++ (p.msa_packet[10].data ++ p.msa_packet[11].data))));
            main_hdr.eth.ethType = p.msa_packet[12].data ++ p.msa_packet[13].data;
        }
        action i_0_parse_ipv6_0() {
            main_hdr.ipv6.setValid();
            main_hdr.ipv6.version = p.msa_packet[14].data[3:0];
            main_hdr.ipv6.class = p.msa_packet[14].data[7:4] ++ p.msa_packet[15].data[3:0];
            main_hdr.ipv6.label = p.msa_packet[15].data[7:4] ++ (p.msa_packet[16].data ++ p.msa_packet[17].data);
            main_hdr.ipv6.totalLen = p.msa_packet[18].data ++ p.msa_packet[19].data;
            main_hdr.ipv6.nexthdr = p.msa_packet[20].data;
            main_hdr.ipv6.hoplimit = p.msa_packet[21].data;
            main_hdr.ipv6.srcAddr = p.msa_packet[22].data ++ (p.msa_packet[23].data ++ (p.msa_packet[24].data ++ (p.msa_packet[25].data ++ (p.msa_packet[26].data ++ (p.msa_packet[27].data ++ (p.msa_packet[28].data ++ (p.msa_packet[29].data ++ (p.msa_packet[30].data ++ (p.msa_packet[31].data ++ (p.msa_packet[32].data ++ (p.msa_packet[33].data ++ (p.msa_packet[34].data ++ (p.msa_packet[35].data ++ (p.msa_packet[36].data ++ p.msa_packet[37].data))))))))))))));
            main_hdr.ipv6.dstAddr = p.msa_packet[38].data ++ (p.msa_packet[39].data ++ (p.msa_packet[40].data ++ (p.msa_packet[41].data ++ (p.msa_packet[42].data ++ (p.msa_packet[43].data ++ (p.msa_packet[44].data ++ (p.msa_packet[45].data ++ (p.msa_packet[46].data ++ (p.msa_packet[47].data ++ (p.msa_packet[48].data ++ (p.msa_packet[49].data ++ (p.msa_packet[50].data ++ (p.msa_packet[51].data ++ (p.msa_packet[52].data ++ p.msa_packet[53].data))))))))))))));
            m.l4proto = main_hdr.ipv6.nexthdr;
            main_hdr.eth.setValid();
            main_hdr.eth.dmac = p.msa_packet[0].data ++ (p.msa_packet[1].data ++ (p.msa_packet[2].data ++ (p.msa_packet[3].data ++ (p.msa_packet[4].data ++ p.msa_packet[5].data))));
            main_hdr.eth.smac = p.msa_packet[6].data ++ (p.msa_packet[7].data ++ (p.msa_packet[8].data ++ (p.msa_packet[9].data ++ (p.msa_packet[10].data ++ p.msa_packet[11].data))));
            main_hdr.eth.ethType = p.msa_packet[12].data ++ p.msa_packet[13].data;
        }
        action i_0_parse_ipv4_0() {
            main_hdr.ipv4.setValid();
            main_hdr.ipv4.version = p.msa_packet[14].data[3:0];
            main_hdr.ipv4.ihl = p.msa_packet[14].data[7:4];
            main_hdr.ipv4.diffserv = p.msa_packet[15].data;
            main_hdr.ipv4.ecn = p.msa_packet[16].data;
            main_hdr.ipv4.totalLen = p.msa_packet[17].data ++ p.msa_packet[18].data;
            main_hdr.ipv4.identification = p.msa_packet[19].data ++ p.msa_packet[20].data;
            main_hdr.ipv4.flags = p.msa_packet[21].data[2:0];
            main_hdr.ipv4.fragOffset = p.msa_packet[21].data[7:3] ++ p.msa_packet[22].data;
            main_hdr.ipv4.ttl = p.msa_packet[23].data;
            main_hdr.ipv4.protocol = p.msa_packet[24].data;
            main_hdr.ipv4.hdrChecksum = p.msa_packet[25].data ++ p.msa_packet[26].data;
            main_hdr.ipv4.srcAddr = p.msa_packet[27].data ++ (p.msa_packet[28].data ++ (p.msa_packet[29].data ++ p.msa_packet[30].data));
            main_hdr.ipv4.dstAddr = p.msa_packet[31].data ++ (p.msa_packet[32].data ++ (p.msa_packet[33].data ++ p.msa_packet[34].data));
            m.l4proto = main_hdr.ipv4.protocol;
            main_hdr.eth.setValid();
            main_hdr.eth.dmac = p.msa_packet[0].data ++ (p.msa_packet[1].data ++ (p.msa_packet[2].data ++ (p.msa_packet[3].data ++ (p.msa_packet[4].data ++ p.msa_packet[5].data))));
            main_hdr.eth.smac = p.msa_packet[6].data ++ (p.msa_packet[7].data ++ (p.msa_packet[8].data ++ (p.msa_packet[9].data ++ (p.msa_packet[10].data ++ p.msa_packet[11].data))));
            main_hdr.eth.ethType = p.msa_packet[12].data ++ p.msa_packet[13].data;
        }
        table parser_tbl {
            key = {
                p.msa_packet[12].data ++ p.msa_packet[13].data: ternary;
            }
            actions = {
            }
            const entries = {
                                16w0x800 : i_0_parse_ipv4_0();

                                16w0x86dd : i_0_parse_ipv6_0();

                                default : i_0_csa_reject();

            }

            const default_action = NoAction();
        }
        apply {
            csa_micro_parser_invalid_headers();
            parser_tbl.apply();
        }
    }

    control micro_deparser(extern emitter {
        void emit<H/14>(extern pkt {
            void copy_from(pkt p);
            bit<32> get_length();
            bit<9> get_in_port();
        }
p, in H/14 hdrs);
    }
em, extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, in struct main_hdr_t {
        header ethernet_h {
    bit<48> dmac;
    bit<48> smac;
    bit<16> ethType;
}
                                                                                                                                                                                                                        eth;
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
        header ipv6_h {
    bit<4>   version;
    bit<8>   class;
    bit<20>  label;
    bit<16>  totalLen;
    bit<8>   nexthdr;
    bit<8>   hoplimit;
    bit<128> srcAddr;
    bit<128> dstAddr;
}
                                                                                                       ipv6;
    }
main_hdr) {
        apply {
            em.emit<ethernet_h>(p, main_hdr.eth);
        }
    }

    control micro_control(extern pkt {
        void copy_from(pkt p);
        bit<32> get_length();
        bit<9> get_in_port();
    }
p, extern im_t {
        void set_out_port(in bit<8> out_port);
        bit<8> get_out_port();
        bit<32> get_value(enum metadata_fields_t {
            QUEUE_DEPTH_AT_DEQUEUE
        }
field_type);
        void copy_from(im_t im);
    }
im, inout struct main_hdr_t {
        header ethernet_h {
    bit<48> dmac;
    bit<48> smac;
    bit<16> ethType;
}
                                                                                                                                                                                                                        eth;
        header ipv4_h {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<8>  ecn;
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
 ipv4;
        header ipv6_h {
    bit<4>   version;
    bit<8>   class;
    bit<20>  label;
    bit<16>  totalLen;
    bit<8>   nexthdr;
    bit<8>   hoplimit;
    bit<128> srcAddr;
    bit<128> dstAddr;
}
                                                                                                       ipv6;
    }
main_hdr, inout struct main_meta_t {
        bit<8> l4proto;
    }
m, in struct empty_t {
    }
ia, out struct empty_t {
    }
oa, inout struct empty_t {
    }
ioa) {
        @name(".NoAction") action NoAction_0() {
        }
        bit<16> nh_0;
        @name("ModularMultiFunction.micro_control.filter") Filter_L4() filter_0;
        @name("ModularMultiFunction.micro_control.l3_i") L3v4() l3_i_0;
        @name("ModularMultiFunction.micro_control.nat3_i") Nat_L3() nat3_i_0;
        @name("ModularMultiFunction.micro_control.ecn_i") ecnv4() ecn_i_0;
        @name("ModularMultiFunction.micro_control.forward") action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
            main_hdr.eth.dmac = dmac;
            main_hdr.eth.smac = smac;
            im.set_out_port(port);
        }
        @name("ModularMultiFunction.micro_control.forward_tbl") table forward_tbl_0 {
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
            filter_0.apply(p, im, ia, oa, m.l4proto);
            nat3_i_0.apply(p, im, ia, oa, main_hdr.eth.ethType);
            ecn_i_0.apply(p, im, ia, oa, main_hdr.eth.ethType);
            l3_i_0.apply(p, im, ia, nh_0, main_hdr.eth.ethType);
            forward_tbl_0.apply();
        }
    }
}

ModularMultiFunction() main;

