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
#include "msaNameConstants.h"

/*
 * This pass converts parser into DAG of MATs
 */
namespace CSA {

class ParserConverter final : public Transform {

// global throught the pass
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    P4ControlStateReconInfoMap* controlToReconInfoMap;
    cstring noActionName;
    cstring rejectActionName;
    P4::ParserStructure* parserStructure = nullptr;
    const std::vector<unsigned>* initialOffsets;
    cstring parserMetaStructTypeName;

    const cstring tableName = "parser_tbl";
    IR::IndexedVector<IR::StatOrDecl> statOrDeclsOfControlBody;
    IR::IndexedVector<IR::Declaration> actionDecls;
    IR::Declaration* tableDecl;
    IR::Vector<IR::KeyElement> keyElementList;
    IR::IndexedVector<IR::ActionListElement> actionList;
    std::map<unsigned, IR::Vector<IR::Entry>> entryListPerOffset;
    std::map<cstring, IR::IndexedVector<IR::StatOrDecl>> toAppendStats;
    cstring pktParamName;

    bool stateIterator(IR::ParserState* state);
    bool hasDefaultSelectCase(const IR::ParserState* state) const;
    bool hasSelectExpression(const IR::ParserState* state) const;
    cstring createInitdAction(IR::P4Parser* parser);
    void createRejectAction(IR::P4Parser* parser);
    void initTableWithOffsetEntries(const cstring startStateName);
    void createP4Table();

    cstring getActionName(const P4::ParserStateInfo* si, unsigned initOffset) const {
        if (si->state->name.name == IR::ParserState::reject) 
            return rejectActionName;
        return "i_"+cstring::to_cstring(initOffset) +"_"+si->name;
    }

 public:
    using Transform::preorder;
    using Transform::postorder;

    explicit ParserConverter(P4::ReferenceMap* refMap, P4::TypeMap* typeMap,
                             P4ControlStateReconInfoMap* controlToReconInfoMap,
                             P4::ParserStructure* parserStructure,
                             const std::vector<unsigned>* initialOffsets,
                             cstring parserMetaStructTypeName)
        : refMap(refMap), typeMap(typeMap), 
          controlToReconInfoMap(controlToReconInfoMap),
          parserStructure(parserStructure), initialOffsets(initialOffsets),
          parserMetaStructTypeName(parserMetaStructTypeName) { 
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        CHECK_NULL(parserStructure); CHECK_NULL(initialOffsets);
        setName("ParserConverter"); 
        noActionName = "NoAction";
    }

    const IR::Node* preorder(IR::P4Parser* parser) override;
    const IR::Node* postorder(IR::P4Parser* parser) override;
    const IR::Node* preorder(IR::ParserState* state) override;
    // const IR::Node* preorder(IR::Parameter* param) override;
};

class ExtractSubstitutor final : public Transform {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    const P4::ParserStateInfo* parserStateInfo;
    unsigned initOffset;
    cstring pktParamName;
    cstring fieldName;

    P4::SymbolicValueFactory svf;
    std::vector<const IR::AssignmentStatement*> createPerFieldAssignmentStmts(
          const IR::Expression* hdrVar, unsigned start);

 public:
    using Transform::preorder;
    using Transform::postorder;

    explicit ExtractSubstitutor(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
                                const P4::ParserStateInfo* parserStateInfo, 
                                unsigned initOffset, cstring pktParamName,
                                cstring fieldName)
        : refMap(refMap), typeMap(typeMap), parserStateInfo(parserStateInfo),
          initOffset(initOffset), pktParamName(pktParamName), 
          fieldName(fieldName), svf(typeMap) { 
        setName("ExtractSubstitutor"); 
    }


    const IR::Node* preorder(IR::MethodCallStatement* mcs) override;
};

}  // namespace CSA

#endif /* _EXTENSIONS_CSA_LINKER_PARSERCONVERTER_H_ */
