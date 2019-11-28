/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "controlBlockInterpreter.h"
#include "frontends/p4/methodInstance.h"
#include "frontends/p4/coreLibrary.h"
#include "composablePackageInterpreter.h"

namespace P4 {


bool ControlBlockInterpreter::preorder(const IR::P4Control* p4Control) {
    
    return true;
}

bool ControlBlockInterpreter::preorder(const IR::SwitchStatement* swStmt) {

    return true;
}

bool ControlBlockInterpreter::preorder(const IR::IfStatement* ifStmt) {
    
    return true;
}

bool ControlBlockInterpreter::preorder(const IR::MethodCallExpression* mce) {
    return true;
}

bool ControlBlockInterpreter::preorder(const IR::P4Action* p4Control) {
    return true;
}

bool ControlBlockInterpreter::preorder(const IR::P4Table* p4Table) {
    return true;
}

bool ControlBlockInterpreter::preorder(const IR::ActionList* actionList) {
    return true;
}

bool ControlBlockInterpreter::preorder(const IR::P4ComposablePackage* p4cp) {
    return true;
}


}  // namespace P4
