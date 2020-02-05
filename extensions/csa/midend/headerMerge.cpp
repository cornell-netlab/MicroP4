#include "headerMerge.h"

namespace CSA {
    IR::Member* HeaderMerger::addFrom1(const IR::Expression* expr) {
        if (!expr->is<IR::Member>()) {
            ::error("Cannot handle non-member expression: %1%", expr);
        }
        auto expr1 = expr->to<IR::Member>();
        auto type1 = typeMap->getType(expr1);
        if (!type1->is<IR::Type_Header>()) {
            ::error("Cannot handle expression with non-header type: %1%", type1);
            return nullptr;
        }
        auto hdr1 = type1->to<IR::Type_Header>();
        auto hdrm = hdr1->clone();
        hdrm->name = IR::ID(hdrm->name.name + "_");
        std::map<cstring, cstring> fieldMap1;

        for (size_t i = 0; i < hdr1->fields.size(); i++) {
            auto field1 = hdr1->fields.at(i);
            fieldMap1.emplace(field1->name.name, field1->name.name);
        }

        HeaderMapping map1(hdrm, fieldMap1);
        hdrMap1.emplace(hdr1, map1);
        subHeaders.push_back(hdrm);

        auto rootField = new IR::StructField(IR::ID(expr1->member.name), hdrm);
        rootHeader->fields.pushBackOrAppend(rootField);
        rootFields1.emplace(expr1->member.name, rootField->name);
        auto pathExpr = new IR::PathExpression(IR::ID(rootHeaderName));
        return new IR::Member(pathExpr, rootField->name);
    }

    IR::Member* HeaderMerger::addFrom2(const IR::Expression* expr) {
        if (!expr->is<IR::Member>()) {
            ::error("Cannot handle non-member expression: %2%", expr);
        }
        auto expr2 = expr->to<IR::Member>();
        auto type2 = typeMap->getType(expr2);
        if (!type2->is<IR::Type_Header>()) {
            ::error("Cannot handle expression with non-header type: %2%", expr2);
            return nullptr;
        }
        auto hdr2 = type2->to<IR::Type_Header>();
        auto hdrm = hdr2->clone();
        hdrm->name = IR::ID(hdrm->name.name + "_");
        std::map<cstring, cstring> fieldMap2;

        for (size_t i = 0; i < hdr2->fields.size(); i++) {
            auto field2 = hdr2->fields.at(i);
            fieldMap2.emplace(field2->name.name, field2->name.name);
        }

        HeaderMapping map2(hdrm, fieldMap2);
        hdrMap2.emplace(hdr2, map2);
        subHeaders.push_back(hdrm);

        auto rootField = new IR::StructField(IR::ID(expr2->member.name), hdrm);
        rootHeader->fields.pushBackOrAppend(rootField);
        rootFields2.emplace(expr2->member.name, rootField->name);
        auto pathExpr = new IR::PathExpression(IR::ID(rootHeaderName));
        return new IR::Member(pathExpr, rootField->name);
    }

    IR::Member* HeaderMerger::setEquivalent(const IR::Expression* expr1, const IR::Expression* expr2) {
        if (!expr1->is<IR::Member>()
            || !expr2->is<IR::Member>()) {
            ::error("Cannot merge non-member expressions: %1% %2%",
                    expr1, expr2);
        }
        auto mem1 = expr1->to<IR::Member>();
        auto mem2 = expr2->to<IR::Member>();

        auto type1 = typeMap->getType(mem1);
        auto type2 = typeMap->getType(mem2);

        if (!type1->is<IR::Type_Header>()
            || !type2->is<IR::Type_Header>()) {
            ::error("Cannot merge memessions with non-header type: %1% %2%",
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

        auto rootField = new IR::StructField(IR::ID(mem1->member.name), hdrm);
        rootHeader->fields.pushBackOrAppend(rootField);
        rootFields1.emplace(mem1->member.name, rootField->name);
        rootFields2.emplace(mem2->member.name, rootField->name);
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

    const IR::Node* HeaderRenamer::preorder(IR::P4Program* p) {
        visit(p->objects);
        for (auto &hdr : merger->subHeaders) {
            p->objects.pushBackOrAppend(hdr);
        }
        p->objects.pushBackOrAppend(merger->rootHeader);
        prune();
        return p;
    }

    const IR::Node* HeaderRenamer::preorder(IR::P4ComposablePackage* p) {
        if (p->name.name == pkgName1) {
            inPkg1 = true;
            inPkg2 = false;
        } else if (p->name.name == pkgName2) {
            inPkg1 = false;
            inPkg2 = true;
        } else {
            inPkg1 = false;
            inPkg2 = false;
            prune();
        }
        return p;
    }

    const IR::Node* HeaderRenamer::preorder(IR::Member* m) {
        auto typ = typeMap->getType(m->expr);
        auto expr = m->expr;
        auto path = m->expr->to<IR::PathExpression>();
        visit(m->expr);
        bool isRoot1 = expr->is<IR::PathExpression>()
            && path->path->name.name == merger->rootHeaderName1;
        bool isRoot2 = expr->is<IR::PathExpression>()
            && path->path->name.name == merger->rootHeaderName2;
        auto structTyp = typ->to<IR::Type_StructLike>();
        if (structTyp == nullptr) {
            return m;
        }
        std::map<cstring, cstring> fieldNames;
        if (inPkg1 && isRoot1) {
            fieldNames = merger->rootFields1;
        } else if (inPkg2 && isRoot2) {
            fieldNames = merger->rootFields2;
        } else {
            fieldNames = merger->hdrMap1.at(structTyp).fieldNames;
        }
        auto newField = fieldNames.at(m->member.name);
        prune();
        m->member = IR::ID(newField);
        return m;
    }

    const IR::Node* HeaderRenamer::preorder(IR::Path* p) {
        if ((inPkg1 && p->name.name == merger->rootHeaderName1)
            || (inPkg2 && p->name.name == merger->rootHeaderName2)) {
            return new IR::Path(IR::ID(merger->rootHeaderName));
        } else {
            return p;
        }
    }
}
