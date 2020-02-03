#ifndef _EXTENSIONS_CSA_HEADERMERGE_H_
#define _EXTENSIONS_CSA_HEADERMERGE_H_

#include "ir/ir.h"
#include "frontends/p4/typeMap.h"

namespace CSA {
    class TypeUpdates {
    };
    class HeaderMerger {
        P4::TypeMap* oldTypeMap;
        P4::TypeMap* newTypeMap;
        TypeUpdates* updates1;
        TypeUpdates* updates2;

      public:
        const IR::Type* setEquivalent(const IR::Type* type1, const IR::Type* type2);
        bool checkEquivalent(const IR::Type* type1, const IR::Type* type2);

        HeaderMerger(P4::TypeMap* typeMap) : oldTypeMap(typeMap) {
            CHECK_NULL(typeMap);
        }
    };
}

#endif /* _EXTENSIONS_CSA_HEADERMERGE_H_ */
