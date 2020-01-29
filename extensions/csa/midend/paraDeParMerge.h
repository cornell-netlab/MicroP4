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
    const IR::Path *extractedHeader;
    IR::Type_Header *extractedType;

    explicit FindExtractedHeader(P4::ReferenceMap* refMap, P4::TypeMap* typeMap)
      : refMap(refMap), typeMap(typeMap) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        setName("FindExtractedHeader"); 
    }

    bool preorder(const IR::StatOrDecl* statementOrDecl) override;
    bool preorder(const IR::MethodCallExpression* call) override;
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

    std::map<cstring, std::pair<cstring, cstring>> stateMap;

  public:
    explicit ParaParserMerge(P4::ReferenceMap* refMap1, P4::TypeMap* typeMap1,
            P4::ReferenceMap* refMap2, P4::TypeMap* typeMap2,
            const IR::P4Parser* p2)
      : refMap1(refMap1), typeMap1(typeMap1), refMap2(refMap2),
        typeMap2(typeMap2), p2(p2) {
        CHECK_NULL(refMap1); CHECK_NULL(typeMap1);
        CHECK_NULL(refMap2); CHECK_NULL(typeMap2);
        setName("ParaParserMerge"); 
    }

    const IR::Node* preorder(IR::P4Parser* p4parser) override;
    const IR::Node* postorder(IR::P4Parser* p4parser) override;

    const IR::Node* preorder(IR::ParserState* state) override;
    const IR::Node* postorder(IR::ParserState* state) override;

  private:
    void visitByNames(cstring s1, cstring s2);
    void mapStates(cstring s1, cstring s2, cstring merged);
    std::vector<std::pair<IR::SelectCase*, IR::SelectCase*>>
      matchCases(IR::Vector<IR::SelectCase> cases1,
		 IR::Vector<IR::SelectCase> cases2);
    IR::Path* mergeHeaders(const IR::Path *h1, IR::Type_Header *type1,
                           const IR::Path *h2, IR::Type_Header *type2);

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

}   // namespace CSA
#endif  /* _EXTENSIONS_CSA_MIDEND_PARADEPARMERGE_H_ */

