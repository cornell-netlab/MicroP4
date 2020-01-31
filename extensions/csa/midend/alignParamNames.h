#ifndef _EXTENSIONS_CSA_MIDEND_ALIGNPARAMNAMES_H_
#define _EXTENSIONS_CSA_MIDEND_ALIGNPARAMNAMES_H_

#include "ir/ir.h"
#include "frontends/p4/coreLibrary.h"
#include "frontends/common/resolveReferences/referenceMap.h"
#include "frontends/p4/typeMap.h"
#include "frontends/p4/typeChecking/typeChecker.h"

namespace CSA {
    class AlignParamNames final : public Transform {
        P4::ReferenceMap *refMap;
        P4::TypeMap *typeMap;
        cstring packetName;
        cstring ingressMetadataName;
        cstring headerName;
        cstring metadataName;
        cstring inArgName;
        cstring inOutArgName;
        std::map<cstring, cstring> renamings;
        
    public:
        
        explicit AlignParamNames(P4::ReferenceMap* refMap, P4::TypeMap* typeMap) :
            refMap(refMap), typeMap(typeMap)
        {
            LOG1("initializing AlignParamNames");
            CHECK_NULL(refMap);
            CHECK_NULL(typeMap);
            packetName = nullptr;
            ingressMetadataName = nullptr;
            headerName = nullptr;
            metadataName = nullptr;
            inArgName = nullptr;
            inOutArgName = nullptr;
            setName("AlignParamNames");
        }

        const IR::Node* preorder(IR::P4Program* p4program) override;

        const IR::Node* preorder(IR::P4ComposablePackage* cpkg) override;

        const IR::Node* preorder(IR::P4Parser* parser) override;

        const IR::Node* preorder(IR::Type_Parser* parserType) override;

        const IR::Node* preorder(IR::P4Control* control) override;

        const IR::Node* preorder(IR::Type_Control* controlType) override;

        const IR::Node* preorder(IR::ParameterList* params) override;

        const IR::Node* preorder(IR::Parameter* param) override;

        const IR::Node* preorder(IR::Path* path) override;

        void end_apply(const IR::Node* node) override;
        

    private:

        void setOrRename(cstring *classField, const IR::Parameter* param);

    };
} /* namespace CSA */
#endif /* _EXTENSIONS_CSA_MIDEND_ALIGNPARAMNAMES_H_ */
