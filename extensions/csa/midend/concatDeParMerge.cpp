/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "concatDeParMerge.h"

namespace CSA {

const IR::Node* ConcatDeParMerge::preorder(IR::P4Control* p4control) {
    return p4control;
}

const IR::Node* ConcatDeParMerge::postorder(IR::P4Control* p4control) {
    return p4control;
}

const IR::Node* ConcatDeParMerge::preorder(IR::P4Parser* p4parser) {
    return p4parser;
}

const IR::Node* ConcatDeParMerge::postorder(IR::P4Parser* p4parser) {
    return p4parser;
}

const IR::Node* ConcatDeParMerge::preorder(IR::P4ComposablePackage* p4cp) {
    return p4cp;
}

const IR::Node* ConcatDeParMerge::postorder(IR::P4ComposablePackage* p4cp) {
    return p4cp;
}


}// namespace CSA
