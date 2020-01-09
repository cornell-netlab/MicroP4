/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */
#include "frontends/p4/methodInstance.h"
#include "identifyStorage.h"
#include "msaNameConstants.h"

namespace CSA {

bool IdentifyStorage::preorder(const IR::ArrayIndex* ai) {
    visit(ai->left);
    auto c = ai->right->to<IR::Constant>();
    arrayIndex = c->asInt();
    return false;
}

bool IdentifyStorage::preorder(const IR::Member* mem) {

    if (level < 0) {
        return false;
    }
    auto type = typeMap->getType(mem, true);

    if (auto ts = type->to<IR::Type_Stack>()) {
        type = ts->elementType;
        names.emplace_back(mem->member);
    }

    if (auto ht = type->to<IR::Type_Header>()) {
        if ((ht->getName() == NameConstants::multiByteHdrTypeName) ||
            (ht->getName() == NameConstants::headerTypeName))  {
            msaHeaderStorage = true;
            names.emplace_back(mem->member);
            return false;
        }
    }

    if (auto ts = type->to<IR::Type_Struct>()) {
        names.emplace_back(mem->member);
        types.emplace_back(ts);
    }

    level--;
    visit(mem->expr);
    return false;
}

bool IdentifyStorage::preorder(const IR::PathExpression* pe) {
    auto type = typeMap->getType(pe, true);
    auto ts = type->to<IR::Type_Struct>();
    return false;
}

cstring IdentifyStorage::getName(unsigned level) {
    return names[level];
}

const IR::Type* IdentifyStorage::getType(unsigned level) {
    return types[level];
}

int IdentifyStorage::getArrayIndex() {
    return arrayIndex;
}

bool IdentifyStorage::isMSAHeaderStorage() {  
    return msaHeaderStorage;
}


}// namespace CSA
