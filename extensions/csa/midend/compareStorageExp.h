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


// have to find mapping here
// param.x.y -> arg ->arg.x.y or
// param.x.y -> arg.x-> arg.x.y
//
// path to param should be substituted by ae
class CompArgParamToStorageExp final : public Inspector {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    const IR::Parameter* param;
    const IR::Expression* calleeExpr;
    const IR::Expression* arg;

    bool result;
    const IR::Expression* curr;

    bool matchingCE;
  public:
    explicit CompArgParamToStorageExp(P4::ReferenceMap* refMap, 
        P4::TypeMap* typeMap, const IR::Parameter* param, 
        const IR::Expression* calleeExpr,
        const IR::Expression* arg) 
      : refMap(refMap), typeMap(typeMap), param(param), calleeExpr(calleeExpr),
        arg(arg) {
        result = true;
        matchingCE = true;
        curr = calleeExpr;
        setName("CompareStorageExp"); 
    }

    bool preorder(const IR::Member* member) override;
    bool preorder(const IR::PathExpression* pe) override;

    Visitor::profile_t init_apply(const IR::Node* node) {
        result = true;
        matchingCE = true;
        curr = calleeExpr;
        BUG_CHECK(node->is<IR::Expression>(), "expected an expression");
        return Inspector::init_apply(node);
    }

    bool isMatch() {
        return result;
    }
};


}  // namespace CSA

#endif /* _EXTENSIONS_CSA_LINKER_COMPARESTORAGEEXP_H_  */
