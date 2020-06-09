/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_SWITCH_CSAV1MODELBACKEND_H_
#define _EXTENSIONS_CSA_SWITCH_CSAV1MODELBACKEND_H_

#include "ir/ir.h"
#include "frontends/common/options.h"
#include "../switch/msaOptions.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeMap.h"
#include "controlStateReconInfo.h"

namespace CSA {

class MSAV1ModelBackend {
  private:
    std::vector<DebugHook> hooks;

    MSAOptions msaOptions;

 public:
    P4::ReferenceMap       refMap;
    P4::TypeMap            typeMap;
    bool isv1;

    explicit MSAV1ModelBackend(MSAOptions& options) {
        msaOptions = options;
        isv1 = options.isv1();
        hooks.push_back(options.getDebugHook());
        refMap.setIsV1(isv1);
    }
    void addDebugHook(DebugHook hook) { hooks.push_back(hook); }
    const IR::P4Program* run(const IR::P4Program* program, 
          MidendContext* midendContext, const IR::P4Program* v1modelP4Program);
};

}  // namespace CSA

#endif /* _EXTENSIONS_CSA_SWITCH_CSAV1MODELBACKEND_H_ */
