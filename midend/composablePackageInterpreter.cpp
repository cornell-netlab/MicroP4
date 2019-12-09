/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "composablePackageInterpreter.h"
#include "frontends/p4/methodInstance.h"
#include "frontends/p4/coreLibrary.h"
#include "controlBlockInterpreter.h"
#include "parserUnroll.h"

namespace P4 {

Visitor::profile_t ComposablePackageInterpreter::init_apply(const IR::Node* node) { 
    BUG_CHECK(node->is<IR::P4ComposablePackage>(), 
                "%1%: expected a P4ComposablePackage", node);
    return Inspector::init_apply(node);
}


bool ComposablePackageInterpreter::preorder(const IR::P4ComposablePackage* p4cp) {
    
    p4cpCallStack.push_back(p4cp->getName());

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

    /*
    auto mdid = p4cp->packageLocals->getDeclaration("micro_deparser");
    if (mdid != nullptr) {
        auto md = mdid->to<IR::P4Control>();
        if (md) 
            visit(md);
    }
    */
    p4cpCallStack.pop_back();
    return false;
}


bool ComposablePackageInterpreter::preorder(const IR::P4Parser* parser) {

    /*
    auto parserStructure = new P4::ParserStructure();
    ParserRewriter rewriter(refMap, typeMap, true, parserStructure);
    parser->apply(rewriter);

    cstring parser_fqn = parser->getName();
    parser_fqn = p4cpCallStack.back() +"_"+ parser->getName();

    parserStructures->emplace(parser_fqn, parserStructure);
    */
    cstring parser_fqn = p4cpCallStack.back() +"_"+ parser->getName();
    auto iter = parserStructures->find(parser_fqn);
    BUG_CHECK(iter != parserStructures->end(), "parser %1% is not evaluated", 
                                                parser->getName());
    auto parserStructure = iter->second;
    maxExtLen = parserStructure->result->getPktMaxOffset();

    std::cout<<parser_fqn<<" maxExtLen "<<maxExtLen/8<<"\n";
    return false;
}


bool ComposablePackageInterpreter::preorder(const IR::P4Control* p4Control) {

    ControlBlockInterpreter cbi(refMap, typeMap, parserStructures);
    p4Control->apply(cbi);
    maxExtLen += cbi.getMaxExtLen();

    cstring control_fqn = p4cpCallStack.back() +"_"+ p4Control->getName();
    std::cout<<control_fqn<<" maxExtLen "<<maxExtLen/8<<"\n";

    maxIncrPktLen = cbi.getMaxIncrPktLen();
    maxDecrPktLen = cbi.getMaxDecrPktLen();
    return false;
}

}  // namespace P4
