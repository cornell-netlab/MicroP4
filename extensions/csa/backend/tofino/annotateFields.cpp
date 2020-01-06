/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */
#include "annotateFields.h"

namespace CSA {

const IR::Node* AnnotateFields::preorder(IR::AssignmentStatement* asmt) {
    return asmt;
}
    
}// namespace CSA
