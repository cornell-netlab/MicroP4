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
    
    visit(p4Control->body);
    return false;
}

bool ControlBlockInterpreter::preorder(const IR::IfStatement* ifStmt) {
    
    auto currIncr = maxIncr;
    auto currDecr = maxDecr;

    auto currAccumDecrPktLen = accumDecrPktLen;
    visit(ifStmt->ifTrue);
    auto trueIncrPktSize = maxIncr;
    auto trueDecrPktSize = maxDecr;
    auto trueAccumDecrPktLen = accumDecrPktLen;
    
    // resetting for false branch
    maxIncr = currIncr;
    maxDecr = currDecr;
    accumDecrPktLen = currAccumDecrPktLen;

    visit(ifStmt->ifFalse);
    auto falseIncrPktSize = maxIncr;
    auto falseDecrPktSize = maxDecr;
    auto falseAccumDecrPktLen = accumDecrPktLen;

    if (trueIncrPktSize > falseIncrPktSize)
        maxIncr = trueIncrPktSize;
    else
        maxIncr = falseIncrPktSize;

    if (trueDecrPktSize > falseDecrPktSize)
        maxDecr = trueDecrPktSize;
    else
        maxDecr = falseDecrPktSize;

    if (trueAccumDecrPktLen > falseAccumDecrPktLen)
        accumDecrPktLen = trueAccumDecrPktLen;
    else
        accumDecrPktLen = falseAccumDecrPktLen;

    return false;
}

bool ControlBlockInterpreter::preorder(const IR::SwitchStatement* swStmt) {

    auto localMaxIncr = maxIncr;
    auto localMaxDecr = maxDecr;
    auto localMaxAccumDecrPktLen = accumDecrPktLen;

    auto currIncr = maxIncr;
    auto currDecr = maxDecr;
    auto currAccumDecrPktLen = accumDecrPktLen;

    for (auto switchCase : swStmt->cases) {
        visit(switchCase);
        if (localMaxIncr < maxIncr)
            localMaxIncr = maxIncr;
        if (localMaxDecr < maxDecr)
            localMaxDecr = maxDecr;
        if (localMaxAccumDecrPktLen < accumDecrPktLen)
            localMaxAccumDecrPktLen = accumDecrPktLen;

        accumDecrPktLen = currAccumDecrPktLen;
        maxIncr = currIncr;
        maxDecr = currDecr;
    }
    maxIncr = localMaxIncr;
    maxDecr = localMaxDecr;
    accumDecrPktLen = localMaxAccumDecrPktLen;
    return false;
}

bool ControlBlockInterpreter::preorder(const IR::SwitchCase* switchCase) {
    visit(switchCase->statement);
    return false;
}

bool ControlBlockInterpreter::preorder(const IR::MethodCallExpression* mce) {

    auto mi = P4::MethodInstance::resolve(mce, refMap, typeMap);

    if (mi->is<P4::ApplyMethod>()) {
        auto am = mi->to<P4::ApplyMethod>();
        if (am->isTableApply()) {
            auto p4Table = am->object->to<IR::P4Table>();
            // std::cout<<"Apply call to P4Table : "<<p4Table->getName()<<"\n";
            visit(p4Table);
        }
        if (auto di = am->object->to<IR::Declaration_Instance>()) {
            auto inst = P4::Instantiation::resolve(di, refMap, typeMap);
            if (auto cpi = inst->to<P4::P4ComposablePackageInstantiation>()) {
                auto cpt = cpi->p4ComposablePackage;
                // std::cout<<"Apply call to Package : "<<cpt->getName()<<"\n";
                visit(cpt);
            }
        }
    }
    if (mi->is<P4::ActionCall>()) {
        auto ac = mi->to<P4::ActionCall>();
        // std::cout<<"Call to P4Action : "<<ac->action->getName()<<"\n";
        visit(ac->action);
    }
    if (mi->is<P4::BuiltInMethod>()) {
        auto bm = mi->to<P4::BuiltInMethod>();
        auto exp = bm->appliedTo;
        auto basetype = typeMap->getType(exp);
        BUG_CHECK(basetype->is<IR::Type_Header>(), "only HeaderType expected");
        auto th = basetype->to<IR::Type_Header>();
        unsigned hs =  factory->getWidth(th);
        // std::cout<<"Header size:"<<hs<<"\n";
        if (bm->name == IR::Type_Header::setValid) {
            if (auto mem = exp->to<IR::Member>()) {
                // std::cout<<mem->member<<"\n";
                removeHdrFromXOredHeaderSets(mem->member);
            }
            maxIncr += hs;
        } else if (bm->name == IR::Type_Header::setInvalid) {
            maxDecr += hs;
        } else {
            return false;
        }
    }
    return false;
}

bool ControlBlockInterpreter::preorder(const IR::P4Table* p4Table) {
    auto al = p4Table->getActionList();
    visit(al);
    return false;
}

bool ControlBlockInterpreter::preorder(const IR::ActionList* al) {

    auto localMaxIncr = maxIncr;
    auto localMaxDecr = maxDecr;

    auto currIncr = maxIncr;
    auto currDecr = maxDecr;
    for (auto ale : al->actionList) {
        visit(ale);
        if (localMaxIncr < maxIncr)
            localMaxIncr = maxIncr;
        if (localMaxDecr < maxDecr)
            localMaxDecr = maxDecr;
        maxIncr = currIncr;
        maxDecr = currDecr;
    }
    maxIncr = localMaxIncr;
    maxDecr = localMaxDecr;
    return false;
}

bool ControlBlockInterpreter::preorder(const IR::ActionListElement* ale) {
    visit(ale->expression);
    return false;
}

bool ControlBlockInterpreter::preorder(const IR::P4Action* p4action) {
    visit(p4action->body);
    return false;
}

bool ControlBlockInterpreter::preorder(const IR::P4ComposablePackage* p4cp) {
    ComposablePackageInterpreter cpi(refMap, typeMap, parserStructures);
    p4cp->apply(cpi);
    maxIncr += cpi.getMaxIncrPktLen();
    maxDecr += cpi.getMaxDecrPktLen();

    auto currMaxExtLen = accumDecrPktLen + cpi.getMaxExtLen();
    if (maxExtLen < currMaxExtLen)
        maxExtLen = currMaxExtLen;

    accumDecrPktLen += cpi.getMaxDecrPktLen();
    return false;
}


void ControlBlockInterpreter::removeHdrFromXOredHeaderSets(cstring hdrInstName) {
    
    if (parserStructure == nullptr)
        return;
    for (auto& s: *(parserStructure->xoredHeaderSets)) {
        auto it = s.find(hdrInstName);
        if (it != s.end())
            s.erase(it);
    }
}
}  // namespace P4
