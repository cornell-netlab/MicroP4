/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _MIDEND_COMPOSABLEPACKAGEINTERPRETER_H_
#define _MIDEND_COMPOSABLEPACKAGEINTERPRETER_H_

#include "ir/ir.h"
#include "frontends/common/resolveReferences/referenceMap.h"
#include "frontends/p4/typeMap.h"
#include "frontends/p4/coreLibrary.h"


namespace P4 {

class ComposablePackageInterpreter : public Inspector {
    ReferenceMap*       refMap;
    TypeMap*            typeMap;

 public:
     ComposablePackageInterpreter(ReferenceMap* refMap, TypeMap* typeMap) :
            refMap(refMap), typeMap(typeMap) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
    }

    bool preorder(const IR::P4Control* p4Control) override;

    bool preorder(const IR::P4Parser* p4Parser) override;

    bool preorder(const IR::P4ComposablePackage* p4cp) override;

    bool preorder(const IR::P4Program* p4Program) override;
};

}  // namespace P4

#endif /* _MIDEND_COMPOSABLEPACKAGEINTERPRETER_H_ */
