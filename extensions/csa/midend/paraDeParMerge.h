/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_MIDEND_PARADEPARMERGE_H_ 
#define _EXTENSIONS_CSA_MIDEND_PARADEPARMERGE_H_ 

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/coreLibrary.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"
#include "headerMerge.h"

namespace CSA {

class FindExtractedHeader final : public Inspector {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

  public:
    const IR::Expression *extractedHeader;

    explicit FindExtractedHeader(P4::ReferenceMap* refMap, P4::TypeMap* typeMap)
      : refMap(refMap), typeMap(typeMap) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        extractedHeader = nullptr;
        setName("FindExtractedHeader"); 
    }

    bool preorder(const IR::MethodCallExpression* call) override;
};

class CollectStates final : public Inspector {
    const IR::IndexedVector<IR::ParserState> allStates;
    bool preorder(const IR::ParserState* state) override;
    bool preorder(const IR::PathExpression* expr) override;
    bool preorder(const IR::SelectExpression* expr) override;

public:
    std::vector<const IR::ParserState*> states;

    explicit CollectStates(IR::IndexedVector<IR::ParserState> allStates)
        : allStates(allStates) {
        setName("CollectStates"); 
    }
};

class ParaParserMerge final : public Transform {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    IR::IndexedVector<IR::ParserState> states1;

    cstring pkgName1;
    cstring pkgName2;
    const IR::P4ComposablePackage* pkg1;
    const IR::P4ComposablePackage* pkg2;
    const IR::P4Parser* p2;
    IR::IndexedVector<IR::ParserState> states2;
    const IR::ParserState* currP2State;
    const IR::SelectCase* currP2Case;

    IR::Vector<IR::ParserState>* statesToAdd;
    IR::Vector<IR::ParserState>* statesToChange;

    std::map<cstring, std::pair<cstring, cstring>> stateMap;
    HeaderMerger* headerMerger;

  public:
    explicit ParaParserMerge(P4::ReferenceMap* refMap, P4::TypeMap* typeMap,
                             cstring pkgName1, cstring pkgName2)
        : refMap(refMap), typeMap(typeMap), pkgName1(pkgName1), pkgName2(pkgName2) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        statesToAdd = new IR::Vector<IR::ParserState>();
        statesToChange = new IR::Vector<IR::ParserState>();
        pkg2 = nullptr;
        p2 = nullptr;
        currP2Case = nullptr;
        currP2State = nullptr;
        setName("ParaParserMerge"); 
        headerMerger = new HeaderMerger(typeMap);
    }

    const IR::Node* preorder(IR::P4Program* program) override;
    const IR::Node* preorder(IR::P4Parser* p4parser) override;
    const IR::Node* preorder(IR::ParserState* state) override;
    const IR::Node* preorder(IR::SelectCase* case1) override;
    const IR::Node* preorder(IR::PathExpression* pathExpression) override;
    const IR::Node* preorder(IR::SelectExpression* selectExpression) override;

  private:
    bool statesMapped(const IR::ParserState *s1, const IR::ParserState *s2);
    bool keysetsEqual(const IR::Expression *e1, const IR::Expression *e2);
    void visitByNames(cstring s1, cstring s2);
    void mapStates(cstring s1, cstring s2, cstring merged);
    IR::Node* copyParser2States();
    std::vector<std::pair<IR::SelectCase*, IR::SelectCase*>>
      matchCases(IR::Vector<IR::SelectCase> cases1,
		 IR::Vector<IR::SelectCase> cases2);
    IR::Expression* mergeHeaders(const IR::Expression *h1, const IR::Expression *h2);
    const IR::Node* mergeTransitions(const IR::ParserState* state1,
                                     const IR::ParserState* state2);
    void collectStates1(const IR::Expression* selectExpression);
    void collectStates2(const IR::Expression* selectExpression);
};

}   // namespace CSA
#endif  /* _EXTENSIONS_CSA_MIDEND_PARADEPARMERGE_H_ */

