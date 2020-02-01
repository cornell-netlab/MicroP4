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
    bool preorder(const IR::Expression* expr) override;

public:
    std::vector<const IR::ParserState*> states;

    explicit CollectStates(IR::IndexedVector<IR::ParserState> allStates)
        : allStates(allStates) {
        setName("CollectStates"); 
    }
};

class ParaParserMerge final : public Transform {
    P4::ReferenceMap* refMap1;
    P4::TypeMap* typeMap1;
    IR::IndexedVector<IR::ParserState> states1;

    P4::ReferenceMap* refMap2;
    P4::TypeMap* typeMap2;
    const IR::P4Parser* p2;
    IR::IndexedVector<IR::ParserState> states2;
    const IR::ParserState* currP2State;
    const IR::Expression* currP2Select;
    const IR::SelectCase* currP2Case;
    IR::Vector<IR::Node>* statesToAdd;

    std::map<cstring, std::pair<cstring, cstring>> stateMap;

  public:
    explicit ParaParserMerge(P4::ReferenceMap* refMap1, P4::TypeMap* typeMap1,
            P4::ReferenceMap* refMap2, P4::TypeMap* typeMap2,
            const IR::P4Parser* p2)
      : refMap1(refMap1), typeMap1(typeMap1), refMap2(refMap2),
        typeMap2(typeMap2), p2(p2) {
        CHECK_NULL(refMap1); CHECK_NULL(typeMap1);
        CHECK_NULL(refMap2); CHECK_NULL(typeMap2);
        statesToAdd = new IR::Vector<IR::Node>();
        currP2Case = nullptr;
        currP2State = nullptr;
        currP2Select = nullptr;
        setName("ParaParserMerge"); 
    }

    const IR::Node* preorder(IR::P4Parser* p4parser) override;
    const IR::Node* postorder(IR::P4Parser* p4parser) override;

    const IR::Node* preorder(IR::ParserState* state) override;
    const IR::Node* postorder(IR::ParserState* state) override;

    const IR::Node* preorder(IR::SelectCase* case1) override;
    const IR::Node* postorder(IR::SelectCase* case1) override;

    const IR::Node* preorder(IR::PathExpression* pathExpression) override;
    const IR::Node* preorder(IR::SelectExpression* selectExpression) override;

    void end_apply(const IR::Node* n) override;

  private:
    const IR::Node* statesMapped(const IR::ParserState *s1, const IR::ParserState *s2);
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

class ParaDeParMerge final : public Transform {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    const IR::P4ComposablePackage* cp2;

  public:
    explicit ParaDeParMerge(P4::ReferenceMap* refMap, P4::TypeMap* typeMap,
        const IR::P4ComposablePackage* cp2) 
      : refMap(refMap), typeMap(typeMap), cp2(cp2) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        setName("ParaDeParMerge"); 
    }

    const IR::Node* preorder(IR::P4Control* p4control) override;
    const IR::Node* postorder(IR::P4Control* p4control) override;

    const IR::Node* preorder(IR::P4Parser* p4parser) override;
    const IR::Node* postorder(IR::P4Parser* p4parser) override;

    const IR::Node* preorder(IR::P4ComposablePackage* cp) override;
    const IR::Node* postorder(IR::P4ComposablePackage* cp) override;

};

class HardcodedMergeTest final : public Transform {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    const IR::P4Parser* other_parser;

public:
    explicit HardcodedMergeTest(P4::ReferenceMap* refMap, P4::TypeMap* typeMap) :
    refMap(refMap), typeMap(typeMap) {
        CHECK_NULL(refMap);
        CHECK_NULL(typeMap);
        setName("HardcodedMergeTest");
    }

    const IR::Node* preorder(IR::P4Parser* parser) override;
};

}   // namespace CSA
#endif  /* _EXTENSIONS_CSA_MIDEND_PARADEPARMERGE_H_ */

