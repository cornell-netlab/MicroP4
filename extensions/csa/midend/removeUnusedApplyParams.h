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
    std::unordered_set<cstring>* skipDecl;
 public:
    using Transform::preorder;
    using Transform::postorder;

    explicit RemoveUnusedApplyParams(P4::ReferenceMap* refMap, 
        P4::TypeMap* typeMap, std::unordered_set<cstring>* skipDecl)
      : refMap(refMap), typeMap(typeMap), skipDecl(skipDecl) {
        setName("RemoveUnusedApplyParams"); 
    }
    const IR::Node* preorder(IR::Parameter* param) override;
    const IR::Node* preorder(IR::MethodCallExpression* mce) override;
    const IR::Node* preorder(IR::P4Control* p4control) override;
    const IR::Node* preorder(IR::Type_Control* tc) override;
    const IR::Node* preorder(IR::ParameterList* pl) override;
};


}  // namespace CSA

#endif /* _EXTENSIONS_CSA_LINKER_REMOVEUNUSEDAPPLYPARAMS_H_ */
