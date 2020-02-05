/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_LINKER_COMPARESTORAGEEXP_H_
#define _EXTENSIONS_CSA_LINKER_COMPARESTORAGEEXP_H_

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"

namespace CSA {
/*
 * This l-value store comparison is with type-checking, not just string matching.
 */
class CompareStorageExp final : public Inspector {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    const IR::Expression* expr;
    bool result;
    const IR::Expression* curr;

    bool compareSub;
    bool subExpMatchStart;
  public:
    explicit CompareStorageExp(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
        const IR::Expression* expr, bool compareSub = false)
      : refMap(refMap), typeMap(typeMap), expr(expr), compareSub(compareSub) {
        result = true;
        subExpMatchStart = false;
        setName("CompareStorageExp"); 
    }

    Visitor::profile_t init_apply(const IR::Node* node) {
        result = true;
        subExpMatchStart = false;
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

}  // namespace CSA

#endif /* _EXTENSIONS_CSA_LINKER_COMPARESTORAGEEXP_H_  */
