# μP4 Architecture.

μP4 is a logical architecture that can be mapped to real target architectures.
It defines following logical externs and programmable blocks to enable modular programming.

## Programming Model
Every μP4 program is modeled as black-box. Every μP4 program is an instance of a cpackage type. 
Every cpackage type has a `apply` method call with runtime behaviour shown in following model. 
                       ___________________                   ___ 
    ___               |                   |-- out args.1 -->|   |
   |in |              |                   |--inout args.1-->|out|
   |   |--in  args -->|                   |--  packet.1  -->|   |
   | b |--inout args->|                   |-- std.meta.1 -->| b |
   | u |--  packet -->|                   |                 | u |
   | f |-- standard   |   cpackage type   |-- out args.n -->| f |
   | f |  metadata -->|                   |--inout args.n-->| f |
   | e |  (std.meta)  |                   |--  packet.n  -->| e |
   |_r_|              |                   |--  std.meta.n-->| r |
                      |                   |                 |___|
                      |___________________|                   
 
  H type headers, M type metadata, parsers, controls are parts of cpackage implementation. 
  They are encapulated within definitions of cpackages.

```P4
/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */
#ifndef _MSA_P4_
#define _MSA_P4_

#include <core.p4>

typedef   bit<9>    PortId_t;
typedef   bit<16>   PktInstId_t;
typedef   bit<16>   GroupId_t;
const   PortId_t    PORT_CPU = 255;
const   PortId_t    PORT_RECIRCULATE = 254;

enum msa_packet_path_t {
    NORMAL     /// Packet received by ingress that is none of the cases below.
//    RECIRCULATE /// Packet arrival is the result of a recirculate operation
}

/*
 * Recirculate is required to process the packet through same the same piece of
 * code repeatedly in control block.
extern void recirculate();
 */

enum metadata_fields_t {
  QUEUE_DEPTH_AT_DEQUEUE
}

extern pkt {
  void copy_from(pkt p);
  bit<32> get_length();
}

extern im_t {
  void set_out_port(in PortId_t out_port);
  PortId_t get_in_port();
  PortId_t get_out_port(); // default 0x00
  bit<32> get_value(metadata_fields_t field_type);
  void copy_from(im_t im);
  void drop();
}

extern emitter {
  void emit<H>(pkt p, in H hdrs);
}

extern extractor {
  void extract<H>(pkt p, out H hdrs);
  /// T may be an arbitrary fixed-size type.
  T lookahead<T>();
}

extern in_buf<I> {
  // This is not the architecture but part of model.
  // void dequeue(pkt p, im_t im, out I in_param);
}

extern out_buf<O> {
  void enqueue(pkt p, im_t im, in O out_param);

  // Can be used to convert out_buf to in_buf
  // All the elements of this instance are moved to ib.
  // Clears the out_buf.
  void to_in_buf(in_buf<O> ib);

  // All the elements of ob are moved to this instance
  void merge(out_buf<O> ob);
}

extern mc_buf<H, O> {
  void enqueue(pkt p, im_t im, in H hdrs, in O param);
}

action msa_no_action(){}
///////////////////////////////////////////////////////////////////////////////
/*
 * Checksums externs are similar to PSA.
 * For higher clarity and portability enums are separated.
 */
/* Disabled for AE 
enum Checksum_Algorithm_t {
  CRC32
}

enum Incremental_Checksum_Algorithm_t {
  INTERNET_CHECKSUM
}
*/

/*
 * W should be of type bit<N>
 */
/* Disabled for AE 
extern Checksum<W> {

  Checksum(Checksum_Algorithm_t ca);

  void clear();

  void add_data<T>(in T data);

  W get_sum();
}

extern IncrementalChecksum<W> {

  IncrementalChecksum(Incremental_Checksum_Algorithm_t icat);

  void clear();

  void add_data<T>(in T data);

  void remove_data<T>(in T data);

  W get_sum();

  W get_state();

  void set_state(in W checksum_state);
}
*/
///////////////////////////////////////////////////////////////////////////////


extern multicast_engine<O> {
  void set_multicast_group(GroupId_t gid);

  // Analogous to fork system call, only difference is original (parent
  // process) cease to exist.
  // Retuens packet instance id and appropriate im_t will be have
  // port_id set by the CP for the PktInstId_t value.
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
  void apply(im_t im, out PktInstId_t id);

  void set_buf(out_buf<O> ob);
  void apply(pkt p, im_t im, out O o);

  // In future, a shim will translate between architecture specific CP APIs
  /*
  @ControlPlaneAPI
  {
      entry_handle add_group (GroupId_t gid);
      void         delete_group (GroupId_t gid);
      void         add_group_entry   (GroupId_t gid, PktInstId_t, PortId_t);
      void         delete_group_entry (GroupId_t gid, PktInstId_t, PortId_t);
  }
  */
}

cpackage Unicast<H, M, I, O, IO>(pkt p, im_t im, in I in_param, out O out_param, inout IO inout_param) {
  parser micro_parser(extractor ex, pkt p, im_t im, out H hdrs, inout M meta, in I in_param, inout IO inout_param);

  control micro_control(pkt p, im_t im, inout H hdrs, inout M meta, in I in_param, out O out_param, inout IO inout_param);

  control micro_deparser(emitter em, pkt p, in H hdrs);
}

cpackage Multicast<H, M, I, O>(pkt p, im_t im, in I in_param, out_buf<O> ob) {

  parser micro_parser(extractor ex, pkt p, im_t im, out H hdrs, inout M meta, in I in_param);

  control micro_control(pkt p, im_t im, inout H hdrs, inout M meta, inout I in_param, mc_buf<H,O> mob);

  control micro_deparser(emitter em, pkt p, in H hdrs);
}

cpackage Orchestration<I, O>(in_buf<I> ib, out_buf<O> ob) {
  // ib.dequeue operation is executed by microp4 before calling the control.
  control orch_control(pkt p, im_t im, in I in_param, out_buf<O> ob);
}

#endif  /* _msa_P4_ */

```
