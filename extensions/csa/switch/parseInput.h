/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_SWITCH_PARSEINPUT_H_
#define _EXTENSIONS_CSA_SWITCH_PARSEINPUT_H_

#include "ir/ir.h"
#include "extensions/csa/switch/msaOptions.h"

namespace CSA {
    std::vector<const IR::P4Program*> getPreCompiledIRs(MSAOptions& options);
}

#endif /* _EXTENSIONS_CSA_SWITCH_PARSEINPUT_H_ */
