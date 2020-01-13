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

/*
 * Initially, this pass is planned for only Tofino2 to insert ContainerType
 * pragmas on msa_header instances.
 * e.g.,
 * @pa_container_type ("ingress", "mpkt.msa_hdr_stack_s0[11].data", "normal")
 */
class LearnConcatenatedFields final : public Inspector {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    std::unordered_set<cstring>* fieldFQDN;
 public:
    using Inspector::preorder;

    explicit LearnConcatenatedFields(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
        std::unordered_set<cstring>* fieldFQDN)
      : refMap(refMap), typeMap(typeMap), 
        fieldFQDN(fieldFQDN) {
        setName("LearnConcatenatedFields"); 
    }
    bool preorder(const IR::AssignmentStatement* asmt) override;
};

class AnnotateFields final : public Transform {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

    std::unordered_set<cstring> fieldFQDN;

 public:
    using Transform::preorder;
    using Transform::postorder;

    explicit AnnotateFields(P4::ReferenceMap* refMap, P4::TypeMap* typeMap)
      : refMap(refMap), typeMap(typeMap) {
        setName("AnnotateFields"); 
    }
    const IR::Node* preorder(IR::P4Program* p4program) override;
    const IR::Node* preorder(IR::Type_Struct* ts) override;
};

}  // namespace CSA

#endif /* _EXTENSIONS_CSA_BACKEND_TOFINO_ANNOTATEFIELDS_H_ */
           
