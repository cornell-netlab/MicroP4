/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

struct empty_t { }

cpackage Callee0 (pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout bit<8> l4proto);
cpackage Callee1 (pkt p, im_t im, in empty_t ia, out empty_t oa, 
                 inout empty_t ioa);

