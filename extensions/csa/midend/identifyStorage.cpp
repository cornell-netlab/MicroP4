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
    // std::cout<<"preorder level : "<<level<<" mem : "<<mem<<"\n";
    auto type = typeMap->getType(mem, true);

    if (auto ts = type->to<IR::Type_Stack>()) {
        type = ts->elementType;
        names.emplace_back(mem->member);
    }

    if (auto ht = type->to<IR::Type_Header>()) {
        if ((ht->getName() == NameConstants::multiByteHdrTypeName) ||
            (ht->getName() == NameConstants::headerTypeName))  {
            msaHeaderStorage = true;
            return false;
        }
    }
    names.emplace_back(mem->member);
    types.emplace_back(type);

    level--;
    visit(mem->expr);
    return false;
}

bool IdentifyStorage::preorder(const IR::PathExpression* pe) {
    if (level < 0)
        return false;
    // std::cout<<"preorder level : "<<level<<" pe : "<<pe<<"\n";
    auto type = typeMap->getType(pe, true);
    names.emplace_back(pe->path->name);
    types.emplace_back(type);
    level --;
    return false;
}

cstring IdentifyStorage::getName(unsigned l) {
    return names[l];
}

const IR::Type* IdentifyStorage::getType(unsigned l) {
    // std::cout<<"return l "<<l<<" size "<<types.size()<<"\n";
    return types[l];
}

int IdentifyStorage::getArrayIndex() {
    return arrayIndex;
}

bool IdentifyStorage::isMSAHeaderStorage() {  
    return msaHeaderStorage;
}


}// namespace CSA
