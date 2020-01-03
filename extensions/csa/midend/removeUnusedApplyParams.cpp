/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "removeUnusedApplyParams.h"

namespace CSA {

const IR::Node* RemoveUnusedApplyParams::preorder(IR::Parameter* param) { 
    return param;
}

const IR::Node* RemoveUnusedApplyParams::preorder(IR::MethodCallExpression* mce) {
    return mce;
}
    
const IR::Node* RemoveUnusedApplyParams::preorder(IR::P4Control* p4control) {
    if (skipDecl->find(p4control->name) != p4control.end())
        return p4control;

    return p4control;
}

const IR::Node* RemoveUnusedApplyParams::preorder(IR::Type_Control* tc) {
    return tc
}

const IR::Node* RemoveUnusedApplyParams::preorder(IR::ParameterList* pl) {
    return pl;
}

}// namespace CSA
