/*
 * Hardik Soni (hardik.soni@cornell.edu)
 *
 */

/********* Expressing full program compositions and their semantics ************\
 *
 * Two major changes in current P4 front-end grammar and package execution
 * semantics:
 * 1. Additional "apply" method semantics for package types:
 * 2. The new Production rules are added for composable package.
 *    
 * All the packages should be seen as black box.
 * The input to the box are byte stream as an instance of packet_in type, an
 * instance of standard_metadata_t and runtime parameters passed to the proram.
 * These parameters have in, out or inout directions.
 *
 * The output is 1 to n copies of packet_out, standard_metadata and values
 * updated in the parameters passed to them according to their directions.
 * Additionally, each top level package is associated with two virtual buffers,
 * "in" and  "out".
 * On invoking a package instance, execution control reads bytes(packet_in.data 
 * and standard metadata) from the package's `in` buffer and writes (packet_out,
 * standard_metadata) to the `out` buffer.
 *
 *   ___                                                      ___
 *  |in |               ___________________                  |out|
 *  |   |              |                   |--packet_out.1-->|   |
 *  | b |--packet_in-->|                   |-- standard      | b |
 *  | u |              | Top Level Package |    metadata.1-->| u |
 *  | f |-- standard   |                   |..               | f |
 *  | f |  metadata -->|                   |--packet_out.n-->| f |
 *  | e |              |___________________|-- standard      | e |
 *  |_r_|                                       metadata.n-->|_r_|
 *
 * H type headers, M type metadata are internal state of packages. 
 * They should be enclosed within packages.
 *
 *
 * Similarly, execution semantics for instances of MATs, Actions and 
 * Controls are augmented with `in` and `out` virtual buffers.
 * On every invocation of a instance, execution control reads headers, metadata 
 * and standard_metdata etc., from the instance's in buffer, modifies them and 
 * write them on ithe instance's out buffer.
 * If multiple copies of the data are generated as a result of applying a table,
 * control or action, the copies are added to the out buffer in an undefined 
 * order.
 * 
 * The content of elements in the in-out buffer are decided by the 
 * parameters (both optConstructor and runtime) in the type declaration.
 *
 * Program's control flow graph dictates the interconnection and sharing of
 * in-out buffers of each instances of MATs, Actions and Controls.
 *
 *   ___                                                        ___ 
 *  |in |               _____________________                  |out|
 *  | b |              |                     |-- Headers.a1 -->| b |
 *  | u |-- Headers -->|       Actions       |-- Metadata.a1-->| u |  
 *  | f |              |         MAT         |..               | f |
 *  | f |-- Metadata-->|    Multicast MAT    |..               | f |
 *  | e |              |      Control        |-- Headers.an -->| e |
 *  |_r_|              |_____________________|-- Metadata.an-->|_r_|
 *
 *  For control statements like if-else and switch.
 *  Switch statement is skipped here.
 *  Short explanation: For each case switch stmt have an out buffer.
 *   ___                                                        _________ 
 *  |in |               _____________________                  |   True  |
 *  | b |              |                     |-- Headers.a1 -->|   out   |
 *  | u |-- Headers -->|                     |-- Metadata.a1-->| buffer  |  
 *  | f |              |       if-else       |..               |---------|
 *  | f |-- Metadata-->|        stmt         |..               |  False  |
 *  | e |              |                     |-- Headers.a1 -->|   out   |
 *  |_r_|              |_____________________|-- Metadata.a1-->|__buffer_|
 *
 ******************************************************************************/

#ifndef _CSA_P4_
#define _CSA_P4_

typedef   bit<8>    PortId_t;
const   PortId_t    PORT_CPU = 255;
const   PortId_t    PORT_RECIRCULATE = 254;

enum CSA_PacketPath_t {
    NORMAL,     /// Packet received by ingress that is none of the cases below.
    RECIRCULATE /// Packet arrival is the result of a recirculate operation
}


extern void recirculate();

struct standard_metadata_t {

    CSA_PacketPath_t packet_path;
    PortId_t ingress_port;
    bool drop_flag;  // true
}

// There are two options to enforce dependency on egress_port assignment and
// queuing related metadata.
// 1. Init returns structure of queuing related metadata)
// 2. separate functions returning value for each field in queuing related
// metadata
enum metadata_t {
    EGRESS_PORT_QUEUE_LENGTH
}

extern egress_spec {
    void set_egress_port(PortId_t egress_port);
    PortId_t get_egress_port(); // default 0x00
    bit<32> get_value(metadata_t field_type);
}


/*
 * Composable package interface declaration. 
 */
cpackage CSASwitch<IND, OUTD, INOUTD, H, UM, PSM>(
          packet_in pin, packet_out po, out H parsedHdr,
          in IND in_args, out OUTD out_args, inout INOUTD inout_args)() {

  @optional
  cpackage ExecuteSwitch<CPTYPE, INC, OUTC, INOUTC>( /* rt params */ 
                         in INC in_meta, out OUTC out_meta, 
                         inout INOUTC inout_meta,
                         inout H parsed_hdr, 
                         inout UM meta,
                         inout  standard_metadata_t standard_metadata) 
                         (CPTYPE callee_inst) /* ctor params */;

  // Declarations for programmable blocks of basic switch package type
  parser Parser(packet_in b, out H parsed_hdr, inout UM meta, 
                inout standard_metadata_t standard_metadata, 
                in PSM program_scope_metadata);

  @optional
  control Import(in IND in_meta, inout INOUTD inout_meta, in H parsed_hdr, 
                 inout UM meta, inout standard_metadata_t standard_metadata, 
                 egress_spec es);
  
  control Pipe(inout H hdr, inout UM meta, 
               inout standard_metadata_t standard_metadata,
               egress_spec es);

  @optional
  control Export(out OUTD out_meta, inout INOUTD inout_meta, in H parsed_hdr, 
                 in UM meta, in standard_metadata_t standard_metadata, 
                 egress_spec es);
  
  control Deparser(packet_out b, in H hdr, out PSM program_scope_metadata);
  
  // Optional
  // Programmer can define more than one Parallel Switch.
  // And they can be invoked in the Pipe Control block.
  // e.g, MyParallelSwitch() inst_one;
  // inst_one.apply(callee1, callee2, ro_data, wo_data, rw_data, parsed_headers,
  // my_meta, std_meta);
  @optional
  cpackage ParallelSwitch<INC, OUTC, INOUTC, CPTYPE1, CPTYPE2>(
             in INC callee_in_args, out OUTC callee_out_args, 
             inout INOUTC callee_inout_args, inout H parsed_hdr, inout UM meta, 
             inout standard_metadata_t standard_metadata) /* rt params */ 
             (CPTYPE1 pkg_one_inst, CPTYPE2 pkg_two_inst) /* ctor params */ {

    struct callee_context_t {
        bool callee_flag;
    }
    control ResultPipe(in INC in_meta, out OUTC out_meta, inout INOUTC inout_meta, 
                       inout H hdr, inout UM meta, 
                       inout standard_metadata_t standard_metadata, 
                       egress_spec es, inout PSM program_scope_metadata,
                       in callee_context_t ctx);
  }

}

/*
 * This package type allows to program execution CFG (DAG) by only using
 * instances of other programs.
 * Hence, programmer does not need to program parser and deparser blocks.
 *
 * This package is more useful for ease of programming and composition.
 */
cpackage OrchestrationSwitch<IND, OUTD, INOUTD, UM, PSM>(packet_in b,
          packet_out p, in IND in_args, out OUTD out_args, 
          inout INOUTD inout_args) () {

  @optional
  control Import(in IND in_meta, inout INOUTD inout_meta, inout UM meta, 
                 inout standard_metadata_t standard_metadata, egress_spec es);
  /*
   * It is possible to directly invoke callee_pkg_inst.apply(...), because 
   * pin and po are available. Therefore, this OrchestrationSwitch does not have
   * "Execute" extern like CSASwitch.
   */
  control Pipe(packet_in pin, packet_out po, inout UM meta, 
               inout standard_metadata_t standard_metadata, egress_spec es,
               inout PSM recirculate_meta);
  
  @optional
  control Export(out OUTD out_meta, inout INOUTD inout_meta, in UM meta, 
                 in standard_metadata_t standard_metadata, egress_spec es);

  @optional
  cpackage ParallelSwitch<INC, OUTC, INOUTC, CPTYPE1, CPTYPE2>(
           CPTYPE1 pkg_one_inst, CPTYPE2 pkg_two_inst, packet_in pin, 
           packet_out po, in INC in_meta, out OUTC out_meta, 
           inout INOUTC inout_meta)() {

    struct callee_context_t {
        bool callee_flag;
    }

    control ResultPipe(in INC callee_in_args, out OUTC callee_out_args, 
                       inout INOUTC callee_inout_args, inout UM meta, 
                       inout standard_metadata_t standard_metadata, 
                       egress_spec es, inout PSM program_scope_metadata, 
                       in callee_context_t ctx);

  }

}

#endif  /* _CSA_P4_ */
