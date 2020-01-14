/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_LINKER_DEADFIELDELIMINATION_H_ 
#define _EXTENSIONS_CSA_LINKER_DEADFIELDELIMINATION_H_ 

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"

namespace CSA {

class FindModifiedFields final : public Inspector {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

    std::unordered_set<cstring>* allUDefHdrTypeInst;
    std::unordered_map<cstring, std::unordered_set<cstring>>* modHdrTypeInstToFields;
    std::unordered_map<cstring, std::unordered_set<cstring>>* accHdrTypeInstToFields;

    void filterUserDefinedHdrType(std::unordered_map<cstring, 
                                              std::unordered_set<cstring>>* map);
    void printHdrTypeInstToFields(
        std::unordered_map<cstring, std::unordered_set<cstring>>* mapSet);
  public:
    explicit FindModifiedFields(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
        std::unordered_set<cstring>* allUDefHdrTypeInst,
        std::unordered_map<cstring, std::unordered_set<cstring>>* modHdrTyInFns,
        std::unordered_map<cstring, std::unordered_set<cstring>>* accHdrTypeFns) 
      : refMap(refMap), typeMap(typeMap), 
        allUDefHdrTypeInst(allUDefHdrTypeInst), 
        modHdrTypeInstToFields(modHdrTyInFns), 
        accHdrTypeInstToFields(accHdrTypeFns) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        CHECK_NULL(allUDefHdrTypeInst);
        CHECK_NULL(modHdrTyInFns);  CHECK_NULL(accHdrTypeFns);

    }
    bool preorder(const IR::AssignmentStatement* asmt) override;
    bool preorder(const IR::Member* member) override;
    void postorder(const IR::P4Program* program) override;
    Visitor::profile_t init_apply(const IR::Node* node) {
        return Inspector::init_apply(node);
    }
};

class EntryContext {
    std::unordered_map<const IR::P4Action*,
      std::unordered_set<const IR::AssignmentStatement*>> markedToDelete;
  public:
    EntryContext() {}
    void insert(const IR::P4Action*, const IR::AssignmentStatement*);

    bool diffDelAsStmt(EntryContext* ec);
    bool exists(const IR::P4Action* act, const IR::AssignmentStatement* asmt);
};

class TableContext {
    std::unordered_map<const IR::Entry*, EntryContext*> entryCtxtMap;
  public:
    TableContext() {}
    EntryContext* instantiateEntryContext(const IR::Entry* entry);

    bool canEliminateDeadField();

    bool exists(const IR::P4Action* act, const IR::AssignmentStatement* asmt);
};

class CommonStorageSubExp final : public Inspector {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    std::unordered_map<cstring, std::unordered_set<cstring>>* modHdrTyInFns;
    bool result;

  public:
    explicit CommonStorageSubExp(P4::ReferenceMap* refMap, P4::TypeMap* typeMap,
        std::unordered_map<cstring, std::unordered_set<cstring>>* modHdrTyInFns)
      : refMap(refMap), typeMap(typeMap), modHdrTyInFns(modHdrTyInFns) {
        result = false;
        setName("CommonStorageSubExp"); 
    }

    Visitor::profile_t init_apply(const IR::Node* node) {
        result = false;
        BUG_CHECK(node->is<IR::Expression>(), "expected an expression");
        return Inspector::init_apply(node);
    }

    bool preorder(const IR::Member* member) override;
    bool preorder(const IR::Concat* c) override;

    bool has() {
        return result;
    }
};


/*
 * This l-value store comparison is with type-checking, not just string matching.
 */
class CompareStorageExp final : public Inspector {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    const IR::Expression* expr;
    bool result;
    const IR::Expression* curr;

  public:
    explicit CompareStorageExp(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
        const IR::Expression* expr)
      : refMap(refMap), typeMap(typeMap), expr(expr) {
        result = true;
        setName("CompareStorageExp"); 
    }

    Visitor::profile_t init_apply(const IR::Node* node) {
        result = true;
        curr = expr;
        BUG_CHECK(node->is<IR::Expression>(), "expected an expression");
        return Inspector::init_apply(node);
    }

    bool preorder(const IR::ArrayIndex* ai) override;
    bool preorder(const IR::Member* member) override;
    bool preorder(const IR::PathExpression* pe) override;
    bool preorder(const IR::Constant* c) override;

    bool isMatch() {
        return result;
    }
};

/*
 *  This passe checks if its safe to remove write-back in actions of deparser
 *  MAT. 
 *  Specifically, In presence of setValid and setInvalid in control block, 
 *  if actions in two entries of Deparser MATs 
 *  are removing byte-moves assignment statements for different locations 
 *  from a common `move` action, the write-back can not be eliminated, unless we
 *  generate separate actions.
 */
class ApplyDepActCSTR final : public Inspector {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    std::unordered_map<cstring, std::unordered_set<cstring>>* modHdrTyInFns;
    
    std::unordered_map<const IR::P4Table*, TableContext*>* tblCtxtMap;
    TableContext* currTblCtxt;
    EntryContext* currEntCtxt;

    IR::Vector<IR::Expression> delWritesOn; 
    void insertEntryInCurrTblCtxt(const IR::Entry* entry);

 public:
    using Inspector::preorder;
    using Inspector::postorder;

    explicit ApplyDepActCSTR(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
        std::unordered_map<cstring, std::unordered_set<cstring>>* modHdrTyInFns,
        std::unordered_map<const IR::P4Table*, TableContext*>* tblCtxtMap)
      : refMap(refMap), typeMap(typeMap), modHdrTyInFns(modHdrTyInFns),
        tblCtxtMap(tblCtxtMap) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap); CHECK_NULL(modHdrTyInFns);
        CHECK_NULL(tblCtxtMap);
        setName("ApplyDepActCSTR"); 
        visitDagOnce = false;
    }
    bool preorder(const IR::P4Control* p4control) override;
    bool preorder(const IR::P4Table* p4table) override;
    bool preorder(const IR::Entry* entry) override;

    bool preorder(const IR::P4Action* p4action) override;
    bool preorder(const IR::BlockStatement* bs) override;
    bool preorder(const IR::AssignmentStatement* asmt) override;
    bool preorder(const IR::MethodCallExpression* mce) override;

    Visitor::profile_t init_apply(const IR::Node* node) override { 
        return Inspector::init_apply(node);
    }
};

class RemoveWritebacks final : public Transform {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    std::unordered_map<const IR::P4Table*, TableContext*>* tblCtxtMap;

    TableContext* currTblCtxt;
    const IR::P4Action* origP4ActionPtr;
  public:
    explicit RemoveWritebacks(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
        std::unordered_map<const IR::P4Table*, TableContext*>* tblCtxtMap)
      : refMap(refMap), typeMap(typeMap), tblCtxtMap(tblCtxtMap) {
        CHECK_NULL(tblCtxtMap);
        setName("RemoveWritebacks"); 
    }
    const IR::Node* preorder(IR::P4Action* p4action) override;
    const IR::Node* preorder(IR::AssignmentStatement* asmt) override;
};

class DeadFieldElimination final : public PassManager {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

    std::unordered_set<cstring> allUDefHdrTypeInst;
    std::unordered_map<cstring, std::unordered_set<cstring>> modHdrTypeInstToFields;
    std::unordered_map<cstring, std::unordered_set<cstring>> accHdrTypeInstToFields;

    std::unordered_map<const IR::P4Table*, TableContext*> tblCtxtMap;
 public:

    explicit DeadFieldElimination(P4::ReferenceMap* refMap, P4::TypeMap* typeMap)
      : refMap(refMap), typeMap(typeMap) {
        setName("DeadFieldElimination"); 

        passes.push_back(new FindModifiedFields(refMap, typeMap, 
              &allUDefHdrTypeInst, &modHdrTypeInstToFields, 
              &accHdrTypeInstToFields));
        passes.push_back(new ApplyDepActCSTR(refMap, typeMap, 
              &modHdrTypeInstToFields, &tblCtxtMap));
        passes.push_back(new RemoveWritebacks(refMap, typeMap, &tblCtxtMap));

    }
    Visitor::profile_t init_apply(const IR::Node* node) override { 
        return PassManager::init_apply(node);
    }

    void end_apply(const IR::Node* node) override { 
        refMap->clear();
        typeMap->clear();
        PassManager::end_apply(node);
    }
};

}  // namespace CSA

#endif /* _EXTENSIONS_CSA_LINKER_DEADFIELDELIMINATION_H_  */
