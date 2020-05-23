/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_BACKEND_TOFINO_V1MODELCONSTANTS_H_ 
#define _EXTENSIONS_CSA_BACKEND_TOFINO_V1MODELCONSTANTS_H_ 

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"

namespace CSA {

class V1ModelConstants {

  public:
    static const std::unordered_set<cstring> archP4ControlNames;

    static const cstring csaPacketStructInstanceName;
    static const cstring metadataArgName;
    static const cstring stdMetadataArgName;
    static const cstring userMetadataStructTypeName;

    static const cstring parserName;
    static const cstring deparserName;
    static const cstring ingressControlName;
    static const cstring egressControlName;
    static const cstring verifyChecksumName;
    static const cstring computeChecksumName;

  private:
    explicit V1ModelConstants() {}
};

}   // namespace CSA
#endif  /* _EXTENSIONS_CSA_BACKEND_TOFINO_V1MODELCONSTANTS_H_ */
