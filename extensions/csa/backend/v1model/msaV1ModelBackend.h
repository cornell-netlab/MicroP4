/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_SWITCH_CSAV1MODELBACKEND_H_
#define _EXTENSIONS_CSA_SWITCH_CSAV1MODELBACKEND_H_

#include "ir/ir.h"
#include "frontends/common/options.h"
#include "../switch/options.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeMap.h"

namespace CSA {

class CSAV1ModelBackend {
    std::vector<DebugHook> hooks;

    CSAOptions csaOptions;
    const IR::P4Program* getV1ModelIR();
    const IR::P4Program* getTofinoIR();
    const IR::P4Program* getCoreIR();

 public:
    P4::ReferenceMap       refMap;
    P4::TypeMap            typeMap;
    bool isv1;

    explicit CSAV1ModelBackend(CSAOptions& options) {
        csaOptions = options;
        isv1 = options.isv1();
        hooks.push_back(options.getDebugHook());
        refMap.setIsV1(isv1);
    }
    void addDebugHook(DebugHook hook) { hooks.push_back(hook); }
    const IR::P4Program* run(const IR::P4Program* program, 
                             std::vector<const IR::P4Program*> precompiledIRs);
};

}  // namespace CSA

#endif /* _EXTENSIONS_CSA_SWITCH_CSAV1MODELBACKEND_H_ */
