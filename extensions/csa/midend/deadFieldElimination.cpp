/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */
#include "frontends/p4/methodInstance.h"
#include "deadFieldElimination.h"
#include "msaNameConstants.h"
#include "identifyStorage.h"


namespace CSA {

bool FindModifiedFields::preorder(const IR::AssignmentStatement* asmt) {

    IdentifyStorage isR(refMap, typeMap);
    IdentifyStorage isL(refMap, typeMap);
    asmt->right->apply(isR);
    asmt->left->apply(isL);

    // happens in assignment statements of converted parsers
    if (isR.isMSAHeaderStorage() && !isL.isMSAHeaderStorage()) {
        // Store the type of left expression storage n allUserDefinedHdrTypes
        auto ts = isL.getStructType();
        if (allUserDefinedHdrTypes->getDeclaration(ts->getName()) == nullptr)
            allUserDefinedHdrTypes->push_back(ts);
        return false;
    }

    if ((!isR.isMSAHeaderStorage() && isL.isMSAHeaderStorage()) ||
        (!isR.isMSAHeaderStorage() && isL.isMSAHeaderStorage()) ) {
        return false;
    }

    if (!isR.isMSAHeaderStorage() && !isL.isMSAHeaderStorage()) {
        auto st = isL.getStructType();
        if (st != nullptr) {
            auto fn = isL.getFieldName();
            auto& fm = (*modifiedHdrTypeFields)[st->getName()];
            fm.emplace(fn);
        }
    }
    return true;
}

bool FindModifiedFields::preorder(const IR::Member* mem) {
    auto type = typeMap->getType(mem->expr, true);
    auto ts = type->to<IR::Type_Struct>();
    if (ts == nullptr)
        return false;
    auto& fm =  (*accessedHdrTypeFields)[ts->getName()];
    fm.emplace(mem->member);
    return true;
}

void FindModifiedFields::postorder(const IR::P4Program* program) {

    filterUserDefinedHdrType(modifiedHdrTypeFields);
    filterUserDefinedHdrType(accessedHdrTypeFields);
    return;
}

void FindModifiedFields::filterUserDefinedHdrType(std::unordered_map<cstring, 
                                            std::unordered_set<cstring>>* map) {
    
     std::vector<cstring> remove;
    for (const auto& e : (*map)) {
        if (allUserDefinedHdrTypes->getDeclaration(e.first) == nullptr)
            remove.emplace_back(e.first);
    }
    for (auto r : remove)
        map->erase(r);
}

}// namespace CSA
