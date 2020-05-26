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
#include "controlStateReconInfo.h"

namespace CSA {

class MSAV1ModelBackend {
  private:
    std::vector<DebugHook> hooks;

    CSAOptions csaOptions;

    const IR::P4Program* v1modelP4Program;

    MidendContext* midendContext;

 public:
    P4::ReferenceMap       refMap;
    P4::TypeMap            typeMap;
    bool isv1;

    explicit MSAV1ModelBackend(CSAOptions& options, 
                               const IR::P4Program* v1modelP4Program,
                               MidendContext* midendContext) {
        CHECK_NULL(v1modelP4Program);
        CHECK_NULL(midendContext);
        csaOptions = options;
        v1modelP4Program = v1modelP4Program;
        midendContext = midendContext;
        isv1 = options.isv1();
        hooks.push_back(options.getDebugHook());
        refMap.setIsV1(isv1);
    }
    void addDebugHook(DebugHook hook) { hooks.push_back(hook); }
    const IR::P4Program* run(const IR::P4Program* program);
};

}  // namespace CSA

#endif /* _EXTENSIONS_CSA_SWITCH_CSAV1MODELBACKEND_H_ */
