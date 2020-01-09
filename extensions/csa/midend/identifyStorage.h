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

    std::vector<const IR::Type*> types;
    std::vector<cstring> names;
    bool msaHeaderStorage;
    int arrayIndex;

    short level;
    short argLevel;
  public:
    explicit IdentifyStorage(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
        short level = 0)
      : refMap(refMap), typeMap(typeMap), argLevel(level) {
    }

    Visitor::profile_t init_apply(const IR::Node* node) {
        types.clear();
        names.clear();
        level = argLevel;
        msaHeaderStorage = false;
        arrayIndex = -1;
        BUG_CHECK(node->is<IR::Expression>(), "expected an expression");
        return Inspector::init_apply(node);
    }

    bool preorder(const IR::ArrayIndex* ai) override;
    bool preorder(const IR::Member* member) override;
    bool preorder(const IR::PathExpression* pe) override;

    bool isMSAHeaderStorage();
    cstring getName(unsigned level);
    const IR::Type* getType(unsigned level);
    int getArrayIndex();

};

}  // namespace CSA

#endif /* _EXTENSIONS_CSA_MIDEND_IDENTIFYSTORAGE_H_ */
