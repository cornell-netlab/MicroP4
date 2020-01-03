/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_LINKER_DEPARSERINVERTER_H_ 
#define _EXTENSIONS_CSA_LINKER_DEPARSERINVERTER_H_ 

#include <tuple>
#include "ir/ir.h"
#include "lib/ordered_map.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeMap.h"
#include "midend/interpreter.h"
#include "msaNameConstants.h"

namespace CSA {

/*
 *  This pass inverses deparser into parser.
 *  It is a dumb pass that perfoms inverse operation by swapping left-right 
 *  of assignment statements.
 */

class DeparserInverter final : public Transform {
    
    cstring newName;
    cstring headerTypeName;
    cstring headerParamName;

    std::map<cstring, cstring> newNameMap;
 public:
    using Transform::preorder;
    using Transform::postorder;

    explicit DeparserInverter(cstring newName, cstring headerTypeName, 
        cstring headerParamName) 
      : newName(newName), headerTypeName(headerTypeName), 
        headerParamName(headerParamName) {
        setName("DeparserInverter"); 
    }

    const IR::Node* preorder(IR::P4Action* act) override;
    const IR::Node* preorder(IR::P4Table* act) override;
    const IR::Node* preorder(IR::P4Control* deparser) override;
    const IR::Node* preorder(IR::Type_Control* control) override;
    const IR::Node* preorder(IR::AssignmentStatement* as) override;
    const IR::Node* preorder(IR::Path* p) override;
    const IR::Node* preorder(IR::Parameter* p) override;
};


}  // namespace CSA

#endif /* _EXTENSIONS_CSA_LINKER_DEPARSERINVERTER_H_ */
