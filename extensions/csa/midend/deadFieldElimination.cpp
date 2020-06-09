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
    // std::cout<<"  --- AssignmentStatement "<<asmt<<"\n";
    return true;
}

bool FindModifiedFields::preorder(const IR::Member* mem) {

    // std::cout<<"  --- member "<<mem<<"\n";
    IdentifyStorage is(refMap, typeMap, 1);
    mem->apply(is);
    auto type = is.getType(1);
    if (type == nullptr)
        return false;
    auto ts = type->to<IR::Type_StructLike>();
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

    /*
    std::cout<<"--- allUDefHdrTypeInst ---\n";
    for (auto hti : *allUDefHdrTypeInst)
        std::cout<<hti<<"\n";
    std::cout<<"--------------------------\n";
    std::cout<<"--- modHdrTypeInstToFields ---\n";
    printHdrTypeInstToFields(modHdrTypeInstToFields);
    std::cout<<"--------------------------\n";
    std::cout<<"--- accHdrTypeInstToFields ---\n";
    printHdrTypeInstToFields(accHdrTypeInstToFields);
    std::cout<<"--------------------------\n";
    */
    return;

}

void FindModifiedFields::printHdrTypeInstToFields(
    std::unordered_map<cstring, std::unordered_set<cstring>>* mapSet) {
    for (auto e : *mapSet) {
        std::cout<<e.first<<" --> [";
        for (auto f : e.second)
            std::cout<<f<<" ";
        std::cout<<"] \n";
    }
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

/*
 * Returns true, if calls to a common action in both `ec` and `this` 
 * EntryContext are deleting different Assignment statements.
 * Else false.
 */
bool EntryContext::diffDelAsStmt(EntryContext* ec) {
    for (auto e1 : markedToDelete) {
        auto it = ec->markedToDelete.find(e1.first);
        if (it != ec->markedToDelete.end()) {
            auto& s1 = e1.second;
            auto& ecs = it->second;
            if (ecs.size() != s1.size())
                return true;
            for (auto eas : ecs) {
                if (s1.find(eas) == s1.end())
                    return true;
            }
        }
    }
    return false;
}


bool EntryContext::exists(const IR::P4Action* act, const IR::AssignmentStatement* asmt) {
    auto it = markedToDelete.find(act);
    if (it == markedToDelete.end())
        return false;

    auto iter = it->second.find(asmt);
    if (iter != it->second.end())
        return true;
    return false;
}

EntryContext* TableContext::instantiateEntryContext(const IR::Entry* entry) {
    auto ec = new EntryContext();
    entryCtxtMap[entry] = ec;
    return ec;
}

bool TableContext::canEliminateDeadField() {
    auto it1 = entryCtxtMap.cbegin();
    for (short i = 0; it1 != entryCtxtMap.cend(); it1++, i++) {
        auto it2 = std::next(entryCtxtMap.cbegin(), i);
        for ( ; it2 !=entryCtxtMap.end(); it2++) {
            if (it1->second->diffDelAsStmt(it2->second))
                return false;
        }
    }
    return true;
}

bool TableContext::exists(const IR::P4Action* act, const IR::AssignmentStatement* asmt) {
    bool res = false;
    for (const auto& e : entryCtxtMap) {
        if (e.second->exists(act, asmt))
            return true;
    }
    return false;
}


bool CommonStorageSubExp::preorder(const IR::Member* member) {
    
    IdentifyStorage is(refMap, typeMap, 1);
    member->apply(is);
    if (!is.isMSAHeaderStorage()) {
        auto instName = is.getName(1);
        auto type = is.getType(1);
        if (type == nullptr)
            return false;
        auto ts = type->to<IR::Type_StructLike>();
        if (ts == nullptr)
            return false;
        auto fieldName = is.getName(0);
        cstring key = ts->name+"."+instName;
        // std::cout<<" key : "<<key<<"\n";
        auto it = modHdrTyInFns->find(key);
        if (it != modHdrTyInFns->end() && 
            it->second.find(fieldName) != it->second.end()) {
            result = true;
        }
    }
    return false;
}

bool CommonStorageSubExp::preorder(const IR::Concat* c) {
    visit(c->left);
    if (!result)
        visit(c->right);
    return false;
}

bool CompareStorageExpLocal::preorder(const IR::ArrayIndex* ai) {
    auto ca = curr->to<IR::ArrayIndex>();
    if (ca == nullptr) {
        result = false;
        return false;
    }
    curr = ca->left;
    visit(ai->left);
    curr = ca->right;
    visit(ai->right);
    return false;
}

bool CompareStorageExpLocal::preorder(const IR::Member* mem) {
    auto cm = curr->to<IR::Member>();
    if (cm == nullptr) {
        result = false;
        return false;
    }

    auto tm = typeMap->getType(mem);
    auto tc = typeMap->getType(curr);

    /*
    if (tm == tc) { 
        std::cout<<tm<<"\n";
        std::cout<<tc<<"\n";
    }
    */

    if (mem->member != cm->member) {
        result = false;
        return false;
    }
    curr = cm->expr;
    visit(mem->expr);
    return false;
}

bool CompareStorageExpLocal::preorder(const IR::PathExpression* pe) {
    auto cpe = curr->to<IR::PathExpression>();
    if (cpe == nullptr) {
        result = false;
        return false;
    }
    if (pe->path->name != cpe->path->name) {
        result = false;
        return false;
    }
    return false;
}

bool CompareStorageExpLocal::preorder(const IR::Constant* c) {
    
    auto cc = curr->to<IR::Constant>();
    if (cc == nullptr) {
        result = false;
        return false;
    }

    if (c->asUnsigned() != cc->asUnsigned()) {
        result = false;
        return false;
    }
    return false;
}

bool ApplyDepActCSTR::preorder(const IR::P4Control* p4control) {
    // std::cout<<"visiting P4Control name : "<<p4control->name<<"\n";
    for (auto c : p4control->controlLocals) {
        if (c->is<IR::P4Table>())
            visit(c);
    }
    return false;
}


bool ApplyDepActCSTR::preorder(const IR::P4Table* p4table) {
    // std::cout<<"visiting table name : "<<p4table->name<<"\n";
    currTblCtxt = new TableContext();
    (*tblCtxtMap)[p4table] = currTblCtxt;
    auto es = p4table->getEntries();
    if (es == nullptr)
        return false;
    for (auto e : es->entries)
        visit(e);
        
    auto c = findContext<IR::P4Control>();
    if (!currTblCtxt->canEliminateDeadField()) {
        ;
        // std::cout<<"---can not perform DeadFieldElimination in "<<c->name
        //   <<" "<<p4table->name<<" \n";
    } else {
        ;
        // std::cout<<"--- can perform DeadFieldElimination in "<<c->name
        //   <<" "<<p4table->name<<" \n";
    }
    return false;
}


bool ApplyDepActCSTR::preorder(const IR::Entry* entry) {
    // std::cout<<"------------------ Entry : "<<entry<<"---------------\n";
    delWritesOn.clear();
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

    // std::cout<<"ApplyDepActCSTR action name:  "<<p4action->name<<"\n";
    // std::cout<<"ApplyDepActCSTR :  "<<asmt<<"\n";
    IdentifyStorage isR(refMap, typeMap, 1);
    IdentifyStorage isL(refMap, typeMap, 1);
    asmt->right->apply(isR);
    asmt->left->apply(isL);

    if(isL.isMSAHeaderStorage() && !(isR.isMSAHeaderStorage())) {
        CommonStorageSubExp css(refMap, typeMap, modHdrTyInFns);
        asmt->right->apply(css);
        if(css.has()) {
            // std::cout<<"Delete any more writes on : "<<asmt->left;
            // std::cout<<" : "<<p4action->name<<"\n";
            delWritesOn.push_back(asmt->left);
        } else {
            // RHS is not modified, therefore it is safe to delete write-back
            // assignment statement in deparser
            currEntCtxt->insert(p4action, asmt);
            // std::cout<<"storing in currEntCtxt to delete: "<<asmt<<"\n";
        }
            
    }

    if (isL.isMSAHeaderStorage() && isR.isMSAHeaderStorage()) {
        // std::cout<<" Second if : \n";
        bool res;
        CompareStorageExpLocal cse(refMap, typeMap, asmt->left);
        for (auto dwo : delWritesOn) {
            // compare dwo with asmt->left
            // // if they match store asmt in currEntCtxt to delete
            dwo->apply(cse);
            if (cse.isMatch()) {
                currEntCtxt->insert(p4action, asmt);
                // std::cout<<"to del - "<<asmt;
                // std::cout<<"-- in action - "<<p4action->name<<"\n";
            }
        }
    }

    return false;
}

void ApplyDepActCSTR::insertEntryInCurrTblCtxt(const IR::Entry* entry) {
    currEntCtxt = currTblCtxt->instantiateEntryContext(entry);
}

const IR::Node* RemoveWritebacks::preorder(IR::P4Action* p4action) {
    origP4ActionPtr = getOriginal()->to<IR::P4Action>(); 
    return p4action;
}

const IR::Node* RemoveWritebacks::preorder(IR::AssignmentStatement* asmt) {
    auto act = findContext<IR::P4Action>();
    if (act == nullptr)
        return asmt;
    auto orig = getOriginal()->to<IR::AssignmentStatement>();
    for (const auto& tt : (*tblCtxtMap))
    if (tt.second->exists(origP4ActionPtr, orig))
        return nullptr;
    return asmt;
}


}// namespace CSA
