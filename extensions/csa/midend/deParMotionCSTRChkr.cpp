/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "deParMotionCSTRChkr.h"

namespace CSA {

Visitor::profile_t DeParMotionCSTRChkr::init_apply(const IR::Node* node) { 
    BUG_CHECK(node->is<IR::P4Program>(), 
                "%1%: expected a P4Program node", node);
    return Inspector::init_apply(node);
}

bool DeParMotionCSTRChkr::preorder(const IR::P4Program* p4Program) {
    return false;
}


bool DeParMotionCSTRChkr::preorder(const IR::P4ComposablePackage* p4cp) {
    return false;
}

}
