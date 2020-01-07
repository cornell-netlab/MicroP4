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

    if (level > 0) {
        level--;
        visit(mem->expr);
        return false;
    }
    auto type = typeMap->getType(mem, true);

    if (auto ts = type->to<IR::Type_Stack>()) {
        type = ts->elementType;
        fieldName = mem->member;
    }

    if (auto ht = type->to<IR::Type_Header>()) {
        if ((ht->getName() == NameConstants::multiByteHdrTypeName) ||
            (ht->getName() == NameConstants::headerTypeName))  {
            msaHeaderStorage = true;
            typeStruct = nullptr;
            fieldName = mem->member;
            return false;
        }
    }

    if (auto ts = type->to<IR::Type_Struct>()) {
        msaHeaderStorage = false;
        if (typeStruct != nullptr) {
            multipleStorages = true;
            typeStruct = nullptr;
            fieldName = "";
        } else {
            fieldName = mem->member;
            typeStruct = ts;
        }
    }

    return false;
}

bool IdentifyStorage::preorder(const IR::PathExpression* pe) {
    auto type = typeMap->getType(pe, true);
    auto ts = type->to<IR::Type_Struct>();
    return false;
}

bool IdentifyStorage::isMSAHeaderStorage() {
    return msaHeaderStorage;
}

bool IdentifyStorage::hasMultipleStorages() {
    return multipleStorages;
}

cstring IdentifyStorage::getFieldName() {
    return fieldName;
}

const IR::Type_Struct* IdentifyStorage::getStructType() {
    return typeStruct;
}

int IdentifyStorage::getArrayIndex() {
    return arrayIndex;
}

}// namespace CSA
