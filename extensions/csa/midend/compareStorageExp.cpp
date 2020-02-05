/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */
#include "compareStorageExp.h"


namespace CSA {

bool CompareStorageExp::preorder(const IR::ArrayIndex* ai) {
    auto ca = curr->to<IR::ArrayIndex>();
    if (ca == nullptr) {
        if (compareSub && !subExpMatchStart) {
            visit(ai->left);
            return false;
        }
        result = false;
        return false;
    }
    if (compareSub && !subExpMatchStart)
        subExpMatchStart = true;
    curr = ca->left;
    visit(ai->left);
    curr = ca->right;
    visit(ai->right);
    return false;
}

bool CompareStorageExp::preorder(const IR::Member* mem) {
    auto cm = curr->to<IR::Member>();
    if (cm == nullptr) {
        result = false;
        return false;
    }
    auto tm = typeMap->getType(mem);
    auto tc = typeMap->getType(curr);
    if (mem->member != cm->member) {
        if (compareSub && !subExpMatchStart) {
            visit(mem->expr);
            return false;
        }
        result = false;
        return false;
    }
    if (tm != tc) { 
        std::cout<<tm<<"\n did not match with \n";
        std::cout<<tc<<"\n";
        result = false;
        return false;
    }
    if (compareSub && !subExpMatchStart)
        subExpMatchStart = true;
    curr = cm->expr;
    visit(mem->expr);
    return false;
}

bool CompareStorageExp::preorder(const IR::PathExpression* pe) {
    auto cpe = curr->to<IR::PathExpression>();
    if (cpe == nullptr) {
        result = false;
        return false;
    }
    if (pe->path->name != cpe->path->name) {
        result = false;
        return false;
    }
    return false;
}

bool CompareStorageExp::preorder(const IR::Constant* c) {
    auto cc = curr->to<IR::Constant>();
    if (cc == nullptr) {
        result = false;
        return false;
    }
    if (c->asUnsigned() != cc->asUnsigned()) {
        result = false;
        return false;
    }
    return false;
}

bool CompArgParamToStorageExp::preorder(const IR::Member* mem) {
    auto cm = curr->to<IR::Member>();
    auto cpe = curr->to<IR::PathExpression>();
    if (cm == nullptr && cpe == nullptr) {
        result = false;
        return false;
    }
    if (cpe != nullptr && matchingCE && param->name == cpe->path->name) {
        curr = arg;
        cm = curr->to<IR::Member>();
        matchingCE = false;
    }

    auto tm = typeMap->getType(mem);
    auto tc = typeMap->getType(curr);
    if (mem->member != cm->member) {
        result = false;
        return false;
    }
    if (tm != tc) { 
        std::cout<<tm<<"\n did not match with \n";
        std::cout<<tc<<"\n";
        result = false;
        return false;
    }
    curr = cm->expr;
    visit(mem->expr);
    return false;
}

bool CompArgParamToStorageExp::preorder(const IR::PathExpression* pe) {
    auto cpe = curr->to<IR::PathExpression>();
    if (cpe == nullptr) {
        result = false;
        return false;
    }
    if (pe->path->name != cpe->path->name) {
        result = false;
        return false;
    }
    return false;
}



}// namespace CSA
