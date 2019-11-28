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

struct l3_meta_t {
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

struct l3_hdr_t {
    ipv6_h ipv6;
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
in_param, out bit<128> out_param, inout bit<16> inout_param)() {
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
hdrs, inout struct l3_meta_t {
    }
meta, in struct empty_t {
    }
in_param, out bit<128> out_param, inout bit<16> inout_param);
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
cpackage L3v6 : implements Unicast<l3_hdr_t, l3_meta_t, empty_t, bit<128>, bit<16>> {
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
hdr, inout struct l3_meta_t {
    }
meta, in struct empty_t {
    }
ia, inout bit<16> ethType) {
        action csa_micro_parser_invalid_headers() {
            hdr.ipv6.setInvalid();
        }
        action i_112_start_0() {
        }
        action i_112_parse_ipv6_0() {
            hdr.ipv6.setValid();
            hdr.ipv6.version = p.msa_packet[14].data[3:0];
            hdr.ipv6.class = p.msa_packet[14].data[7:4] ++ p.msa_packet[15].data[3:0];
            hdr.ipv6.label = p.msa_packet[15].data[7:4] ++ (p.msa_packet[16].data ++ p.msa_packet[17].data);
            hdr.ipv6.totalLen = p.msa_packet[18].data ++ p.msa_packet[19].data;
            hdr.ipv6.nexthdr = p.msa_packet[20].data;
            hdr.ipv6.hoplimit = p.msa_packet[21].data;
            hdr.ipv6.srcAddr = p.msa_packet[22].data ++ (p.msa_packet[23].data ++ (p.msa_packet[24].data ++ (p.msa_packet[25].data ++ (p.msa_packet[26].data ++ (p.msa_packet[27].data ++ (p.msa_packet[28].data ++ (p.msa_packet[29].data ++ (p.msa_packet[30].data ++ (p.msa_packet[31].data ++ (p.msa_packet[32].data ++ (p.msa_packet[33].data ++ (p.msa_packet[34].data ++ (p.msa_packet[35].data ++ (p.msa_packet[36].data ++ p.msa_packet[37].data))))))))))))));
            hdr.ipv6.dstAddr = p.msa_packet[38].data ++ (p.msa_packet[39].data ++ (p.msa_packet[40].data ++ (p.msa_packet[41].data ++ (p.msa_packet[42].data ++ (p.msa_packet[43].data ++ (p.msa_packet[44].data ++ (p.msa_packet[45].data ++ (p.msa_packet[46].data ++ (p.msa_packet[47].data ++ (p.msa_packet[48].data ++ (p.msa_packet[49].data ++ (p.msa_packet[50].data ++ (p.msa_packet[51].data ++ (p.msa_packet[52].data ++ p.msa_packet[53].data))))))))))))));
        }
        table parser_tbl {
            key = {
                p.indices.curr_offset: exact;
                ethType              : ternary;
            }
            actions = {
                i_112_parse_ipv6_0();
                i_112_csa_reject();
            }
            const entries = {
                                (112, 16w0x86dd) : i_112_parse_ipv6_0();

                                (112, default) : i_112_csa_reject();

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
h) {
        apply {
            em.emit<ipv6_h>(p, h.ipv6);
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
hdr, inout struct l3_meta_t {
    }
m, in struct empty_t {
    }
e, out bit<128> nexthop, inout bit<16> ethType) {
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
}

struct meta_t {
}

header ethernet_h {
    bit<48> dmac;
    bit<48> smac;
    bit<16> ethType;
}

struct hdr_t {
    ethernet_h eth;
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
    }
hdrs, inout struct meta_t {
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
    }
hdrs, inout struct meta_t {
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
    }
hdrs);
}
cpackage ModularRouterv6 : implements Unicast<hdr_t, meta_t, empty_t, empty_t, empty_t> {
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
    }
hdr, inout struct meta_t {
    }
meta, in struct empty_t {
    }
ia, inout struct empty_t {
    }
ioa) {
        action csa_micro_parser_invalid_headers() {
            hdr.eth.setInvalid();
        }
        action i_0_start_0() {
            hdr.eth.setValid();
            hdr.eth.dmac = p.msa_packet[0].data ++ (p.msa_packet[1].data ++ (p.msa_packet[2].data ++ (p.msa_packet[3].data ++ (p.msa_packet[4].data ++ p.msa_packet[5].data))));
            hdr.eth.smac = p.msa_packet[6].data ++ (p.msa_packet[7].data ++ (p.msa_packet[8].data ++ (p.msa_packet[9].data ++ (p.msa_packet[10].data ++ p.msa_packet[11].data))));
            hdr.eth.ethType = p.msa_packet[12].data ++ p.msa_packet[13].data;
        }
        table parser_tbl {
            key = {
            }
            actions = {
            }
            const entries = {
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
    }
hdr, inout struct meta_t {
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
        bit<128> nh_0;
        @name("ModularRouterv6.micro_control.l3_i") L3v6() l3_i_0;
        @name("ModularRouterv6.micro_control.forward") action forward(bit<48> dmac, bit<48> smac, PortId_t port) {
            hdr.eth.dmac = dmac;
            hdr.eth.smac = smac;
            im.set_out_port(port);
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
            l3_i_0.apply(p, im, ia, nh_0, hdr.eth.ethType);
            forward_tbl_0.apply();
        }
    }
}

ModularRouterv6() main;

