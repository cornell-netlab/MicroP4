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
        action i_240_start_0() {
        }
        action i_432_parse_udp_0() {
            hdr.udp.setValid();
            hdr.udp.sport = p.msa_packet[54].data ++ p.msa_packet[55].data;
            hdr.udp.dport = p.msa_packet[56].data ++ p.msa_packet[57].data;
            meta.sport = hdr.udp.sport;
            meta.dport = hdr.udp.dport;
        }
        action i_240_parse_udp_0() {
            hdr.udp.setValid();
            hdr.udp.sport = p.msa_packet[30].data ++ p.msa_packet[31].data;
            hdr.udp.dport = p.msa_packet[32].data ++ p.msa_packet[33].data;
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
        action i_240_parse_tcp_0() {
            hdr.tcp.setValid();
            hdr.tcp.sport = p.msa_packet[30].data ++ p.msa_packet[31].data;
            hdr.tcp.dport = p.msa_packet[32].data ++ p.msa_packet[33].data;
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
                i_240_parse_tcp_0();
                i_240_parse_udp_0();
                i_240_csa_reject();
            }
            const entries = {
                                (240, 8w0x6) : i_240_parse_tcp_0();

                                (240, 8w0x17) : i_240_parse_udp_0();

                                (240, default) : i_240_csa_reject();

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

struct l3_meta_t {
}

header ipv4_h {
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
    bit<16> srcAddr;
    bit<16> dstAddr;
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
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<16> srcAddr;
    bit<16> dstAddr;
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
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<16> srcAddr;
    bit<16> dstAddr;
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
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<16> srcAddr;
    bit<16> dstAddr;
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
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<16> srcAddr;
    bit<16> dstAddr;
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
        action i_240_start_0() {
        }
        action i_432_parse_ipv4_0() {
            hdr.ipv4.setValid();
            hdr.ipv4.version = p.msa_packet[54].data[3:0];
            hdr.ipv4.ihl = p.msa_packet[54].data[7:4];
            hdr.ipv4.diffserv = p.msa_packet[55].data;
            hdr.ipv4.totalLen = p.msa_packet[56].data ++ p.msa_packet[57].data;
            hdr.ipv4.identification = p.msa_packet[58].data ++ p.msa_packet[59].data;
            hdr.ipv4.flags = p.msa_packet[60].data[2:0];
            hdr.ipv4.fragOffset = p.msa_packet[60].data[7:3] ++ p.msa_packet[61].data;
            hdr.ipv4.ttl = p.msa_packet[62].data;
            hdr.ipv4.protocol = p.msa_packet[63].data;
            hdr.ipv4.hdrChecksum = p.msa_packet[64].data ++ p.msa_packet[65].data;
            hdr.ipv4.srcAddr = p.msa_packet[66].data ++ p.msa_packet[67].data;
            hdr.ipv4.dstAddr = p.msa_packet[68].data ++ p.msa_packet[69].data;
        }
        action i_240_parse_ipv4_0() {
            hdr.ipv4.setValid();
            hdr.ipv4.version = p.msa_packet[30].data[3:0];
            hdr.ipv4.ihl = p.msa_packet[30].data[7:4];
            hdr.ipv4.diffserv = p.msa_packet[31].data;
            hdr.ipv4.totalLen = p.msa_packet[32].data ++ p.msa_packet[33].data;
            hdr.ipv4.identification = p.msa_packet[34].data ++ p.msa_packet[35].data;
            hdr.ipv4.flags = p.msa_packet[36].data[2:0];
            hdr.ipv4.fragOffset = p.msa_packet[36].data[7:3] ++ p.msa_packet[37].data;
            hdr.ipv4.ttl = p.msa_packet[38].data;
            hdr.ipv4.protocol = p.msa_packet[39].data;
            hdr.ipv4.hdrChecksum = p.msa_packet[40].data ++ p.msa_packet[41].data;
            hdr.ipv4.srcAddr = p.msa_packet[42].data ++ p.msa_packet[43].data;
            hdr.ipv4.dstAddr = p.msa_packet[44].data ++ p.msa_packet[45].data;
        }
        table parser_tbl {
            key = {
                p.indices.curr_offset: exact;
                ethType              : ternary;
            }
            actions = {
                i_432_parse_ipv4_0();
                i_432_csa_reject();
                i_240_parse_ipv4_0();
                i_240_csa_reject();
            }
            const entries = {
                                (240, 16w0x800) : i_240_parse_ipv4_0();

                                (240, default) : i_240_csa_reject();

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
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<16> srcAddr;
    bit<16> dstAddr;
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
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<16> srcAddr;
    bit<16> dstAddr;
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

struct meta_t {
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

struct hdr_t {
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
im, out struct hdr_t {
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
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<16> srcAddr;
    bit<16> dstAddr;
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
hdrs, inout struct meta_t {
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
im, inout struct hdr_t {
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
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<16> srcAddr;
    bit<16> dstAddr;
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
hdrs, inout struct meta_t {
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
p, in struct hdr_t {
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
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<16> srcAddr;
    bit<16> dstAddr;
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
cpackage ModularFirewall : implements Unicast<hdr_t, meta_t, empty_t, empty_t, empty_t> {
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
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<16> srcAddr;
    bit<16> dstAddr;
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
hdr, inout struct meta_t {
        bit<8> l4proto;
    }
m, in struct empty_t {
    }
ia, inout struct empty_t {
    }
ioa) {
        action csa_micro_parser_invalid_headers() {
            hdr.eth.setInvalid();
            hdr.ipv4.setInvalid();
            hdr.ipv6.setInvalid();
        }
        action i_0_start_0() {
            hdr.eth.setValid();
            hdr.eth.dmac = p.msa_packet[0].data ++ (p.msa_packet[1].data ++ (p.msa_packet[2].data ++ (p.msa_packet[3].data ++ (p.msa_packet[4].data ++ p.msa_packet[5].data))));
            hdr.eth.smac = p.msa_packet[6].data ++ (p.msa_packet[7].data ++ (p.msa_packet[8].data ++ (p.msa_packet[9].data ++ (p.msa_packet[10].data ++ p.msa_packet[11].data))));
            hdr.eth.ethType = p.msa_packet[12].data ++ p.msa_packet[13].data;
        }
        action i_0_parse_ipv6_0() {
            hdr.ipv6.setValid();
            hdr.ipv6.version = p.msa_packet[14].data[3:0];
            hdr.ipv6.class = p.msa_packet[14].data[7:4] ++ p.msa_packet[15].data[3:0];
            hdr.ipv6.label = p.msa_packet[15].data[7:4] ++ (p.msa_packet[16].data ++ p.msa_packet[17].data);
            hdr.ipv6.totalLen = p.msa_packet[18].data ++ p.msa_packet[19].data;
            hdr.ipv6.nexthdr = p.msa_packet[20].data;
            hdr.ipv6.hoplimit = p.msa_packet[21].data;
            hdr.ipv6.srcAddr = p.msa_packet[22].data ++ (p.msa_packet[23].data ++ (p.msa_packet[24].data ++ (p.msa_packet[25].data ++ (p.msa_packet[26].data ++ (p.msa_packet[27].data ++ (p.msa_packet[28].data ++ (p.msa_packet[29].data ++ (p.msa_packet[30].data ++ (p.msa_packet[31].data ++ (p.msa_packet[32].data ++ (p.msa_packet[33].data ++ (p.msa_packet[34].data ++ (p.msa_packet[35].data ++ (p.msa_packet[36].data ++ p.msa_packet[37].data))))))))))))));
            hdr.ipv6.dstAddr = p.msa_packet[38].data ++ (p.msa_packet[39].data ++ (p.msa_packet[40].data ++ (p.msa_packet[41].data ++ (p.msa_packet[42].data ++ (p.msa_packet[43].data ++ (p.msa_packet[44].data ++ (p.msa_packet[45].data ++ (p.msa_packet[46].data ++ (p.msa_packet[47].data ++ (p.msa_packet[48].data ++ (p.msa_packet[49].data ++ (p.msa_packet[50].data ++ (p.msa_packet[51].data ++ (p.msa_packet[52].data ++ p.msa_packet[53].data))))))))))))));
            m.l4proto = hdr.ipv6.nexthdr;
            hdr.eth.setValid();
            hdr.eth.dmac = p.msa_packet[0].data ++ (p.msa_packet[1].data ++ (p.msa_packet[2].data ++ (p.msa_packet[3].data ++ (p.msa_packet[4].data ++ p.msa_packet[5].data))));
            hdr.eth.smac = p.msa_packet[6].data ++ (p.msa_packet[7].data ++ (p.msa_packet[8].data ++ (p.msa_packet[9].data ++ (p.msa_packet[10].data ++ p.msa_packet[11].data))));
            hdr.eth.ethType = p.msa_packet[12].data ++ p.msa_packet[13].data;
        }
        action i_0_parse_ipv4_0() {
            hdr.ipv4.setValid();
            hdr.ipv4.version = p.msa_packet[14].data[3:0];
            hdr.ipv4.ihl = p.msa_packet[14].data[7:4];
            hdr.ipv4.diffserv = p.msa_packet[15].data;
            hdr.ipv4.totalLen = p.msa_packet[16].data ++ p.msa_packet[17].data;
            hdr.ipv4.identification = p.msa_packet[18].data ++ p.msa_packet[19].data;
            hdr.ipv4.flags = p.msa_packet[20].data[2:0];
            hdr.ipv4.fragOffset = p.msa_packet[20].data[7:3] ++ p.msa_packet[21].data;
            hdr.ipv4.ttl = p.msa_packet[22].data;
            hdr.ipv4.protocol = p.msa_packet[23].data;
            hdr.ipv4.hdrChecksum = p.msa_packet[24].data ++ p.msa_packet[25].data;
            hdr.ipv4.srcAddr = p.msa_packet[26].data ++ p.msa_packet[27].data;
            hdr.ipv4.dstAddr = p.msa_packet[28].data ++ p.msa_packet[29].data;
            m.l4proto = hdr.ipv4.protocol;
            hdr.eth.setValid();
            hdr.eth.dmac = p.msa_packet[0].data ++ (p.msa_packet[1].data ++ (p.msa_packet[2].data ++ (p.msa_packet[3].data ++ (p.msa_packet[4].data ++ p.msa_packet[5].data))));
            hdr.eth.smac = p.msa_packet[6].data ++ (p.msa_packet[7].data ++ (p.msa_packet[8].data ++ (p.msa_packet[9].data ++ (p.msa_packet[10].data ++ p.msa_packet[11].data))));
            hdr.eth.ethType = p.msa_packet[12].data ++ p.msa_packet[13].data;
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
p, in struct hdr_t {
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
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<16> srcAddr;
    bit<16> dstAddr;
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
hdr) {
        apply {
            em.emit<ethernet_h>(p, hdr.eth);
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
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<16> srcAddr;
    bit<16> dstAddr;
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
hdr, inout struct meta_t {
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
        @name("ModularFirewall.micro_control.filter") Filter_L4() filter_0;
        @name("ModularFirewall.micro_control.l3_i") L3v4() l3_i_0;
        @name("ModularFirewall.micro_control.forward") action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
            hdr.eth.dmac = dmac;
            hdr.eth.smac = smac;
            im.set_out_port(port);
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
            filter_0.apply(p, im, ia, oa, m.l4proto);
            l3_i_0.apply(p, im, ia, nh_0, hdr.eth.ethType);
            forward_tbl_0.apply();
        }
    }
}

ModularFirewall() main;

