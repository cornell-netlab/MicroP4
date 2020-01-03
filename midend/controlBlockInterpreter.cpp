/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "controlBlockInterpreter.h"
#include "frontends/p4/methodInstance.h"
#include "frontends/p4/coreLibrary.h"
#include "composablePackageInterpreter.h"

namespace P4 {


void ControlBlockInterpreter::replicateHdrValidityOpsVec(size_t nfold) {
    auto currSize = xoredHdrValidityOps->size();
    xoredHdrValidityOps->resize(nfold * currSize);
    for (size_t i = 0; i<currSize; i++) {
        auto e = (*xoredHdrValidityOps)[i];
        for (size_t n = 1; n<nfold; n++)
            (*xoredHdrValidityOps)[i+(n*currSize)] = e;
    }
}

void ControlBlockInterpreter::clearCurrOpsRec() {
    currOpsRec.first.clear();
    currOpsRec.second.clear();
}

void ControlBlockInterpreter::insertCurrOpsRecToVecEles(size_t begin, size_t end) {
    for (size_t i = begin; i<end; i++) {
        auto& e = (*xoredHdrValidityOps)[i];
        for (auto hsv : currOpsRec.first)
            e.first.emplace(hsv);
        for (auto hsiv : currOpsRec.second)
            e.second.emplace(hsiv);
    }
}


bool ControlBlockInterpreter::preorder(const IR::P4Control* p4Control) {
    
    xoredHdrValidityOps->push_back(currOpsRec);
    visit(p4Control->body);

    std::vector<size_t> emptyElements;

    bool modified = true;
    bool dup = false;
    while (modified) {
        modified = false;
        auto it = xoredHdrValidityOps->begin();
        for (; it != xoredHdrValidityOps->end(); it++) {
            auto ef = it->first;
            auto es = it->second;
            if (ef.empty() && es.empty()) {
                modified = true;
                break;
            }
        }
        if (modified && dup) {
            xoredHdrValidityOps->erase(it);
        }
        if (modified)
            dup = true;
    }

    return false;
}

bool ControlBlockInterpreter::preorder(const IR::IfStatement* ifStmt) {
    
    size_t currSize = xoredHdrValidityOps->size();
    size_t index = 0;
    insertCurrOpsRecToVecEles(0, currSize);
    clearCurrOpsRec();
    replicateHdrValidityOpsVec(2);

    auto currIncr = maxIncr;
    auto currDecr = maxDecr;
    auto currAccumDecrPktLen = accumDecrPktLen;
  
    visit(ifStmt->ifTrue);
    
    auto trueIncrPktSize = maxIncr;
    auto trueDecrPktSize = maxDecr;
    auto trueAccumDecrPktLen = accumDecrPktLen;
    insertCurrOpsRecToVecEles(index, index+currSize);
    index = index + currSize;

    // resetting for false branch
    clearCurrOpsRec();
    maxIncr = currIncr;
    maxDecr = currDecr;
    accumDecrPktLen = currAccumDecrPktLen;

    visit(ifStmt->ifFalse);
    
    auto falseIncrPktSize = maxIncr;
    auto falseDecrPktSize = maxDecr;
    auto falseAccumDecrPktLen = accumDecrPktLen;
    if (ifStmt->ifFalse != nullptr)
        insertCurrOpsRecToVecEles(index, index+currSize);
    clearCurrOpsRec();

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

    size_t currSize = xoredHdrValidityOps->size();
    size_t index = 0;
    insertCurrOpsRecToVecEles(0, currSize);
    clearCurrOpsRec();
    replicateHdrValidityOpsVec(swStmt->cases.size());

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

        insertCurrOpsRecToVecEles(index, index+currSize);
        index = index + currSize;
        clearCurrOpsRec();
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
                // removeHdrFromXOredHeaderSets(mem->member);
                currOpsRec.first.emplace(mem->member);
            }
            maxIncr += hs;
        } else if (bm->name == IR::Type_Header::setInvalid) {
            maxDecr += hs;
            if (auto mem = exp->to<IR::Member>()) {
                currOpsRec.second.emplace(mem->member);
            }
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

    size_t currSize = xoredHdrValidityOps->size();
    size_t index = 0;
    insertCurrOpsRecToVecEles(0, currSize);
    clearCurrOpsRec();
    replicateHdrValidityOpsVec(al->actionList.size());

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

        insertCurrOpsRecToVecEles(index, index+currSize);
        index = index + currSize;
        clearCurrOpsRec();
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
    ComposablePackageInterpreter cpi(refMap, typeMap, parserStructures, 
                                     hdrValidityOpsPkgMap);
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
