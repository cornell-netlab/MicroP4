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
    RECIRCULATE /// Packet arrival is the result of a recirculate operation
}


/*
 * Recirculate is required to process the packet through same the same piece of
 * code repeatedly in control block.
 */
extern void recirculate();


/*
 * Programmers can declare and instance of this and create copies of it
 */
struct msa_standard_metadata_t {
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

extern msa_packet_in {
    msa_packet_in();
    void copy_from(msa_packet_in msa_pin);
}

extern msa_packet_out {
    msa_packet_out();
    void get_packet_in(msa_packet_in msa_pin);
}

action msa_no_action(){}


extern msa_multicast_engine {
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
    PacketInstanceId_t apply(egress_spec es);
    /*
     * Potential misuse of above function:
     * not using es in successive statements. but using some es1 or es passed in
     * arguments.
     * Compiler should raise warning and if programmer persist, it essentially 
     * means overriding configuration of control plane.
     *
     */

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

extern msa_multicast_buffer<EXTRA_ELE_T> {
    packet_buffer();
    void enqueue(msa_packet_out msa_po, in msa_standard_metadata_t sm,
                 egress_spec es, in EXTRA_ELE_T ele); // writer
    
    void dequeue(msa_packet_in msa_pin, out msa_standard_metadata_t sm,
                 egress_spec es, out EXTRA_ELE_T data); // finalize, writes on arguments
}


/*
 * This has to be package, because main can not be instance of P4Control types.
 */
cpackage OrchestrationSwitch<IND, OUTD, INOUTD, RM>(
          msa_packet_in b, msa_packet_out po, 
          inout msa_standard_metadata_t standard_metadata, egress_spec es,
          in IND in_args, out OUTD out_args, inout INOUTD inout_args) () {

    control msa_pipe(msa_packet_in pin, msa_packet_out pout, 
                     in IND in_meta, out OUTD out_meta, inout INOUTD inout_meta, 
                     inout msa_standard_metadata_t sm, egress_spec e,
                     inout RM recirculate_data);

}

cpackage CSASwitch<IND, OUTD, INOUTD, H, UM, RM>(
          msa_packet_in pin, msa_packet_out po, 
          inout msa_standard_metadata_t standard_metadata, egress_spec es,
          in IND in_args, out OUTD out_args, inout INOUTD inout_args)() {

    parser msa_parser(packet_in b, out H parsed_hdr, inout UM meta, 
                  inout msa_standard_metadata_t sm);
 
    control msa_pipe(inout H hdr, inout UM meta, inout msa_standard_metadata_t sm, 
                     egress_spec e,  in IND in_meta, out OUTD out_meta, 
                     inout INOUTD inout_meta, inout RM recirculate_data);
    
    control msa_deparser(packet_out b, in H hdr);
}


#endif  /* _msa_P4_ */
