/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_MIDEND_IDENTIFYSTORAGE_H_
#define _EXTENSIONS_CSA_MIDEND_IDENTIFYSTORAGE_H_

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"

namespace CSA {

class IdentifyStorage final : public Inspector {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

    const IR::Type_Struct* typeStruct;
    cstring fieldName;
    bool msaHeaderStorage;
    bool multipleStorages;
    int arrayIndex;


    short level;
  public:
    explicit IdentifyStorage(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
        short level = 0)
      : refMap(refMap), typeMap(typeMap), level(level) {
    }

    Visitor::profile_t init_apply(const IR::Node* node) {
        typeStruct = nullptr;
        fieldName = "";
        msaHeaderStorage = false;
        multipleStorages = false;
        arrayIndex = -1;
        BUG_CHECK(node->is<IR::Expression>(), "expected an expression");
        return Inspector::init_apply(node);
    }

    bool preorder(const IR::ArrayIndex* ai) override;
    bool preorder(const IR::Member* member) override;
    bool preorder(const IR::PathExpression* pe) override;

    bool isMSAHeaderStorage();
    bool hasMultipleStorages();
    cstring getFieldName();
    const IR::Type_Struct* getStructType();
    int getArrayIndex();

};

}  // namespace CSA

#endif /* _EXTENSIONS_CSA_MIDEND_IDENTIFYSTORAGE_H_ */
