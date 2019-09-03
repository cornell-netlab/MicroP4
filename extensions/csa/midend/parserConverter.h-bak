/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_LINKER_PARSERCONVERTER_H_ 
#define _EXTENSIONS_CSA_LINKER_PARSERCONVERTER_H_ 

#include "ir/ir.h"
#include "lib/ordered_map.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeMap.h"
#include "midend/parserUnroll.h"
#include "controlStateReconInfo.h"
/*
 * This pass converts parser into DAG of MATs
 */
namespace CSA {

class ParserConverter final : public Transform {

// global throught the pass
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    cstring structTypeName;
    cstring fieldName;
    unsigned* bitMaxOffset;
    P4ControlStateReconInfoMap* controlToReconInfoMap;

    cstring noActionName;


// per parser data structures, they get refreshed
    P4::ParserStructure* parserEval = nullptr;
    IR::IndexedVector<IR::StatOrDecl> statOrDeclsOfControlBody;
    IR::IndexedVector<IR::Declaration> varDecls;
    IR::IndexedVector<IR::Declaration> actionDecls;
    IR::IndexedVector<IR::Declaration> tableDecls;
    cstring paketInParamName;
    std::map<cstring, unsigned> stateIDMap;

    // Populated by createKeyElementList and used by entry creation
    std::list<cstring> keyElementOrder;

    void createP4Actions(IR::ParserState* state);
    IR::Vector<IR::KeyElement>* createKeyElementList(IR::ParserState* state);
    IR::IndexedVector<IR::ActionListElement>* 
        createActionList(IR::ParserState* state);
    IR::Vector<IR::Entry>* createEntryList(IR::ParserState* state);

    bool hasDefaultSelectCase(const IR::ParserState* state) const;
    bool hasSelectExpression(const IR::ParserState* state) const;

    cstring createHeaderInvalidAction(IR::P4Parser* parser);
    
    cstring getStateVisitVarName(const IR::ParserState* state) const {
        return "visit_csa_"+state->name.name;
    }

 public:
    using Transform::preorder;
    using Transform::postorder;

    explicit ParserConverter(P4::ReferenceMap* refMap, P4::TypeMap* typeMap,
                             cstring structTypeName, cstring fieldName,
                             unsigned* maxOffset, 
                             P4ControlStateReconInfoMap* controlToReconInfoMap)
        : refMap(refMap), typeMap(typeMap), structTypeName(structTypeName), 
          fieldName(fieldName), bitMaxOffset(maxOffset), 
          controlToReconInfoMap(controlToReconInfoMap) { 
        CHECK_NULL(maxOffset);
        setName("ParserConverter"); 
        *bitMaxOffset = 0;
        noActionName = "NoAction";
    }

    const IR::Node* preorder(IR::P4Parser* parser) override;
    const IR::Node* postorder(IR::P4Parser* parser) override;
    const IR::Node* preorder(IR::ParserState* state) override;
};

class ExtractSubstitutor final : public Transform {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    const P4::ParserStateInfo* parserStateInfo;
    cstring paketInParamName;
    cstring fieldName;

    P4::SymbolicValueFactory svf;
    std::vector<const IR::AssignmentStatement*> createPerFieldAssignmentStmts(
          const IR::Expression* hdrVar, unsigned start);

 public:
    using Transform::preorder;
    using Transform::postorder;

    explicit ExtractSubstitutor(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
                                const P4::ParserStateInfo* parserStateInfo, 
                                cstring paketInParamName,
                                cstring fieldName)
        : refMap(refMap), typeMap(typeMap), parserStateInfo(parserStateInfo), 
          paketInParamName(paketInParamName), fieldName(fieldName), svf(typeMap) { 
        setName("ExtractSubstitutor"); 
    }

    const IR::Node* preorder(IR::MethodCallStatement* mcs) override;

};

/*

// FIXME: check IR::P4Parser has less or replace it with IR::Node* to have
// std::less, otherwise pointer addresses are being compared here.
// It is fine to compare as long nodes cloned in previous passes are not
// invalidated.
typedef std::map<const IR::P4Parser*, P4::ParserStructure*> ParserEvalMap;

class EvaluateAllParsers final : public Inspector { 
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    ParserEvalMap* parserEvalMap;
    unsigned* maxOffset = nullptr;
  public:
    
    EvaluateAllParsers(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
                       // out param
                       ParserEvalMap *parserEvalMap, 
                       unsigned* maxOffset) 
        : refMap(refMap), typeMap(typeMap), parserEvalMap(parserEvalMap), 
          maxOffset(maxOffset) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap); 
        CHECK_NULL(parserEvalMap); CHECK_NULL(maxOffset);
        *maxOffset = 0;
    }

    bool preorder(const IR::P4Parser* parser) override;
};

*/


}  // namespace CSA

#endif /* _EXTENSIONS_CSA_LINKER_PARSERCONVERTER_H_ */
