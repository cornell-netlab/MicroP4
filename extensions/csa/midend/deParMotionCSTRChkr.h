/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_MIDEND_DEPARMOTIONCSTRCHKR_h_
#define _EXTENSIONS_CSA_MIDEND_DEPARMOTIONCSTRCHKR_h_

#include "ir/ir.h"
#include "frontends/common/resolveReferences/referenceMap.h"
#include "frontends/p4/typeMap.h"
#include "frontends/p4/coreLibrary.h"
#include "frontends/p4/typeChecking/typeChecker.h"

#include "midend/composablePackageInterpreter.h"  

namespace CSA {

class DeParMotionCSTRChkr : public Inspector {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    const IR::P4ComposablePackage* cp2;
 public:
    DeParMotionCSTRChkr(P4::ReferenceMap* refMap, P4::TypeMap* typeMap,
      const IR::P4ComposablePackage* cp2)
        : refMap(refMap), typeMap(typeMap), cp2(cp2) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        setName("DeParMotionCSTRChkr"); 
    }

    Visitor::profile_t init_apply(const IR::Node* node) override;
    bool preorder(const IR::P4ComposablePackage* p4cp) override;
    bool preorder(const IR::P4Program* p4Program) override;

    bool preorder(const IR::MethodCallStatement* mcs) override;

};




}  // namespace P4

#endif /* _EXTENSIONS_CSA_MIDEND_DEPARMOTIONCSTRCHKR_h_ */
