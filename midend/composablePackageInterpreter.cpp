/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "composablePackageInterpreter.h"
#include "frontends/p4/methodInstance.h"
#include "frontends/p4/coreLibrary.h"
#include "controlBlockInterpreter.h"

namespace P4 {


bool ComposablePackageInterpreter::preorder(const IR::P4Program* p4Program) {
    auto mainDecls = p4Program->getDeclsByName(IR::P4Program::main)->toVector();

    if (mainDecls->size() != 1)
        return p4Program;

    auto main = mainDecls->at(0);
    auto mainDeclInst = main->to<IR::Declaration_Instance>();
    if (mainDeclInst == nullptr)
        return p4Program;

    auto type = typeMap->getType(mainDeclInst);
    BUG_CHECK(type!=nullptr && type->is<IR::P4ComposablePackage>(), 
        "could not find type of main package");

    visit(type);

    return false;
}


bool ComposablePackageInterpreter::preorder(const IR::P4Control* p4Control) {
    return true;
}


bool ComposablePackageInterpreter::preorder(const IR::P4Parser* p4Parser) {
    return true;
}


bool ComposablePackageInterpreter::preorder(const IR::P4ComposablePackage* p4cp) {
    
    auto mpid = p4cp->packageLocals->getDeclaration("micro_parser");
    if (mpid != nullptr) {
        auto mp = mpid->to<IR::P4Parser>();
        if (mp) 
            visit(mp);
    }

    auto mcid = p4cp->packageLocals->getDeclaration("micro_control");
    CHECK_NULL(mcid);
    auto mc = mcid->to<IR::P4Control>();
    if (mc) 
        visit(mc);


    auto mdid = p4cp->packageLocals->getDeclaration("micro_deparser");
    if (mdid != nullptr) {
        auto md = mdid->to<IR::P4Control>();
        if (md) 
            visit(md);
    }
    return false;
}


}  // namespace P4
