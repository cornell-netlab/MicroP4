/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_MIDEND_DEPARMERGE_H_ 
#define _EXTENSIONS_CSA_MIDEND_DEPARMERGE_H_ 

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"

namespace CSA {

class DeParMerge final : public Transform {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    const IR::P4ComposablePackage* cp2;

  public:
    explicit DeParMerge(P4::ReferenceMap* refMap, P4::TypeMap* typeMap) 
      : refMap(refMap), typeMap(typeMap) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        CHECK_NULL(cp2);
        setName("DeParMerge"); 
    }

    const IR::Node* preorder(IR::P4Control* p4control) override;
    const IR::Node* postorder(IR::P4Control* p4control) override;

    const IR::Node* preorder(IR::P4Parser* p4parser) override;
    const IR::Node* postorder(IR::P4Parser* p4parser) override;

    const IR::Node* preorder(IR::P4ComposablePackage* cp) override;
    const IR::Node* postorder(IR::P4ComposablePackage* cp) override;

};

class DeParMotion final : public PassRepeated {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
  public:
    explicit DeParMotion(P4::ReferenceMap* refMap, P4::TypeMap* typeMap)
      : PassManager({}), refMap(refMap), typeMap(typeMap) {
        passes.emplace_back(new P4::ResolveReferences(refMap, true));
        passes.emplace_back(new P4::TypeInference(refMap, typeMap, false));
    }
    void end_apply(const IR::Node* node) override {
        PassManager::end_apply(node);
    }
};


}   // namespace CSA
#endif  /* _EXTENSIONS_CSA_MIDEND_DEPARMERGE_H_ */

