/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "deParMotion.h"


namespace CSA {

const IR::Node* DeParMerge::preorder(IR::P4Control* p4control) {
    return p4control;
}

const IR::Node* DeParMerge::postorder(IR::P4Control* p4control) {
    return p4control;
}

const IR::Node* DeParMerge::preorder(IR::P4Parser* p4parser) {
    return p4parser;
}

const IR::Node* DeParMerge::postorder(IR::P4Parser* p4parser) {
    return p4parser;
}

const IR::Node* DeParMerge::preorder(IR::P4ComposablePackage* p4cp) {
    return p4cp;
}

const IR::Node* DeParMerge::postorder(IR::P4ComposablePackage* p4cp) {
    return p4cp;
}


}// namespace CSA
