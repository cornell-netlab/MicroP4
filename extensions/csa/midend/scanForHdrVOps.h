/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_LINKER_ScanForHdrVOps_H_ 
#define _EXTENSIONS_CSA_LINKER_ScanForHdrVOps_H_ 

#include <vector>
#include <tuple>
#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeMap.h"

namespace CSA {

class ScanForHdrVOps final : public Inspector {
    
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

    std::vector<std::pair<cstring, cstring>>* hdrTypeInstNames;
 public:

    explicit ScanForHdrVOps(P4::ReferenceMap* refMap, P4::TypeMap* typeMap,
        std::vector<std::pair<cstring, cstring>>* hdrTypeInstNames) 
      : refMap(refMap), typeMap(typeMap), hdrTypeInstNames(hdrTypeInstNames) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap); 
        CHECK_NULL(hdrTypeInstNames);
        setName("ScanForHdrVOps"); 
    }

    bool preorder(const IR::MethodCallExpression* mce) override;
};


}  // namespace CSA

#endif /* _EXTENSIONS_CSA_LINKER_ScanForHdrVOps_H_ */
