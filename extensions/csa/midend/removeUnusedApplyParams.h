/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_MIDEND_REMOVEUNUSEDAPPLYPARAMS_H_ 
#define _EXTENSIONS_CSA_MIDEND_REMOVEUNUSEDAPPLYPARAMS_H_ 

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"


namespace CSA {

class RemoveUnusedApplyParams final : public Transform {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    const std::unordered_set<cstring>* skipDecl;

    IR::IndexedVector<IR::Declaration> unusedParams;

    std::unordered_set<size_t> unusedParamLocations;

    // control name, unused param location
    std::unordered_map<cstring, std::unordered_set<size_t>> controlUnusedParamLocMap;

 public:
    using Transform::preorder;
    using Transform::postorder;

    explicit RemoveUnusedApplyParams(P4::ReferenceMap* refMap, 
        P4::TypeMap* typeMap, const std::unordered_set<cstring>* skipDecl)
      : refMap(refMap), typeMap(typeMap), skipDecl(skipDecl) {
        setName("RemoveUnusedApplyParams"); 
    }
    const IR::Node* preorder(IR::Parameter* param) override;
    const IR::Node* preorder(IR::MethodCallExpression* mce) override;
    const IR::Node* preorder(IR::P4Control* p4control) override;
    const IR::Node* preorder(IR::Type_Control* tc) override;
    const IR::Node* postorder(IR::ParameterList* pl) override;

    Visitor::profile_t init_apply(const IR::Node* node) override { 
        controlUnusedParamLocMap.clear();
        unusedParams.clear();
        unusedParamLocations.clear();
        return Transform::init_apply(node);
    }

    void end_apply(const IR::Node* node) override { 
        refMap->clear();
        typeMap->clear();
        Transform::end_apply(node);
    }
};



class RmUnusedApplyParams : public PassRepeated {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

  public:
    explicit RmUnusedApplyParams(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
        const std::unordered_set<cstring>* skipDecl)
      : PassManager({}), refMap(refMap), typeMap(typeMap) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap); setName("RmUnusedApplyParams");
        passes.emplace_back(new P4::ResolveReferences(refMap, true)); 
        passes.emplace_back(new P4::TypeInference(refMap, typeMap, false)); 
        passes.emplace_back(new RemoveUnusedApplyParams(refMap, typeMap, skipDecl));
    }

    void end_apply(const IR::Node* node) override { 
        refMap->clear();
        typeMap->clear();
        PassManager::end_apply(node);
    }
};


}  // namespace CSA

#endif /* _EXTENSIONS_CSA_LINKER_REMOVEUNUSEDAPPLYPARAMS_H_ */
