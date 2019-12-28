/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _MIDEND_CONTROLBLOCKINTERPRETER_H_
#define _MIDEND_CONTROLBLOCKINTERPRETER_H_

#include "ir/ir.h"
#include "frontends/common/resolveReferences/referenceMap.h"
#include "frontends/p4/typeMap.h"
#include "frontends/p4/coreLibrary.h"
#include "interpreter.h"
#include "parserUnroll.h"

// Symbolic Evaluation of `selective code` of P4 Control blocks.
// This interpreter finds maximum increase and maximum decrease in packet size by
// every control block in the program.

namespace P4 {

class SymbolicValueFactory;

typedef std::pair<std::unordered_set<cstring>, std::unordered_set<cstring>> HdrValidityOpsRecord;
typedef std::vector<HdrValidityOpsRecord> HdrValidityOpsRecVec;
typedef std::map<cstring, HdrValidityOpsRecVec*> HdrValidityOpsPkgMap;


class ControlBlockInterpreter : public Inspector {
    ReferenceMap*       refMap;
    TypeMap*            typeMap;
    P4::ParserStructuresMap* parserStructures;
    cstring parserFQN;
    HdrValidityOpsRecVec* xoredHdrValidityOps;
    P4::HdrValidityOpsPkgMap* hdrValidityOpsPkgMap;

    P4::ParserStructure* parserStructure;
    const SymbolicValueFactory* factory;

    unsigned maxIncr; // maximum increase in packet size
    unsigned maxDecr; // maximum decrease in packet size

    // TODO: tighten the bound for maxIncrPktLen using them
    // if minIncr > 0, maxDecrPktLen = minDecrPktLen = 0
    unsigned minIncr;
    // if minDecrPktLen > 0, maxIncrPktLen = minIncrPktLen = 0
    unsigned minDecr;

    unsigned maxExtLen; // maximum extract length of the control block
    unsigned accumDecrPktLen; // accumulated decrease in packet size by callees



    HdrValidityOpsRecord currOpsRec;

    void replicateHdrValidityOpsVec(size_t nfold);
    void clearCurrOpsRec();
    void insertCurrOpsRecToVecEles(size_t begin, size_t end);

    void removeHdrFromXOredHeaderSets(cstring hdrInstName);
 public:
    ControlBlockInterpreter(ReferenceMap* refMap, TypeMap* typeMap, 
        P4::ParserStructuresMap* parserStructures, cstring parserFQN, 
        HdrValidityOpsRecVec* xoredHdrValidityOps, 
        P4::HdrValidityOpsPkgMap* hdrValidityOpsPkgMap) 
      : refMap(refMap), typeMap(typeMap), parserStructures(parserStructures), 
        parserFQN(parserFQN), xoredHdrValidityOps(xoredHdrValidityOps), 
        hdrValidityOpsPkgMap(hdrValidityOpsPkgMap) {

        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        CHECK_NULL(parserStructures);  
        parserStructure = nullptr;
        factory = new SymbolicValueFactory(typeMap);
        maxIncr = 0;
        maxDecr = 0;
        minIncr = 0;
        minDecr = 0;
        maxExtLen = 0;
        accumDecrPktLen = 0;
    }

    Visitor::profile_t init_apply(const IR::Node* node) override { 
        BUG_CHECK(node->is<IR::P4Control>(), "%1%: expected a P4Control", node);
        auto iter = parserStructures->find(parserFQN);
        if (iter != parserStructures->end())
            parserStructure = iter->second;
        return Inspector::init_apply(node);
    }

    bool preorder(const IR::P4Control* p4Control) override;
    bool preorder(const IR::SwitchStatement* swStmt) override;
    bool preorder(const IR::SwitchCase* switchCase) override;
    bool preorder(const IR::IfStatement* ifStmt) override;
    
    bool preorder(const IR::MethodCallExpression* mce) override;
    bool preorder(const IR::P4Action* p4action) override;
    bool preorder(const IR::P4Table* p4Table) override;
    bool preorder(const IR::ActionList* actionList) override;
    bool preorder(const IR::ActionListElement* ale) override;

    bool preorder(const IR::P4ComposablePackage* p4cp) override;

    unsigned getMaxExtLen() const { return maxExtLen; }
    unsigned getMaxIncrPktLen() const { return maxIncr; }
    unsigned getMaxDecrPktLen() const { return maxDecr; }
};

}  // namespace P4

#endif /* _MIDEND_CONTROLBLOCKINTERPRETER_H_ */
