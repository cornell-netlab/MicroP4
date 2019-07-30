/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _CSA_P4_
#define _CSA_P4_

#include <core.p4>

typedef   bit<9>    PortId_t;
const   PortId_t    PORT_CPU = 255;
const   PortId_t    PORT_RECIRCULATE = 254;

enum csa_packet_path_t {
    NORMAL,     /// Packet received by ingress that is none of the cases below.
    RECIRCULATE /// Packet arrival is the result of a recirculate operation
}

// extern void recirculate();

struct csa_standard_metadata_t {
    csa_packet_path_t packet_path;
    PortId_t ingress_port;
    bool drop_flag;  // true
}


enum csa_metadata_fields_t {
    QUEUE_DEPTH_AT_DEQUEUE
}


extern egress_spec {
    void set_egress_port(in PortId_t egress_port);
    PortId_t get_egress_port(); // default 0x00
    bit<32> get_value(csa_metadata_fields_t field_type);
}

extern csa_packet_in {
    csa_packet_in();
}


extern csa_packet_out {
    csa_packet_out();
    void get_packet_in(csa_packet_in csa_pin);
}

action csa_no_action(){}

/*
extern csa_packet_buffer_v2<EXTRA_ELE_T> {
    csa_packet_buffer_v2();
    //void get_packet_in(csa_packet_out po, csa_packet_in pin);
    void enqueue(csa_packet_out csa_po, in EXTRA_ELE_T ele); // writer
    void dequeue(csa_packet_in csa_pin, out EXTRA_ELE_T data); // finalize
}
*/



cpackage OrchestrationSwitch<IND, OUTD, INOUTD, UM, PSM>(
          csa_packet_in b, csa_packet_out po, 
          inout csa_standard_metadata_t standard_metadata, egress_spec es,
          in IND in_args, out OUTD out_args, inout INOUTD inout_args) () {

    @optional
    control csa_import(in IND in_meta, inout INOUTD inout_meta, inout UM meta, 
                   inout csa_standard_metadata_t sm, egress_spec e);
    /*
     * It is possible to directly invoke callee_pkg_inst.apply(...), because 
     * pin and po are available. Therefore, this OrchestrationSwitch does not have
     * "Execute" extern like CSASwitch.
     */
    control csa_pipe(csa_packet_in pin, csa_packet_out pout, inout UM meta, 
                 inout csa_standard_metadata_t sm, egress_spec e);
    
    @optional
    control csa_export(out OUTD out_meta, inout INOUTD inout_meta, in UM meta, 
                   in csa_standard_metadata_t sn, egress_spec e);
 
/*
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
*/

}

/*
 * Composable package interface declaration. 
 */
          
cpackage CSASwitch<IND, OUTD, INOUTD, H, UM, PSM>(
          csa_packet_in pin, csa_packet_out po, 
          inout csa_standard_metadata_t standard_metadata, egress_spec es,
          in IND in_args, out OUTD out_args, inout INOUTD inout_args)() {

    // Declarations for programmable blocks of basic switch package type
    parser csa_parser(packet_in b, out H parsed_hdr, inout UM meta, 
                  inout csa_standard_metadata_t sm);
 
    @optional
    control csa_import(in IND in_meta, inout INOUTD inout_meta, in H parsed_hdr, 
                   inout UM meta, inout csa_standard_metadata_t sm, 
                   egress_spec e);
    
    control csa_pipe(inout H hdr, inout UM meta, inout csa_standard_metadata_t sm, 
                 egress_spec e);
 
    @optional
    control csa_export(out OUTD out_meta, inout INOUTD inout_meta, in H parsed_hdr, 
                   in UM meta, in csa_standard_metadata_t sm, egress_spec e);
    
    control csa_deparser(packet_out b, in H hdr);
  


/*  
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
             inout standard_metadata_t standard_metadata) // rt params  
             (CPTYPE1 pkg_one_inst, CPTYPE2 pkg_two_inst) // ctor params {

    struct callee_context_t {
        bool callee_flag;
    }
    control ResultPipe(in INC in_meta, out OUTC out_meta, inout INOUTC inout_meta, 
                       inout H hdr, inout UM meta, 
                       inout standard_metadata_t standard_metadata, 
                       egress_spec es, inout PSM program_scope_metadata,
                       in callee_context_t ctx);
  }
*/

}


#endif  /* _CSA_P4_ */
