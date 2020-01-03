/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_MIDEND_REMOVEMSACONSTRUCTS_H_ 
#define _EXTENSIONS_CSA_MIDEND_REMOVEMSACONSTRUCTS_H_ 

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"
#include "frontends/p4/coreLibrary.h"


namespace CSA {

class RemoveMSAConstructs final : public Transform {

 public:
    using Transform::preorder;
    using Transform::postorder;

    explicit RemoveMSAConstructs() {
        setName("RemoveMSAConstructs"); 
    }
    const IR::Node* preorder(IR::Type_Extern* te) override;
};


}  // namespace CSA

#endif /* _EXTENSIONS_CSA_LINKER_PARSERCONVERTER_H_ */
