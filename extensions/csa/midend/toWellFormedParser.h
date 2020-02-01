/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_MIDEND_TOWELLFORMEDPARSER_H_ 
#define _EXTENSIONS_CSA_MIDEND_TOWELLFORMEDPARSER_H_ 

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"

namespace CSA {
class CheckParserGuard final : public Inspector {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

    bool available;
  public:
    using Inspector::preorder;
    using Inspector::postorder;

    explicit CheckParserGuard(P4::ReferenceMap* refMap, P4::TypeMap* typeMap) 
      : refMap(refMap), typeMap(typeMap) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        setName("CheckParserGuard"); 
        available = false;
    }
    bool preorder(const IR::ParserState* parserState) override;
    bool hasGuard() const {
        return available;
    }

};

class ToWellFormedParser final : public Transform {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

    IR::Vector<IR::Type_Declaration> updateP4ProgramObjects;
    std::map<cstring, const IR::Type_Declaration*> insertAtP4ProgramObjects;
    IR::P4Program* p4Program;

    const IR::Expression* guard;
    std::vector<std::pair<const IR::Member*, const IR::Constant*>> guardStack;
    std::pair<const IR::Member*, const IR::Constant*> currGuard;

    const IR::Member* guardMem;
    const IR::Constant* guardVal;

    cstring newFieldName;
    const IR::Constant* value;
    IR::Type_Struct* newInParamType;
    const IR::Parameter* currInParam;


    cstring parserInParamName;
    cstring newStartName;

    std::vector<IR::IndexedVector<IR::Declaration>*> clStack;

    const IR::P4ComposablePackage* getNodeFromP4Program(
        const IR::P4Program* p4Program, const IR::P4ComposablePackage* node);

    unsigned short id_suffix = 0;
  public:
    using Transform::preorder;
    using Transform::postorder;

    explicit ToWellFormedParser(P4::ReferenceMap* refMap, P4::TypeMap* typeMap) 
      : refMap(refMap), typeMap(typeMap) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        setName("ToWellFormedParser"); 
        newInParamType = nullptr;
    }

    const IR::Node* preorder(IR::P4Parser* p4parser) override;

    const IR::Node* preorder(IR::ParserState* parserState) override;

    const IR::Node* preorder(IR::P4Control* p4control) override;

    const IR::Node* preorder(IR::P4ComposablePackage* cp) override;

    const IR::Node* preorder(IR::Parameter* param) override;

    const IR::Node* preorder(IR::IfStatement* ifstmt) override;

    const IR::Node* preorder(IR::MethodCallStatement* mcs) override;

    const IR::Node* preorder(IR::P4Program* program) override;

    const IR::Node* preorder(IR::Equ* equ) override;

    const IR::Node* preorder(IR::Member* mem) override;
  
    const IR::Node* preorder(IR::Constant* cs) override;

    const IR::Node* preorder(IR::Type_Specialized* ts) override;

};

}   // namespace CSA
#endif  /* _EXTENSIONS_CSA_MIDEND_TOWELLFORMEDPARSER_H_ */

