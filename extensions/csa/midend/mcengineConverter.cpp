/*
 * mcengineConverter.cpp
 *
 *  Created on: Apr 3, 2020
 *      Author: myriana
 */

#include "mcengineConverter.h"
#include "ir/ir.h"
#include "frontends/p4/coreLibrary.h"
#include "frontends/p4/parserCallGraph.h"

namespace CSA {

// replace mcengine.apply with assignments statements;
const IR::Node* MCengineConverter::preorder(IR::MethodCallStatement* mcs) {
/*
    auto expression = mcs->methodCall;
    P4::MethodInstance* mi = P4::MethodInstance::resolve(expression, refMap, typeMap);
    if (!mi->is<P4::ExternMethod>())
        return mcs;
    auto em = mi->to<P4::ExternMethod>();
    if (em->originalExternType->name.name !=
            P4::P4CoreLibrary::instance.mcengine.name
        || em->method->name.name !=
            P4::P4CoreLibrary::instance.mcengine.apply.name)
        return mcs;

    auto arg1 = expression->arguments->at(1);
    auto valueMap = parserStateInfo->after;
    auto sv = valueMap->get(arg1->expression);
    auto shv = sv->to<P4::SymbolicHeader>();
    unsigned start, end;
    shv->getCoordinatesFromBitStream(start, end);
    //LOG3("extract"<<" = x.y["<<start<<", "<<end<<"]"<<"\n");

    auto asmtSmts = createPerFieldAssignmentStmts(arg1->expression,
                                                  start+initOffset);
    auto newMember = new IR::Member(arg1->expression->clone(),
                                    IR::Type_Header::setValid);
    auto mce = new IR::MethodCallExpression(newMember);
    auto setValidMCS =  new IR::MethodCallStatement(mce);

    cstring hdrName = "";
    if (auto hdrMem = arg1->expression->to<IR::Member>())
        hdrName = hdrMem->member;
    if (auto hdrPE = arg1->expression->to<IR::PathExpression>())
        hdrName = hdrPE->path->name;
    cstring hdrValidFlagName = hdrName + NameConstants::hdrValidFlagSuffix;
    auto lhe = new IR::Member(
          new IR::PathExpression(NameConstants::parserMetaStrParamName),
          IR::ID(hdrValidFlagName));
    auto rhe = new IR::BoolLiteral(true);
    auto as = new IR::AssignmentStatement(lhe, rhe);

    auto retVec = new IR::IndexedVector<IR::StatOrDecl>();
    // retVec->push_back(setValidMCS);
    retVec->push_back(as);
    retVec->append(asmtSmts);
    prune();
    return retVec;
    */
}

std::vector<const IR::AssignmentStatement*>
MCengineConverter::createPerFieldAssignmentStmts(const IR::Expression* hdrVar,
                                                   unsigned startOffset) {

}



}


