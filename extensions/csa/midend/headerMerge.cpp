#include "headerMerge.h"

namespace CSA {
    IR::Member* HeaderMerger::setEquivalent(const IR::Member* expr1, const IR::Member* expr2) {
        auto type1 = typeMap->getType(expr1);
        auto type2 = typeMap->getType(expr2);

        if (!type1->is<IR::Type_Header>()
            || !type2->is<IR::Type_Header>()) {
            ::error("Cannot merge expressions with non-header type: %1% %2%",
                    type1, type2);
            return nullptr;
        }

        auto hdr1 = type1->to<IR::Type_Header>();
        auto hdr2 = type2->to<IR::Type_Header>();
        IR::ID name = IR::ID(hdr1->name.name + "_" + hdr2->name.name);
        auto hdrm = new IR::Type_Header(name);

        if (!checkEquivalent(hdr1, hdr2)) {
            ::error("types not equivalent %1% <> %2", hdr1, hdr2);
        }

        std::map<cstring, cstring> fieldMap1;
        std::map<cstring, cstring> fieldMap2;

        for (size_t i = 0; i < hdr1->fields.size(); i++) {
            auto field1 = hdr1->fields.at(i);
            auto field2 = hdr2->fields.at(i);
            auto fieldm = field1->clone();
            hdrm->fields.pushBackOrAppend(fieldm);
            fieldMap1.emplace(field1->name.name, fieldm->name.name);
            fieldMap2.emplace(field2->name.name, fieldm->name.name);
        }

        HeaderMapping map1(hdrm, fieldMap1);
        HeaderMapping map2(hdrm, fieldMap2);
        hdrMap1.emplace(hdr1, map1);
        hdrMap2.emplace(hdr2, map2);
        subHeaders.push_back(hdrm);

        auto rootField = new IR::StructField(IR::ID(expr1->member.name), hdrm);
        rootHeader->fields.pushBackOrAppend(rootField);
        rootFields1.emplace(expr1->member.name, rootField->name);
        rootFields2.emplace(expr2->member.name, rootField->name);
        auto pathExpr = new IR::PathExpression(IR::ID(rootHeaderName));
        return new IR::Member(pathExpr, rootField->name);

    }

    bool HeaderMerger::checkEquivalent(const IR::Type* type1, const IR::Type* type2) {
        if (type1->is<IR::Type_Name>()) {
            BUG("type %1% is only a type name", type1);
        }
        if (type2->is<IR::Type_Name>()) {
            BUG("type %1% is only a type name", type1);
        }

        if (typeMap->equivalent(type1, type2))
            return true;

        if (type1->is<IR::Type_StructLike>()) {
            auto sl = type1->to<IR::Type_StructLike>();
            auto sr = type2->to<IR::Type_StructLike>();
            if (sl->fields.size() != sr->fields.size())
                return false;
            for (size_t i = 0; i < sl->fields.size(); i++) {
                auto fl = sl->fields.at(i);
                auto fr = sr->fields.at(i);
                if (!checkEquivalent(fl->type, fr->type))
                    return false;
            }
            return true;
        }

        return false;
    }
}
