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

    IR::IndexedVector<IR::Type_Declaration>* allUserDefinedHdrTypes;
    std::unordered_map<cstring, std::unordered_set<cstring>>* modifiedHdrTypeFields;
    std::unordered_map<cstring, std::unordered_set<cstring>>* accessedHdrTypeFields;

    void filterUserDefinedHdrType(std::unordered_map<cstring, 
                                              std::unordered_set<cstring>>* map);
  public:
    explicit FindModifiedFields(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
        IR::IndexedVector<IR::Type_Declaration>* allUserDefinedHdrTypes,  
        std::unordered_map<cstring, std::unordered_set<cstring>>* modHdrTyeFns,
        std::unordered_map<cstring, std::unordered_set<cstring>>* accHdrTypeFns) 
      : refMap(refMap), typeMap(typeMap), 
        allUserDefinedHdrTypes(allUserDefinedHdrTypes), 
        modifiedHdrTypeFields(modHdrTyeFns), 
        accessedHdrTypeFields(accHdrTypeFns) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        CHECK_NULL(allUserDefinedHdrTypes); 
        CHECK_NULL(modHdrTyeFns);  CHECK_NULL(accHdrTypeFns);

    }

    bool preorder(const IR::AssignmentStatement* asmt) override;
    bool preorder(const IR::Member* member) override;
    void postorder(const IR::P4Program* program) override;

    Visitor::profile_t init_apply(const IR::Node* node) {
        return Inspector::init_apply(node);
    }

};

class ReduceWriteBacks final : public Transform {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

 public:
    using Transform::preorder;
    using Transform::postorder;

    explicit ReduceWriteBacks(P4::ReferenceMap* refMap, P4::TypeMap* typeMap)
      : refMap(refMap), typeMap(typeMap) {
        setName("ReduceWriteBacks"); 
    }
    const IR::Node* preorder(IR::P4Control* p4control) override;
    const IR::Node* preorder(IR::P4Action* p4action) override;
    const IR::Node* preorder(IR::AssignmentStatement* asmt) override;
    const IR::Node* preorder(IR::Path* asmt) override;

    Visitor::profile_t init_apply(const IR::Node* node) override { 
        return Transform::init_apply(node);
    }

    void end_apply(const IR::Node* node) override { 
        refMap->clear();
        typeMap->clear();
        Transform::end_apply(node);
    }
};

class DeadFieldElimination final : public PassManager {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

    IR::IndexedVector<IR::Type_Declaration> allUserDefinedHdrTypes;
    std::unordered_map<cstring, std::unordered_set<cstring>> modifiedHdrTypeFields;
    std::unordered_map<cstring, std::unordered_set<cstring>> accessedHdrTypeFields;
 public:

    explicit DeadFieldElimination(P4::ReferenceMap* refMap, P4::TypeMap* typeMap)
      : refMap(refMap), typeMap(typeMap) {
        setName("DeadFieldElimination"); 

        passes.push_back(new FindModifiedFields(refMap, typeMap, 
              &allUserDefinedHdrTypes, &modifiedHdrTypeFields, 
              &accessedHdrTypeFields));

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
