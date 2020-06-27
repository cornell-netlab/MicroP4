#include <core.p4>
#include <csa.p4>

struct empty_t {}


/////////////////////////////////////////////////////////////

header H1 {
  bit<8> f1;
  bit<8> f2;
}

header H2 {
  bit<16> f1;
  bit<16> f2;
}

struct parsed_headers_t {
  H1 h1;
  H2 h2;
}

struct my_metadata_t {
  bit<8> d;
}

cpackage Layer2 : implements CSASwitch<empty_t, empty_t, empty_t, parsed_headers_t, 
                                       my_metadata_t, empty_t> {


  // Declarations for programmable blocks of basic switch package type
  parser Parser(packet_in pin, out parsed_headers_t parsed_hdr, 
                inout my_metadata_t meta, 
                inout standard_metadata_t standard_metadata, 
                in empty_t program_scope_metadata) {

    state start {
      transition parse_h1;
    }

    state parse_h1 {
      pin.extract(parsed_hdr.h1);
      transition parse_h2;
    }

    state parse_h2 {
      pin.extract(parsed_hdr.h2);
      transition accept;
    }

  }
 
  control Pipe(inout parsed_headers_t parsed_hdr, inout my_metadata_t meta,
               inout standard_metadata_t standard_metadata, egress_spec es) {

    bit<8> i = 0b0;
    action action1(bit<48> dmac, bit<8> port) {
      i = 0x11;
      es.set_egress_port(port);
    }

    action action2() { 
      i = 0xff;
    }
 
    table t1 {
      key = { parsed_hdr.h1.f1: exact; }
      actions = {
        action2;
        action1;
      }
    }
    action action3() { }
    action action4() { }

    table t2 {
      key = { es.get_value(csa_metadata_fields_t.EGRESS_PORT_QUEUE_LENGTH) 
                            : exact @name("egress_port_queue") ;
              parsed_hdr.h2.f1 : exact;}
      actions = {
        action3;
        action4;
      }
    }

    action action5() { }
    action action6() { }
    action action7() { }

    apply {
      t1.apply();
      if (i == 0x11) {
        action5();
        t2.apply();
        action6();
      }
      action4();
      action7();
    }
  }

  control Deparser(packet_out po, in parsed_headers_t parsed_hdr, 
                   out empty_t program_scope_metadata) {
    apply {
      po.emit(parsed_hdr.h1);
      po.emit(parsed_hdr.h2);
    }
  }
}

