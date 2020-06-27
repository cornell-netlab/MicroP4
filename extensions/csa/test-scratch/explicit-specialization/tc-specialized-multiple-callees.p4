struct  I_t {
    bit<8> id;
}

struct  A_t {
    bit<48> ad;
}

cpackage CalleePackage(in I_t ii)();

cpackage Interface<IV, HV, SV>(in IV i)() {

    @optional
    cpackage Exec<CEV, AV>(out AV ai, inout HV hi)(CEV cevi);

    control P1(in IV ii, inout HV hi);
    control P2(out HV hi, inout SV si);
}

// Moving headers and structs outside, because we want to give them as type
// parameters in interface.
struct  H_t {
    bit<16> hd;
}

struct  S_t {
    bit<32> sd;
}

cpackage Impl : implements Interface<I_t, H_t, S_t> {

  control P1(in I_t it, inout H_t ht) {
    
    A_t at;
    CalleePackage() callee_inst_a;
    CalleePackage() callee_inst_b;
    Exec(callee_inst_a) callee_exec_a;
    Exec(callee_inst_b) callee_exec_b;

    apply {
        callee_exec_a.apply(at, ht);
        callee_exec_b.apply(at, ht);
    }
  }

  control P2(out H_t ht, inout S_t st) {
    apply {
    }
  }
}

Impl() main;
