
#ifndef _EXTENSIONS_CSA_HEADERMERGE_H_
#define _EXTENSIONS_CSA_HEADERMERGE_H_

#include "ir/ir.h"
#include "frontends/p4/typeMap.h"

namespace CSA {
    class HeaderMapping {
      public:
        IR::Type_Header* hdr;
        std::map<cstring, cstring> fieldNames;
        HeaderMapping(IR::Type_Header* hdr, std::map<cstring, cstring> fieldNames)
            : hdr(hdr), fieldNames(fieldNames) {
            CHECK_NULL(hdr);
        }
    };

    class HeaderMerger {
        P4::TypeMap* typeMap;
        cstring rootHeaderName;
        IR::Type_Struct* rootHeader;
        std::map<cstring, cstring> rootFields1;
        std::map<cstring, cstring> rootFields2;
        std::vector<IR::Type_Header*> subHeaders;
        std::map<const IR::Type_StructLike*, HeaderMapping> hdrMap1;
        std::map<const IR::Type_StructLike*, HeaderMapping> hdrMap2;

      public:
        IR::Member* setEquivalent(const IR::Member* h1, const IR::Member* h2);
        IR::Type_Struct* getRootHeaderType();
        bool checkEquivalent(const IR::Type* type1, const IR::Type* type2);

        HeaderMerger(P4::TypeMap* typeMap) : typeMap(typeMap) {
            CHECK_NULL(typeMap);
        }
    };
}

#endif /* _EXTENSIONS_CSA_HEADERMERGE_H_ */
