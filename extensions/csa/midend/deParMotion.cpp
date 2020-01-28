/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "frontends/p4/methodInstance.h"
#include "deParMotion.h"

namespace CSA {

const IR::Node* DeParMerge::preorder(IR::P4Control* p4control) {

    deParMotion = false;
    callees.clear();
    visit(p4control->body);

    prune();
    return p4control;
}

const IR::Node* DeParMerge::preorder(IR::P4ComposablePackage* p4cp) {

    deParMotion = false;
    callees.clear();
    visit(p4cp->packageLocals);

    if (!deParMotion) {
        if(!hasMultipleParsers(callees)) {
            auto calleeP4CP = getCallee<IR::P4ComposablePackage>(callees);
            if (calleeP4CP != nullptr)  {
                // concat calleeP4CP
            } else {
                auto p4parser = getCallee<IR::P4Parser>(callees);
                auto p4deparser = getCallee<IR::P4Control>(callees);
                if (p4parser!=nullptr && p4deparser!=nullptr) {
                    // concate p4parser, p4deparser with current p4cp
                }
            }
        } else {
            BUG("Unexpected scenario ");
        }
    }

    return p4cp;
}

const IR::Node* DeParMerge::postorder(IR::P4ComposablePackage* p4cp) {
    return p4cp;
}

const IR::Node* DeParMerge::preorder(IR::IfStatement* ifstmt) {

    auto currCallees = callees;
    bool finalDeParMotion = deParMotion;
    deParMotion = false;
    callees.clear();
    visit(ifstmt->ifTrue);
    bool ifDeParMotion = deParMotion;
    auto ifCallees = callees;
    if (ifDeParMotion == true)
        finalDeParMotion = true;

    callees.clear();
    visit(ifstmt->ifFalse);
    bool elseDeParMotion = deParMotion;
    auto elseCallees = callees;
    if (elseDeParMotion == true)
        finalDeParMotion = true;

    deParMotion = finalDeParMotion;
    if (!deParMotion) {
        if (!hasMultipleParsers(ifCallees) && !hasMultipleParsers(elseCallees)) {
            deParMotion = true;
            // parallel Composition
        } else {
            BUG("multiple parser-deparser, not expected here ");
        }
    }

    return ifstmt;
}

const IR::Node* DeParMerge::postorder(IR::IfStatement* ifstmt) {
    return ifstmt;
}

const IR::Node* DeParMerge::preorder(IR::BlockStatement* bs) {
    auto currCallees = callees;
    bool finalDeParMotion = deParMotion;
    callees.clear();
    for (auto s : bs->components) {
        deParMotion = false;
        visit(s);
        if (deParMotion == true) //  && !s->is<IR::BlockStatement>()
            finalDeParMotion = true;
    }

    deParMotion = finalDeParMotion;
    if (deParMotion) {
        callees = currCallees;
        return bs;
    }
    if (!hasMultipleParsers(callees)) {
        deParMotion = true;
        // Sequential composition
        callees.clear();
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

bool DeParMerge::hasMultipleParsers(const IR::IndexedVector<IR::Type_Declaration>& cs) {
    unsigned short count = 0;
    for (auto td : cs) {
        if (td->is<IR::P4Parser>() || td->is<IR::P4ComposablePackage>())
            count++;
        if (count > 1)
            return true;
    }
    return false;
}

template<typename T> const T* 
DeParMerge::getCallee(const IR::IndexedVector<IR::Type_Declaration>& cs)  {
    unsigned short count = 0;
    const T* typeDecl = nullptr;
    for (auto td : cs) {
        if (td->is<T>()) {
            typeDecl = td->to<T>();
            count++;
        }
    }
    BUG_CHECK(count <=1, "maximum one parser is expected in the callee list");
    return typeDecl;
}


}// namespace CSA
