/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "frontends/p4/methodInstance.h"
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

const IR::Node* DeParMerge::preorder(IR::IfStatement* ifstmt) {

    auto currCallees = callees;
    bool currDeParMotion = deParMotion;
    deParMotion = false;
    callees.clear();
    visit(ifstmt->ifTrue);
    bool ifDeParMotion = deParMotion;
    auto ifCallees = callees;

    callees.clear();
    visit(ifstmt->ifFalse);
    bool elseDeParMotion = deParMotion;
    auto elseCallees = callees;

    if (!ifDeParMotion && !elseDeParMotion) {
        if ((elseCallees.size()!=0) || (ifCallees.size()!=0)) {
            deParMotion = true;
            // parallel Composition
        }
    }

    return ifstmt;
}

const IR::Node* DeParMerge::postorder(IR::IfStatement* ifstmt) {
    return ifstmt;
}

const IR::Node* DeParMerge::preorder(IR::BlockStatement* bs) {
    auto currCallees = callees;
    bool currDeParMotion = deParMotion;
    callees.clear();
    for (auto s : bs->components) {
        visit(s);
    }
    if (deParMotion)
        return bs;
    if (callees.size() > 1) {
        deParMotion = true;
        // Sequential composition
    }
    return bs;

}
const IR::Node* DeParMerge::postorder(IR::BlockStatement* bs) {
    return bs;
}


const IR::Node* DeParMerge::preorder(IR::MethodCallStatement* mcs) {
    auto mi = P4::MethodInstance::resolve(mcs->methodCall, refMap, typeMap);
    if (mi->isApply()) {
        auto a = mi->to<P4::ApplyMethod>();
        if (auto di = a->object->to<IR::Declaration_Instance>()) {
            auto inst = P4::Instantiation::resolve(di, refMap, typeMap);
            if (auto p4cpi = inst->to<P4::P4ComposablePackageInstantiation>()) 
                callees.push_back(p4cpi->p4ComposablePackage);
            if (auto pi = inst->to<P4::ParserInstantiation>()) 
                callees.push_back(pi->parser);
            if (auto ci = inst->to<P4::ControlInstantiation>())  {
                if (isDeparser(ci->control)) 
                  callees.push_back(ci->control);
            }
        }
    }
    return mcs;
}

bool DeParMerge::isDeparser(const IR::P4Control* p4control) {
    auto params = p4control->getApplyParameters();
    for (auto param : params->parameters) {
        auto type = typeMap->getType(param, true);
        CHECK_NULL(type);
        if (type->is<IR::Type_Extern>()) {
            auto te = type->to<IR::Type_Extern>();
            if (te->name.name == P4::P4CoreLibrary::instance.emitter.name) {
                // std::cout<<te<<"\n";
                return true;
            }
        }
    }
    return false;
}


}// namespace CSA
