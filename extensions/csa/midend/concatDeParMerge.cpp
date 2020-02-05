/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */
#include "concatDeParMerge.h"
#include "compareStorageExp.h"

namespace CSA {


bool FindDeclaration::preorder(const IR::Path* path) {
    (*decl) = refMap->getDeclaration(path, true);
    return false;
}

bool FindConcatCntxts::preorder(const IR::P4ComposablePackage* cp) {
    return true;
}

bool FindConcatCntxts::preorder(const IR::P4Parser* p4Parser) {

    auto cp = findContext<IR::P4ComposablePackage>();
    if (cp == p4cp)
        return false;
    return true;
}

bool FindConcatCntxts::preorder(const IR::ParserState* ps) {
    if (ps->name == IR::ParserState::start)
        visit(ps->selectExpression);
    return false;
}

bool FindConcatCntxts::preorder(const IR::SelectExpression* se) { 
    // overly simplified assumption

    parserSelectExpr = se->select->components[0];

    const IR::IDeclaration* decl = nullptr;
    FindDeclaration fd(refMap, &decl);
    parserSelectExpr->apply(fd);

    auto param = decl->to<IR::Parameter>();
    BUG_CHECK(param != nullptr, "expected parameter here");

    auto p4Parser = findContext<IR::P4Parser>();
    auto pap = p4Parser->getApplyParameters();
    unsigned short in = 0;
    for (; in<pap->size(); in++) {
        if (pap->parameters[in] == param)
            break;
    }
    // from micro_parser signature
    BUG_CHECK(in==5 || in==6, " did not expect this scenario");
    size_t pkgAplIndex = in==5 ? 2 : 4;

    auto ae = argToExprs[pkgAplIndex].first;
    CompArgParamToStorageExp capm(refMap, typeMap, param, parserSelectExpr, ae);
    const auto& exprsInCaller = argToExprs[pkgAplIndex].second;
    const IR::Expression* callerExprInArg = nullptr;
    size_t s = 0;
    for (auto e : exprsInCaller) {
        e->apply(capm);
        if (capm.isMatch()) {
            callerExprInArg = e;
            break;
        }
    }
    for (auto pair : exprsToParamsMap) {
        if (pair.first == callerExprInArg)
            concatCntxt->first.insert(pair.second->to<IR::Member>());
    }
    return false;
}

bool FindConcatCntxts::preorder(const IR::P4Control* p4control) {
    auto cp = findContext<IR::P4ComposablePackage>();
    if (cp != p4cp)
        return false;

    callerP4ControlApplyParams = p4control->getApplyParameters();
    return true;
}

void FindConcatCntxts::postorder(const IR::P4Control* p4control) {
    callerP4ControlApplyParams = nullptr;
    return;
}

bool FindConcatCntxts::preorder(const IR::MethodCallStatement* mcs) {
    auto mi = P4::MethodInstance::resolve(mcs->methodCall, refMap, typeMap);
    if (!mi->isApply())
        return false;
    auto applyMethod = mi->to<P4::ApplyMethod>();
    if (applyMethod == nullptr)
        return false;
    const IR::P4ComposablePackage* cp = nullptr;
    if (applyMethod->applyObject->is<IR::P4ComposablePackage>())
        auto cp = applyMethod->applyObject->to<IR::P4ComposablePackage>();
    if (cp == nullptr)
        return false;

    for (auto a : *(mcs->methodCall->arguments)) {
        auto ae = a->expression;
        std::vector<const IR::Expression*> mappedExpr;
        CompareStorageExp cse(refMap, typeMap, ae, true);
        for (auto e : exprsToParamsMap) {
            e.first->apply(cse);
            if (cse.isMatch()) {
                mappedExpr.push_back(e.first);
            }
        }
        argToExprs.emplace_back(ae, mappedExpr);
    }

    visit(cp);
    return false;
}

bool FindConcatCntxts::preorder(const IR::AssignmentStatement* asmt) {
    auto p4c = findContext<IR::P4Control>();
    if (!(asmt->right->is<IR::Member>() || 
          asmt->right->is<IR::PathExpression>() || p4c != nullptr))
      return false;
    
    const IR::IDeclaration* decl = nullptr;
    FindDeclaration fd(refMap, &decl);
    asmt->right->apply(fd);
    if (decl->is<IR::Parameter>()) {
        auto param = decl->is<IR::Parameter>();
        exprsToParamsMap.emplace_back(std::make_pair(asmt->left, asmt->right));
    } else if (asmt->left->is<IR::Member>() || 
               asmt->left->is<IR::PathExpression>()) {
        CompareStorageExp cse(refMap, typeMap, asmt->right);
        for (auto e : exprsToParamsMap) {
            // This is equivalent to if (e.first == asmt->left)
            e.first->apply(cse);
            if (cse.isMatch()) {
                exprsToParamsMap.emplace_back(std::make_pair(asmt->left, e.second));
            }
        }
    }
    return false;
}

const IR::Node* ConcatDeParMerge::preorder(IR::P4ComposablePackage* p4cp) {
    return p4cp;
}

const IR::Node* ConcatDeParMerge::postorder(IR::P4ComposablePackage* p4cp) {
    return p4cp;
}

const IR::Node* ConcatDeParMerge::preorder(IR::P4Control* p4control) {
    return p4control;
}

const IR::Node* ConcatDeParMerge::postorder(IR::P4Control* p4control) {
    return p4control;
}

const IR::Node* ConcatDeParMerge::preorder(IR::P4Parser* p4parser) {
    return p4parser;
}

const IR::Node* ConcatDeParMerge::postorder(IR::P4Parser* p4parser) {
    return p4parser;
}



}// namespace CSA
