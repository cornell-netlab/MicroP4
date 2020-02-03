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
    return false;
}

bool FindConcatCntxts::preorder(const IR::P4Control* p4control) {
    applyParams = p4control->getApplyParameters();
    return true;
}

void FindConcatCntxts::postorder(const IR::P4Control* p4control) {
    applyParams = nullptr;
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

    // put arg
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

const IR::Node* ConcatDeParMerge::preorder(IR::P4ComposablePackage* p4cp) {
    return p4cp;
}

const IR::Node* ConcatDeParMerge::postorder(IR::P4ComposablePackage* p4cp) {
    return p4cp;
}


}// namespace CSA
