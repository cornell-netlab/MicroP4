/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_SWITCH_MSATOFINOBACKEND_H_
#define _EXTENSIONS_CSA_SWITCH_MSATOFINOBACKEND_H_

#include "ir/ir.h"
#include "frontends/common/options.h"
#include "../switch/options.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeMap.h"

namespace CSA {

class MSATofinoBackend {
  private:
    std::vector<DebugHook> hooks;

    CSAOptions csaOptions;
    const IR::P4Program* tnaP4Program;
    MidendContext* midendContext;

 public:
    P4::ReferenceMap       refMap;
    P4::TypeMap            typeMap;
    bool isv1;

    explicit MSATofinoBackend(CSAOptions& options, 
                              const IR::P4Program* tnaP4Prog,
                              MidendContext* midendContext) {
        CHECK_NULL(tnaP4Prog);
        CHECK_NULL(midendContext);
        csaOptions = options;
        tnaP4Program = tnaP4Prog;
        isv1 = options.isv1();
        hooks.push_back(options.getDebugHook());
        refMap.setIsV1(isv1);
    }
    void addDebugHook(DebugHook hook) { hooks.push_back(hook); }
    const IR::P4Program* run(const IR::P4Program* program);
};

}  // namespace CSA

#endif /* _EXTENSIONS_CSA_SWITCH_MSATOFINOBACKEND_H_ */
