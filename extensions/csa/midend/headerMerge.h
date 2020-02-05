
#ifndef _EXTENSIONS_CSA_HEADERMERGE_H_
#define _EXTENSIONS_CSA_HEADERMERGE_H_

#include "ir/ir.h"
#include "frontends/p4/typeMap.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/coreLibrary.h"

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
        friend class HeaderRenamer;
        P4::TypeMap* typeMap;
        IR::Type_Struct* rootHeader;
        const cstring rootHeaderName1;
        const cstring rootHeaderName2;
        cstring rootHeaderName;
        std::map<cstring, cstring> rootFields1;
        std::map<cstring, cstring> rootFields2;
        std::vector<IR::Type_Header*> subHeaders;
        std::map<const IR::Type_StructLike*, HeaderMapping> hdrMap1;
        std::map<const IR::Type_StructLike*, HeaderMapping> hdrMap2;

      public:
        IR::Member* addFrom1(const IR::Expression* expr1);
        IR::Member* addFrom2(const IR::Expression* expr2);
        IR::Member* setEquivalent(const IR::Expression* h1, const IR::Expression* h2);
        IR::Type_Struct* getRootHeaderType();
        bool checkEquivalent(const IR::Type* type1, const IR::Type* type2);

        HeaderMerger(P4::TypeMap* typeMap)
            : typeMap(typeMap),
              rootHeaderName1("hdr"),
              rootHeaderName2 ("hdr"),
              rootHeaderName("hdrm") {
            rootHeader = new IR::Type_Struct(IR::ID(rootHeaderName));
            CHECK_NULL(typeMap);
        }
    };

    class HeaderRenamer final : public Transform {
        P4::ReferenceMap* refMap;
        P4::TypeMap* typeMap;
        HeaderMerger* merger;
        bool inPkg1;
        bool inPkg2;
        cstring pkgName1;
        cstring pkgName2;
        cstring rootHeaderName1;
        cstring rootHeaderName2;

        const IR::Node* preorder(IR::P4Program* p) override;
        const IR::Node* preorder(IR::P4ComposablePackage* p) override;
        const IR::Node* preorder(IR::Member* m) override;
        const IR::Node* preorder(IR::Path* p) override;

    public:
        HeaderRenamer(P4::ReferenceMap* refMap,
                      P4::TypeMap* typeMap,
                      HeaderMerger* merger,
                      cstring pkgName1,
                      cstring pkgName2)
            : refMap(refMap), typeMap(typeMap), merger(merger),
            inPkg1(false), inPkg2(false),
            pkgName1(pkgName1), pkgName2(pkgName2) {
            CHECK_NULL(refMap);
            CHECK_NULL(typeMap);
            CHECK_NULL(merger);
        }
    };
}

#endif /* _EXTENSIONS_CSA_HEADERMERGE_H_ */
