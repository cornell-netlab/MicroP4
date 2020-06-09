/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */
#include "hdrToStructs.h"
#include "frontends/p4/methodInstance.h"
#include "msaNameConstants.h"

namespace CSA {



bool HdrToStructs::skipHeaderTypes(cstring typeName) {
    if (typeName == NameConstants::multiByteHdrTypeName ||
        typeName == NameConstants::headerTypeName || 
        typeName == NameConstants::indicesHeaderTypeName ||
        typeName == "ingress_intrinsic_metadata_t" ||
        typeName == "egress_intrinsic_metadata_t"  ||
        typeName == "pktgen_timer_header_t" ||
        typeName == "pktgen_port_down_header_t" ||
        typeName == "pktgen_recirc_header_t" ||
        typeName == "ptp_metadata_t")
        return true;

    return false;
}

HdrToStructs::ValidityOPType 
HdrToStructs::getValidityOPFlagName(const IR::MethodCallExpression* mce,
                                    cstring& hdrName, cstring& hdrTypeName) {
    auto mi = P4::MethodInstance::resolve(mce, refMap, typeMap);

    if (mi->is<P4::BuiltInMethod>()) { 
        auto bm = mi->to<P4::BuiltInMethod>();
        auto exp = bm->appliedTo;
        auto basetype = typeMap->getType(exp);
        auto th = basetype->to<IR::Type_Header>();
        BUG_CHECK(th != nullptr, "only HeaderType expected");
        hdrTypeName = th->getName();
        if (auto mem = exp->to<IR::Member>())
            hdrName = mem->member;
        if (auto pe = exp->to<IR::PathExpression>())
            hdrName = pe->path->name;

        if (bm->name == IR::Type_Header::setValid) {
            BUG_CHECK(hdrName != "", "Header not PathExpression or Member expr");
            return ValidityOPType::SetValid;
        } else if (bm->name == IR::Type_Header::setInvalid) {
            BUG_CHECK(hdrName != "", "Header not PathExpression or Member expr");
            return ValidityOPType::SetInvalid;
        } else if (bm->name == IR::Type_Header::isValid) {
            BUG_CHECK(hdrName != "", "Header not PathExpression or Member expr");
            return ValidityOPType::IsValid;
        } else {
            return ValidityOPType::None;
        }

    }
    return ValidityOPType::None;
}

const IR::Node* HdrToStructs::preorder(IR::Type_Header* typeHeader) {
    
  /*
    if (typeHeader->name == NameConstants::multiByteHdrTypeName ||
        typeHeader->name == NameConstants::headerTypeName || 
        typeHeader->name == NameConstants::indicesHeaderTypeName ||
        typeHeader->name == "ingress_intrinsic_metadata_t" ||
        typeHeader->name == "egress_intrinsic_metadata_t"  ||
        typeHeader->name == "pktgen_timer_header_t" ||
        typeHeader->name == "pktgen_port_down_header_t" ||
        typeHeader->name == "pktgen_recirc_header_t" ||
        typeHeader->name == "ptp_metadata_t")
      */

    if (skipHeaderTypes(typeHeader->name))
        return typeHeader;


    IR::IndexedVector<IR::StructField> fields;
    for (auto f : typeHeader->fields)
        fields.push_back(f->clone());
    auto ts = new IR::Type_Struct(typeHeader->name, fields);
    prune();
    return ts;
}


const IR::Node* HdrToStructs::preorder(IR::MethodCallExpression* mce) {

    cstring hdrName = "";
    cstring hdrTypeName = "";
    auto call = getValidityOPFlagName(mce, hdrName, hdrTypeName);
    if (call != ValidityOPType::IsValid)
        return mce;
    if (skipHeaderTypes(hdrTypeName))
        return mce;

    auto hdrVFlagName = hdrName + NameConstants::hdrValidFlagSuffix;
    auto hdrSVFlagName = hdrName + NameConstants::hdrSetValidOpFlagSuffix;

    auto lm = new IR::Member(
        new IR::PathExpression(NameConstants::parserMetaStrParamName), 
        IR::ID(hdrVFlagName));
    auto rm = new IR::Member(
        new IR::PathExpression(NameConstants::headerValidityOpStrParamName), 
        IR::ID(hdrSVFlagName));
    auto borExpr = new IR::LOr(lm, rm);
    prune();
    return borExpr;
}

    
const IR::Node* HdrToStructs::preorder(IR::MethodCallStatement* mcs) {
    cstring hdrName = "";
    cstring hdrTypeName = "";
    auto call = getValidityOPFlagName(mcs->methodCall, hdrName, hdrTypeName);
    if (call == ValidityOPType::None)
        return mcs;
    if (skipHeaderTypes(hdrTypeName))
        return mcs;

    auto stmts = new IR::IndexedVector<IR::StatOrDecl> ();

    auto hdrSVOPFlagName = hdrName + NameConstants::hdrSetValidOpFlagSuffix;
    auto hdrSIVOPFlagName = hdrName + NameConstants::hdrSetInvalidOpFlagSuffix;

    auto lmSV = new IR::Member(
        new IR::PathExpression(NameConstants::headerValidityOpStrParamName), 
        IR::ID(hdrSVOPFlagName));

    auto lmSIV = new IR::Member(
        new IR::PathExpression(NameConstants::headerValidityOpStrParamName), 
        IR::ID(hdrSIVOPFlagName));

    auto cf = new IR::BoolLiteral(false);
    auto ct = new IR::BoolLiteral(true);

    IR:: AssignmentStatement* as0 = nullptr;
    IR:: AssignmentStatement* as1 = nullptr;
    if (call == ValidityOPType::SetValid) {
        as0 = new IR::AssignmentStatement(lmSV, ct);
        as1 = new IR::AssignmentStatement(lmSIV, cf);
    } else if (call == ValidityOPType::SetInvalid) {
        as0 = new IR::AssignmentStatement(lmSV, cf);
        as1 = new IR::AssignmentStatement(lmSIV, ct);
    }
    stmts->push_back(as0);
    stmts->push_back(as1);
    prune();
    return stmts;
}

}// namespace CSA
