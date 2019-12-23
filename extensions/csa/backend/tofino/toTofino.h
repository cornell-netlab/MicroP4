/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_MIDEND_TOV1MODEL_H_ 
#define _EXTENSIONS_CSA_MIDEND_TOV1MODEL_H_ 

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"


namespace CSA {

class CreateTofinoArchBlock final : public Transform {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    cstring headerTypeName;
    const P4ControlPartitionInfoMap* partitionsMap;
    const std::vector<cstring>* partitions;
    unsigned* minExtLen;
    unsigned* maxExtLen;

    std::set<cstring> metadataFields;

    const IR::Node* createMainPackageInstance();
    const IR::Node* createV1ModelParser();
    const IR::Node* createV1ModelDeparser();

    IR::P4Control* createTofinoPipelineControl(cstring name, 
                  IR::BlockStatement* bs = new IR::BlockStatement());

    IR::P4Control* createP4Control(cstring name,
        IR::ParameterList* pl, IR::BlockStatement* bs = new IR::BlockStatement());
    IR::ParameterList* getHeaderMetaPL(IR::Direction dirMSAPkt,
                                       IR::Direction dirUserMeta);

    IR::Type_Struct* createUserMetadataStructType();
    std::vector<const IR::P4Control*> getControls(const IR::P4Program* prog, 
                                                  bool ingress);
    
    const IR::Node* createIngressControl(std::vector<const IR::P4Control*>& p4c,
                                         IR::Type_Struct* typeStruct);

    const IR::Node* createEgressControl(std::vector<const IR::P4Control*>& p4c,
                                        IR::Type_Struct*  typeStruct);
  public:
    explicit CreateTofinoArchBlock(P4::ReferenceMap* refMap, 
        P4::TypeMap* typeMap, cstring headerTypeName, 
        const P4ControlPartitionInfoMap* partitionsMap,
        const std::vector<cstring>* partitions,
        unsigned* minExtLen, unsigned* maxExtLen)
      : refMap(refMap), typeMap(typeMap), headerTypeName(headerTypeName), 
        partitionsMap(partitionsMap), partitions(partitions),
        minExtLen(minExtLen), maxExtLen(maxExtLen) {
        CHECK_NULL(refMap);
        CHECK_NULL(typeMap);
        setName("CreateTofinoArchBlock"); 
    }

    const IR::Node* preorder(IR::P4Program* p4program) override;

    Visitor::profile_t init_apply(const IR::Node* node) override { 
        BUG_CHECK(node->is<IR::P4Program>(), "expected a P4Program");
        return Transform::init_apply(node);
    }

    static const cstring metadataArgName;
    static const cstring stdMetadataArgName;
    static const cstring userMetadataStructTypeName;

    static const cstring csaPacketStructTypeName; // struct with csa_packet_h
    static const cstring csaPacketStructInstanceName; 

    static const cstring parserName;
    static const cstring deparserName;
    static const cstring ingressControlName;
    static const cstring egressControlName;
    static const cstring verifyChecksumName;
    static const cstring computeChecksumName;

};


class CSAStdMetaSubstituter final : public Transform {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

    const IR::Parameter* getStandardMetadataParam(const IR::P4Control* p4c);
  public:
    CSAStdMetaSubstituter(P4::ReferenceMap* refMap, P4::TypeMap* typeMap)
        : refMap(refMap), typeMap(typeMap) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
    }

    const IR::Node* preorder(IR::Path* path) override;
    const IR::Node* preorder(IR::Parameter* parameter) override;
    //const IR::Node* preorder(IR::Argument* arg) override;

    const IR::Node* preorder(IR::MethodCallExpression* mce) override;
    const IR::Node* preorder(IR::MethodCallStatement* mcs) override;
    const IR::Node* preorder(IR::AssignmentStatement* as) override;
    
    void end_apply(const IR::Node* node) override { 
        typeMap->clear();
        refMap->clear();
        Transform::end_apply(node);
    }

};


class ToTofino final : public PassManager {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

  public:
    ToTofino(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
              const P4ControlPartitionInfoMap* partitionsMap,
              const std::vector<cstring>* partitions,
              unsigned* minExtLen, unsigned* maxExtLen)
        : refMap(refMap), typeMap(typeMap) {

        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        CHECK_NULL(partitionsMap); CHECK_NULL(partitions);

        passes.push_back(new CSAStdMetaSubstituter(refMap, typeMap));

        passes.push_back(new P4::ResolveReferences(refMap, true));
        passes.push_back(new P4::TypeInference(refMap, typeMap, false));
        passes.push_back(new CreateTofinoArchBlock(refMap, typeMap, 
                ToControl::headerTypeName, partitionsMap, partitions, 
                minExtLen, maxExtLen));
    }



};


}   // namespace CSA
#endif  /* _EXTENSIONS_CSA_MIDEND_TOV1MODEL_H_ */

