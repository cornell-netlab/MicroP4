#ifndef _EXTENSIONS_CSA_SWITCH_PARSEINPUT_H_
#define _EXTENSIONS_CSA_SWITCH_PARSEINPUT_H_

#include "ir/ir.h"
#include "extensions/csa/switch/options.h"

namespace CSA {
/*
std::vector<std::pair<std::string, const IR::P4Program*>>  
getPreCompiledIRs(CSAOptions& options);
*/

std::vector<const IR::P4Program*> getPreCompiledIRs(CSAOptions& options);
}

#endif /* _EXTENSIONS_CSA_SWITCH_PARSEINPUT_H_ */
