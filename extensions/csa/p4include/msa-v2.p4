/*
 * Hardik Soni (hardik.soni@cornell.edu)
 *
 */
#ifndef _MSA_P4_
#define _MSA_P4_

#include <core.p4>

typedef   bit<8>    PortId_t;
typedef   bit<16>   PacketInstanceId_t;
typedef   bit<16>   GroupId_t;
const   PortId_t    PORT_CPU = 255;
const   PortId_t    PORT_RECIRCULATE = 254;

enum msa_packet_path_t {
    NORMAL,     /// Packet received by ingress that is none of the cases below.
//    RECIRCULATE /// Packet arrival is the result of a recirculate operation
}

/*
 * Recirculate is required to process the packet through same the same piece of
 * code repeatedly in control block.
extern void recirculate();
 */

/*
 * Programmers can declare and instance of this and create copies of it
 */
struct sm_t {
  msa_packet_path_t packet_path;
  PortId_t ingress_port;
  bool drop_flag;  // true
}

enum msa_metadata_fields_t {
  QUEUE_DEPTH_AT_DEQUEUE
}

extern egress_spec {
  void set_egress_port(in PortId_t egress_port);
  PortId_t get_egress_port(); // default 0x00
  bit<32> get_value(msa_metadata_fields_t field_type);
  void copy_from(egress_spec es);
}

extern pkt {
  void copy_from(pkt p);
}

extern emitter {
  void emit<H>(pkt p, in H hdrs);
}

extern extractor {
  void extractor<H>(pkt, out H hdrs);
  /// T may be an arbitrary fixed-size type.
  T lookahead<T>();
}

extern in_buf<I> {
  dequeue(pkt p, out sm_t sm, es_t es, out I in_param);
}

extern out_buf<O> {
  enqueue(pkt p, in sm_t sm, es_t es, in O out_param);
}

extern mc_in_buf<H, I> {
  dequeue(pkt p, out H hdrs, out sm_t sm, es_t es, out I in_param);
}

extern mc_out_buf<H, O> {
  enqueue(pkt p, in H hdrs, in sm_t sm, es_t es, in O out_param);
}

action msa_no_action(){}

extern multicast_engine {
    msa_multicast_engine();
    
    void set_multicast_group(GroupId_t gid);

    // Analogous to fork system call, only difference is original (parent
    // process) cease to exist.
    // Retuens packet instance id and appropriate egress_spec will be have
    // port_id set by the CP for the PacketInstanceId_t value.
    // All other declaration and arguments (local variable declarations, headers,
    // metadata etc.,) in the scope will be available after this call.
    //
    // This function is available only in apply body of control blocks.
    // Need to think more, if it should be allowed in Action body.
    /*
     * Potential misuse of above function:
     * not using es in successive statements. but using some es1 or es passed in
     * arguments.
     * Compiler should raise warning and if programmer persist, it essentially 
     * means overriding configuration of control plane.
     *
     */
    PacketInstanceId_t apply(egress_spec es);

    set_buf(out_buf<O>);
    apply(pkt, out sm_t, es_t, out O);

    // In future, a shim will translate between architecture specific CP APIs
    /*
    @ControlPlaneAPI
    {
        entry_handle add_group (GroupId_t gid);
        void         delete_group (GroupId_t gid);
        void         add_group_entry   (GroupId_t gid, PacketInstanceId_t, PortId_t);
        void         delete_group_entry (GroupId_t gid, PacketInstanceId_t, PortId_t);
    }
    */


}

cpackage  Unicast<H, M, I, O, IO>(pkt p, inout sm_t sm, es_t es, in I in_param, 
                                  out O out_param, inout IO inout_param) {
  parser micro_parser(extractor ex, pkt p, out H hdrs, inout M meta, inout sm_t sm, in I in_param, inout IO inout_param);

  control micro_control(pkt p, inout H hdrs, inout M m, inout sm_t sm, es_t es, in I in_param, out O out_param, inout IO inout_param);

  control micro_deparser(emitter em, pkt p, in H hdrs);
}

Multicast<H, M, I, O>(pkt p, in sm_t sm, es_t es, in I in_param, out_buf<O> ob) {

  parser micro_parser(extractor ex, pkt p, out H hdrs, inout M meta, in I in_param, inout sm_t sm);

  control micro_control(pkt p, inout H hdrs, inout M meta, inout sm_t sm, es_t es, inout I in_param, mc_out_buf<H,O> mob);

  control micro_deparser(emitter em, out_buf<O> ob, mc_in_buf<H,O> mib);
}

Orchestration<I, O>(in_buf<I>, out_buf<O>) {
  control orch_control(pkt p, inout sm_t sm, es_t es, in I in_param, out_buf<O> ob);
}



#endif  /* _msa_P4_ */
