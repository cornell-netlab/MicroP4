/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */
#include "frontends/p4/methodInstance.h"
#include "deadFieldElimination.h"
#include "msaNameConstants.h"
#include "identifyStorage.h"


namespace CSA {

bool FindModifiedFields::preorder(const IR::AssignmentStatement* asmt) {

    IdentifyStorage isR(refMap, typeMap, 1);
    IdentifyStorage isL(refMap, typeMap, 1);
    asmt->right->apply(isR);
    asmt->left->apply(isL);

    // happens in assignment statements of converted parsers
    if (isR.isMSAHeaderStorage() && !isL.isMSAHeaderStorage()) {
        // Store the instance name in left expression storage in allUserDefinedHdrTypes
        auto instName = isL.getName(1);
        auto type = isL.getType(1);
        auto ts = type->to<IR::Type_StructLike>();
        BUG_CHECK(ts!=nullptr, "expected Type_StructLike in LHS");
        cstring key = ts->name+"."+instName;
        allUDefHdrTypeInst->emplace(key);
        return false;
    }

    if ((!isR.isMSAHeaderStorage() && isL.isMSAHeaderStorage()) ||
        (!isR.isMSAHeaderStorage() && isL.isMSAHeaderStorage()) ) {
        return false;
    }

    if (!isR.isMSAHeaderStorage() && !isL.isMSAHeaderStorage()) {
        auto st = isL.getType(1)->to<IR::Type_StructLike>();
        if (st != nullptr) {
            auto fn1 = isL.getName(1);
            auto fn0 = isL.getName(0);
            cstring key = st->name+"."+fn1;
            auto& fm = (*modHdrTypeInstToFields)[key];
            fm.emplace(fn0);
        }
    }
    return true;
}

bool FindModifiedFields::preorder(const IR::Member* mem) {


    IdentifyStorage is(refMap, typeMap, 1);
    auto ts = is.getType(1)->to<IR::Type_StructLike>();
    if (ts == nullptr)
        return false;
    cstring key = ts->name+"."+is.getName(1);
    auto& fm =  (*accHdrTypeInstToFields)[key];
    fm.emplace(is.getName(0));
    return true;
}

void FindModifiedFields::postorder(const IR::P4Program* program) {

    filterUserDefinedHdrType(modHdrTypeInstToFields);
    filterUserDefinedHdrType(accHdrTypeInstToFields);
    return;
}

void FindModifiedFields::filterUserDefinedHdrType(std::unordered_map<cstring, 
                                            std::unordered_set<cstring>>* map) {
    
     std::vector<cstring> remove;
    for (const auto& e : (*map)) {
        if (allUDefHdrTypeInst->find(e.first) == 
            allUDefHdrTypeInst->end())
            remove.emplace_back(e.first);
    }
    for (auto r : remove)
        map->erase(r);
}

void EntryContext::insert(const IR::P4Action* p4action, 
                         const IR::AssignmentStatement* asmt) {
    auto& asmtSet = markedToDelete[p4action];
    asmtSet.emplace(asmt);
}

EntryContext* TableContext::instantiateEntryContext(const IR::Entry* entry) {
    auto ec = new EntryContext();
    entryCtxtMap[entry] = ec;
    return ec;
}


bool CompareStorageExp::preorder(const IR::ArrayIndex* ai) {
    return true;
}

bool CompareStorageExp::preorder(const IR::Member* member) {
    return true;
}

bool CompareStorageExp::preorder(const IR::PathExpression* pe) {
    return true;
}

bool ApplyDepActCSTR::preorder(const IR::P4Control* p4control) {
    visit(p4control->controlLocals);
    return false;
}

bool ApplyDepActCSTR::preorder(const IR::P4Table* p4table) {
    currTblCtxt = new TableContext();
    tblCtxtMap[p4table] = currTblCtxt;
    return true;
}

void ApplyDepActCSTR::postorder(const IR::P4Table* p4table) {
    // check on table context
}

bool ApplyDepActCSTR::preorder(const IR::Entry* entry) {
    insertEntryInCurrTblCtxt(entry);
    visit(entry->action);
    return false;
}

bool ApplyDepActCSTR::preorder(const IR::MethodCallExpression* mce) {
    
    auto mi = P4::MethodInstance::resolve(mce, refMap, typeMap);
    if (auto ac = mi->to<P4::ActionCall>())
        visit(ac->action);
    return false;
}

bool ApplyDepActCSTR::preorder(const IR::P4Action* p4action) {
    return true;
}

bool ApplyDepActCSTR::preorder(const IR::BlockStatement* bs) {
    auto p4action = findContext<IR::P4Action>();
    if (p4action == nullptr)
        return false;
    auto it = bs->components.rbegin();
    for (; it != bs->components.rend(); ++it) {
        visit(*it);
    }
    return false;
}

bool ApplyDepActCSTR::preorder(const IR::AssignmentStatement* asmt) {
    auto p4action = findContext<IR::P4Action>();
    if (p4action == nullptr)
        return false;

    IdentifyStorage isR(refMap, typeMap, 1);
    IdentifyStorage isL(refMap, typeMap, 1);
    asmt->right->apply(isR);
    asmt->left->apply(isL);
    if (isL.isMSAHeaderStorage() && !(isR.isMSAHeaderStorage())) {
        auto instName = isR.getName(1);
        auto type = isR.getType(1);
        auto ts = type->to<IR::Type_StructLike>();
        BUG_CHECK(ts!=nullptr, "expected Type_StructLike in RHS");
        auto fieldName = isR.getName(0);
        cstring key = ts->name+"."+instName;
        auto it = modHdrTyInFns->find(key);
        if (it != modHdrTyInFns->end() && 
            it->second.find(fieldName) != it->second.end()) { 
            delWritesOn.push_back(asmt->left);
        } else {
            // RHS is not modified, therefore it is safe to delete write-back
            // assignment statement in deparser
            currEntCtxt->insert(p4action, asmt);
        }
    }

    if (isL.isMSAHeaderStorage() && isR.isMSAHeaderStorage()) {
        bool res;
        CompareStorageExp cse(refMap, typeMap, asmt->left);
        for (auto dwo : delWritesOn) {
            // compare dwo with asmt->left
            // // if they match store asmt in currEntCtxt for delete
            dwo->apply(cse);
            if (cse.isMatch()) 
                currEntCtxt->insert(p4action, asmt);
        }
    }

    return false;
}

void ApplyDepActCSTR::insertEntryInCurrTblCtxt(const IR::Entry* entry) {
    currEntCtxt = currTblCtxt->instantiateEntryContext(entry);
}


}// namespace CSA
