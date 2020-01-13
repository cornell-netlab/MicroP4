/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_BACKEND_TOFINO_REPLACEBYTEHDRSTACK_H_ 
#define _EXTENSIONS_CSA_BACKEND_TOFINO_REPLACEBYTEHDRSTACK_H_ 

#include "ir/ir.h"
#include "lib/ordered_map.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeMap.h"
#include "frontends/p4/typeChecking/typeChecker.h"

/*
 * This pass replaces the stack of single byte headers to multiple stacks of
 * maximum 32 two-byte headers. Tofino's requirement
 */
namespace CSA {


class CompareExpression final : public Inspector {

    const IR::Expression* currExpr = nullptr;
    bool* match;

  public:
    explicit CompareExpression(const IR::Expression* currExpr, 
        bool* match) : currExpr(currExpr), match(match) {
        CHECK_NULL(match);
        CHECK_NULL(currExpr);
        *match = true;
    }

    bool preorder(const IR::Member* mem) override;
    bool preorder(const IR::PathExpression* pe) override;
    bool preorder(const IR::ArrayIndex* ai) override;
    bool preorder(const IR::Constant* c) override;

};
 
  
class ReplaceByteHdrStack final : public Transform {

    unsigned byteStackSize;

    unsigned stackSize;
    unsigned hdrBitWidth;
    cstring fieldName;
 
    bool addOneByteHdr = false;
    unsigned* numFullStacks;
    unsigned* residualStackSize;

    int getIndexOfByteStack(const IR::Member* member, IR::Expression** subExp);
    bool translateIndexAndSlice(unsigned in, unsigned h, unsigned l,
        unsigned& stackNumber, unsigned& stackIndex, unsigned& nh, unsigned& nl);

  public:
    explicit ReplaceByteHdrStack(unsigned stackSize, unsigned hdrBitWidth, 
        unsigned* numFullStacks, unsigned* residualStackSize)
      : stackSize(stackSize), hdrBitWidth(hdrBitWidth), 
        numFullStacks(numFullStacks), residualStackSize(residualStackSize) {
        CHECK_NULL(numFullStacks);
        CHECK_NULL(residualStackSize);
        *residualStackSize = 0;
        *numFullStacks = 0;
        byteStackSize = 0;
    }

    const IR::Node* preorder(IR::Type_Header* typeHdr) override;
    const IR::Node* preorder(IR::Type_Struct* typeStruct) override;

    const IR::Node* preorder( IR::Member* member) override;
    const IR::Node* preorder(IR::Slice* slice) override;

    const IR::Node* postorder(IR::P4Program* p4program) override;


};

class FoldLExpSlicesInAsStmts final : public Transform {

    const IR::Expression* lExpMember = nullptr;
    const IR::Expression* currentSubLExpMember = nullptr;

    // <l, h>              
    std::vector<std::pair<unsigned, unsigned>> slices;
    IR::Vector<IR::Expression> rightExprVec;


    bool match;
    void resetFoldContext();
    bool matchLExpSliceIndices(const IR::Expression* lexp, unsigned& l, 
                               unsigned& h, bool& pushDir);

    IR::AssignmentStatement* fold();
  public:
    explicit FoldLExpSlicesInAsStmts() { }

    const IR::Node* preorder(IR::AssignmentStatement* as) override;
    const IR::Node* postorder(IR::StatOrDecl* sd) override;
    const IR::Node* preorder(IR::BlockStatement* bs) override;

    const IR::Node* preorder(IR::Member* mem) override;
    const IR::Node* preorder(IR::PathExpression* pe) override;
    const IR::Node* preorder(IR::ArrayIndex* pe) override;
    const IR::Node* preorder(IR::Constant* c) override;

};


class FlattenConcatExpression final : public Inspector {

    IR::Vector<IR::Expression>* exprVec;
  public:
    FlattenConcatExpression(IR::Vector<IR::Expression>* exprVec) 
      : exprVec(exprVec) {
        CHECK_NULL(exprVec);
    }

    bool preorder(const IR::Concat* concat) override;
};


/*
 * This pass evaluates concat on slices. If operands are consecutives slices of
 * the same field or variable, they are replaced with single slice operation.
 */
class ReduceConcatExpression final : public Transform {

    const IR::Expression* currExpr = nullptr;
    bool match = true;

    const IR::Expression* reduce(const IR::Slice* curr, unsigned l, 
                            unsigned h);
    bool checkReducibility(const IR::Slice* curr, const IR::Slice* exp, 
                           unsigned curL, unsigned& newL);
    const IR::Expression* createConcat(IR::Vector<IR::Expression>& vec);
  public:
    explicit ReduceConcatExpression() { 
        visitDagOnce = false;
    }

    const IR::Node* preorder(IR::Concat* concat) override;
};

class RemoveExplicitSlices final : public Transform {

    P4::ReferenceMap*       refMap;
    P4::TypeMap*            typeMap;
  public:
    RemoveExplicitSlices(P4::ReferenceMap* refMap, P4::TypeMap* typeMap) 
      : refMap(refMap), typeMap(typeMap) {
    }
    const IR::Node* preorder(IR::Slice* slice) override;
};

class ReplaceMSAByteHdrStack final : public PassManager {

    P4::ReferenceMap*       refMap;
    P4::TypeMap*            typeMap;
  public:
    explicit ReplaceMSAByteHdrStack(P4::ReferenceMap* refMap, P4::TypeMap* typeMap,
        unsigned stackSize, unsigned newFieldBitWidth, 
        unsigned* numFullStacks, unsigned* residualStackSize)
      : refMap(refMap), typeMap(typeMap) {
        CHECK_NULL(numFullStacks);
        CHECK_NULL(residualStackSize);
        passes.push_back(new CSA::ReplaceByteHdrStack(stackSize, 
                          newFieldBitWidth, numFullStacks, residualStackSize));
        passes.push_back(new CSA::FoldLExpSlicesInAsStmts());
        passes.push_back(new CSA::ReduceConcatExpression());
    }

    void end_apply(const IR::Node* node) override { 
        refMap->clear();
        typeMap->clear();
        PassManager::end_apply(node);
    }

    static cstring getHdrStackInstName(unsigned sn);
};

}

#endif  /* _EXTENSIONS_CSA_BACKEND_TOFINO_REPLACEBYTEHDRSTACK_H_ */
