/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_MIDEND_MSAPACKETSUBSTITUTER_H_ 
#define _EXTENSIONS_CSA_MIDEND_MSAPACKETSUBSTITUTER_H_ 

#include "ir/ir.h"
#include "lib/ordered_map.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"
#include "msaNameConstants.h"


namespace CSA {

class MSAPacketSubstituter final : public Transform {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    cstring pathToReplace;
    // cstring replacementPath = NameConstants::csaPacketStructTypeName+"_var";
    cstring intermediatePath = NameConstants::csaPacketStructTypeName+
                              NameConstants::intermediateVarDeclSuffix;
  public:
    explicit MSAPacketSubstituter(P4::ReferenceMap* refMap, P4::TypeMap* typeMap)
        : refMap(refMap), typeMap(typeMap) {
        setName("MSAPacketSubstituter"); 
    }
    const IR::Node* preorder(IR::Path* path) override;
    const IR::Node* preorder(IR::Parameter* param) override;
    const IR::Node* preorder(IR::Declaration_Variable* dv) override;
    const IR::Node* preorder(IR::P4Control* p4control) override;

    void end_apply(const IR::Node* node) override { 
        refMap->clear();
        typeMap->clear();
        Transform::end_apply(node);
    }


};

}

#endif 
