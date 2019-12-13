/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "staticAnalyzer.h"
#include "midend/parserUnroll.h"
#include "midend/composablePackageInterpreter.h"  


namespace CSA {

Visitor::profile_t StaticAnalyzer::init_apply(const IR::Node* node) { 
    BUG_CHECK(node->is<IR::P4Program>(), 
                "%1%: expected a P4Program node", node);
    return Inspector::init_apply(node);
}


bool StaticAnalyzer::preorder(const IR::P4Program* p4Program) {
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

    auto p4cp = type->to<IR::P4ComposablePackage>();
    *mainPackageTypeName = p4cp->getName();
    visit(p4cp);
    return false;
}


bool StaticAnalyzer::preorder(const IR::P4ComposablePackage* p4cp) {

    P4::ComposablePackageInterpreter cpi(refMap, typeMap, parserStructures);
    p4cp->apply(cpi);

    *maxExtLen = cpi.getMaxExtLen();
    *byteStackSize = *maxExtLen + cpi.getMaxIncrPktLen();

    std::cout<<"staticAnalyzer : Max extract length: "<<(*maxExtLen)/8<<"\n";
    std::cout<<"staticAnalyzer : Byte Stack Size: "<<(*byteStackSize)/8<<"\n";
    return false;
}

}
