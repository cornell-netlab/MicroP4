/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */
#ifndef _EXTENSIONS_CSA_MIDEND_CONCATDEPARMERGE_H_ 
#define _EXTENSIONS_CSA_MIDEND_CONCATDEPARMERGE_H_ 

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"

namespace CSA {

typedef std::vector<const IR::Member*> ParserHooks; 
typedef std::pair<ParserHooks, const IR::P4ComposablePackage*> ConcatCntxt;

/*
 * Finds declaration of l-value expression
 */
class FindDeclaration final : public Inspector {
    P4::ReferenceMap* refMap;

    const IR::IDeclaration** decl;
  public:
    explicit FindDeclaration(P4::ReferenceMap* refMap, 
        const IR::IDeclaration** decl)
      : refMap(refMap), decl(decl) {
        setName("FindDeclaration"); 
    }
    bool preorder(const IR::Path* path) override;
    Visitor::profile_t init_apply(const IR::Node* node) {
        BUG_CHECK((node->is<IR::PathExpression>() || node->is<IR::Member>()), 
            " %1% must be path expression or member for FindDeclaration", node);
        return Inspector::init_apply(node);
    }
};

class FindConcatCntxts final : public Inspector {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    std::vector<ConcatCntxt*>*  concatCntxts;

    const IR::ParameterList* callerP4ControlApplyParams;

    // First element : intermediate expression/variable
    // second element : PathExpression/Member containing param
    std::vector<std::pair<const IR::Expression*, const IR::Expression*>> 
        exprsToParamsMap;

    // expression in arg to intermediate expression/variable
    // vector allows to use parameter's index for arg mapping.
    std::vector<std::pair<const IR::Expression*, 
                          std::vector<const IR::Expression*>>> argToExprs;

    const IR::P4ComposablePackage* p4cp;
    const IR::Expression* parserSelectExpr;


  public:
    explicit FindConcatCntxts(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
        std::vector<ConcatCntxt*>* concatCntxts)
      : refMap(refMap), typeMap(typeMap), concatCntxts(concatCntxts) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap); CHECK_NULL(concatCntxts);
        setName("FindConcatCntxts"); 
    }

    bool preorder(const IR::P4ComposablePackage* cp) override;
    bool preorder(const IR::P4Control* p4control) override;
    void postorder(const IR::P4Control* p4control) override;
    bool preorder(const IR::P4Parser* p4Parser) override;

    bool preorder(const IR::ParserState* ps) override;
    bool preorder(const IR::SelectExpression* se) override;

    bool preorder(const IR::MethodCallStatement* mcs) override;
    bool preorder(const IR::AssignmentStatement* asmt) override;

    Visitor::profile_t init_apply(const IR::Node* node) {
        BUG_CHECK(node->is<IR::P4ComposablePackage>(), 
            " %1% must be P4ComposablePackage", node);
        p4cp = node->to<IR::P4ComposablePackage>();
        return Inspector::init_apply(node);
    }

};


class ConcatDeParMerge final : public Transform {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

    // ones which cant be concatenated in this pass, as are already involved as
    // callers or callees in concatenation
    IR::IndexedVector<IR::Type_Declaration> lockedP4CP;


  public:
    explicit ConcatDeParMerge(P4::ReferenceMap* refMap, P4::TypeMap* typeMap)
      : refMap(refMap), typeMap(typeMap) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        setName("ConcatDeParMerge"); 
    }

    const IR::Node* preorder(IR::P4ComposablePackage* cp) override;

    const IR::Node* preorder(IR::P4Control* p4control) override;
    const IR::Node* postorder(IR::P4Control* p4control) override;

    const IR::Node* preorder(IR::P4Parser* p4parser) override;
    const IR::Node* postorder(IR::P4Parser* p4parser) override;


};

}   // namespace CSA
#endif  /* _EXTENSIONS_CSA_MIDEND_CONCATDEPARMERGE_H_ */
