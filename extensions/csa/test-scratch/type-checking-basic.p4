// #include <core.p4>


struct  I_t {
    bit<8> id;
}

cpackage Interface<IV, HV, SV>(in IV i)() {

    control P1(in IV ii, inout HV hi);
    control P2(out HV hi, inout SV si);
}

cpackage Impl : implements Interface {

  struct  H_t {
      bit<16> hd;
  }

  struct  S_t {
      bit<32> sd;
  }
  
  control P1(in I_t it, inout H_t ht) {
    apply { }
  }

  control P2(out H_t ht, inout S_t st) {
    apply { }
  }
}

Impl() main;
