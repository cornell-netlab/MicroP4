/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_BACKEND_TOFINO_ANNOTATEFIELDS_H_ 
#define _EXTENSIONS_CSA_BACKEND_TOFINO_ANNOTATEFIELDS_H_ 

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"

namespace CSA {

class AnnotateFields final : public Transform {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

 public:
    using Transform::preorder;
    using Transform::postorder;

    explicit AnnotateFields(P4::ReferenceMap* refMap, 
        P4::TypeMap* typeMap, std::vector<cstring>* skipDecl)
      : refMap(refMap), typeMap(typeMap) {
        setName("AnnotateFields"); 
    }
    const IR::Node* preorder(IR::AssignmentStatement* asmt) override;
};

}  // namespace CSA

#endif /* _EXTENSIONS_CSA_BACKEND_TOFINO_ANNOTATEFIELDS_H_ */
           
