/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */
#ifndef _EXTENSIONS_CSA_LINKER_CLONEWITHFRESHPATH_H_ 
#define _EXTENSIONS_CSA_LINKER_CLONEWITHFRESHPATH_H_ 

#include "ir/ir.h"

namespace CSA {

class CloneWithFreshPath final : public Transform {
    
 public:
    using Transform::preorder;
    using Transform::postorder;

    explicit CloneWithFreshPath() {
        setName("CloneWithFreshPath"); 
    }
    const IR::Node* preorder(IR::Path* path) override;
    const IR::Node* preorder(IR::PathExpression* path) override;
};

}  // namespace CSA

#endif /* _EXTENSIONS_CSA_LINKER_CLONEWITHFRESHPATH_H_ */
