/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_MIDEND_HDRTOSTRUCTS_H_ 
#define _EXTENSIONS_CSA_MIDEND_HDRTOSTRUCTS_H_ 

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"

namespace CSA {

class HdrToStructs final : public Transform {

    enum ValidityOPType {
        SetValid = 0,
        SetInvalid,
        IsValid,
        None
    };

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

    ValidityOPType getValidityOPFlagName(const IR::MethodCallExpression* mce, 
                                         cstring& hdrName, cstring& hdrTypeName);
    bool skipHeaderTypes(cstring typeName);

 public:
    using Transform::preorder;
    using Transform::postorder;

    explicit HdrToStructs(P4::ReferenceMap* refMap, P4::TypeMap* typeMap)
      : refMap(refMap), typeMap(typeMap) {
        setName("HdrToStructs"); 
    }
    const IR::Node* preorder(IR::Type_Header* typeHeader) override;
    const IR::Node* preorder(IR::MethodCallExpression* mce) override;
    const IR::Node* preorder(IR::MethodCallStatement* mcs) override;

};


}  // namespace CSA

#endif /* _EXTENSIONS_CSA_LINKER_HDRTOSTRUCTS_H_ */
