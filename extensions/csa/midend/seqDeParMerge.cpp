/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "seqDeParMerge.h"

namespace CSA {

const IR::Node* SeqDeParMerge::preorder(IR::P4Control* p4control) {
    return p4control;
}

const IR::Node* SeqDeParMerge::postorder(IR::P4Control* p4control) {
    return p4control;
}

const IR::Node* SeqDeParMerge::preorder(IR::P4Parser* p4parser) {
    return p4parser;
}

const IR::Node* SeqDeParMerge::postorder(IR::P4Parser* p4parser) {
    return p4parser;
}

const IR::Node* SeqDeParMerge::preorder(IR::P4ComposablePackage* p4cp) {
    return p4cp;
}

const IR::Node* SeqDeParMerge::postorder(IR::P4ComposablePackage* p4cp) {
    return p4cp;
}


}// namespace CSA
