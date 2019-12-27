/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_BACKEND_TOFINO_TOTOFINO_H_ 
#define _EXTENSIONS_CSA_BACKEND_TOFINO_TOTOFINO_H_ 

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"


namespace CSA {

class GetCalleeP4Controls final : public Inspector {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

    IR::IndexedVector<IR::Type_Declaration>* callees;
  public:
    explicit GetCalleeP4Controls(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
        IR::IndexedVector<IR::Type_Declaration>* callees) 
      : refMap(refMap), typeMap(typeMap), callees(callees) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        CHECK_NULL(callees);
    }

    bool preorder(const IR::P4Control* mcs) override;
    bool preorder(const IR::MethodCallStatement* mcs) override;
    
    Visitor::profile_t init_apply(const IR::Node* node) {
        BUG_CHECK(node->is<IR::P4Control>(),
            "%1%: expected a P4Control node", node);
        return Inspector::init_apply(node);
    }

};

class MSAStdMetaSubstituter final : public Transform {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    const P4ControlPartitionInfoMap* partitionsMap;
    const std::vector<cstring>* partitions;

    bool ingress;

    IR::IndexedVector<IR::Type_Declaration> ingressControls;
    IR::IndexedVector<IR::Type_Declaration> egressControls;

  public:
    MSAStdMetaSubstituter(P4::ReferenceMap* refMap, P4::TypeMap* typeMap,
          const P4ControlPartitionInfoMap* partitionsMap,
          const std::vector<cstring>* partitions)
        : refMap(refMap), typeMap(typeMap), partitionsMap(partitionsMap), 
          partitions(partitions) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        CHECK_NULL(partitionsMap); CHECK_NULL(partitions);
    }

    const IR::Node* preorder(IR::Path* path) override;
    const IR::Node* preorder(IR::Parameter* parameter) override;
    const IR::Node*preorder(IR::Argument* arg) override;

    const IR::Node* preorder(IR::MethodCallExpression* mce) override;
    const IR::Node* preorder(IR::MethodCallStatement* mcs) override;
    const IR::Node* preorder(IR::P4Program* program) override;

    const IR::Node* preorder(IR::P4Control* p4c) override;

    void end_apply(const IR::Node* node) override { 
        refMap->clear();
        typeMap->clear();
        Transform::end_apply(node);
    }
};


class CreateTofinoArchBlock final : public Transform {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    cstring headerTypeName;
    const P4ControlPartitionInfoMap* partitionsMap;
    const std::vector<cstring>* partitions;
    unsigned* minExtLen;
    unsigned* maxExtLen;
    unsigned hdrBitWidth;
    unsigned stackSize;
    unsigned* numFullStacks;
    unsigned* residualStackSize;

    unsigned maxFullStToExct;
    unsigned maxHdrsToExctResSt;
    unsigned extctResidualByteHdr;

    std::set<cstring> metadataFields;

    IR::P4Control* createP4Control(cstring name, IR::ParameterList* pl, 
                                   IR::BlockStatement* bs);
    std::vector<const IR::P4Control*> getControls(const IR::P4Program* prog, 
                                                  bool ingress);
    IR::ParameterList* getHeaderMetaPL(IR::Direction dirMSAPkt,
                                       IR::Direction dirUserMeta);
    IR::Type_Struct* createUserMetadataStructType();
    

    // Ingress
    const IR::Type_Control* createIngressTypeControl();
    const IR::P4Parser* createTofinoIngressParser();
    const IR::Node* createIngressP4Control(std::vector<const IR::P4Control*>& p4c,
                                         IR::Type_Struct* typeStruct);
    const IR::P4Control* createTofinoIngressDeparser();

    // Egress
    const IR::Node* createTofinoEgressParser();
    const IR::Type_Control* createEgressTypeControl();
    const IR::Node* createEgressP4Control(std::vector<const IR::P4Control*>& p4c,
                                        IR::Type_Struct*  typeStruct);
    const IR::Node* createTofinoEgressDeparser();

    IR::Vector<IR::Node> createMainPackageInstance();

  public:
    explicit CreateTofinoArchBlock(P4::ReferenceMap* refMap, 
        P4::TypeMap* typeMap, cstring headerTypeName, 
        const P4ControlPartitionInfoMap* partitionsMap,
        const std::vector<cstring>* partitions, unsigned* minExtLen, 
        unsigned* maxExtLen, unsigned hdrBitWidth, unsigned stackSize,
        unsigned* numFullStacks, unsigned* residualStackSize)
      : refMap(refMap), typeMap(typeMap), headerTypeName(headerTypeName), 
        partitionsMap(partitionsMap), partitions(partitions),
        minExtLen(minExtLen), maxExtLen(maxExtLen), hdrBitWidth(hdrBitWidth), 
        stackSize(stackSize), numFullStacks(numFullStacks), 
        residualStackSize(residualStackSize) {
        setName("CreateTofinoArchBlock"); 
    }

    const IR::Node* preorder(IR::P4Program* p4program) override;

    Visitor::profile_t init_apply(const IR::Node* node) override { 
        BUG_CHECK(node->is<IR::P4Program>(), "expected a P4Program");
        return Transform::init_apply(node);
    }

    static const cstring csaPacketStructInstanceName;
    static const cstring metadataArgName;
    static const cstring stdMetadataArgName;
    static const cstring userMetadataStructTypeName;

    static const cstring ingressParserName;
    static const cstring egressParserName; 
    static const cstring ingressDeparserName;
    static const cstring egressDeparserName;

    static const cstring ingressControlName; 
    static const cstring egressControlName;

    static const cstring igIMTypeName;
    static const cstring igIMArgName;

    static const cstring igIMFrmParTypeName;
    static const cstring igIMFrmParInstName;

    static const cstring igIMForDePTypeName;
    static const cstring igIMForDePInstName;

    static const cstring igIMForTMTypeName;
    static const cstring igIMForTMInstName;

    static const cstring egIMTypeName; 
    static const cstring egIMArgName;

    static const cstring egIMFrmParTypeName;
    static const cstring egIMFrmParInstName;
    
    static const cstring egIMForDePTypeName;
    static const cstring egIMForDePInstName;

    static const cstring egIMForOPTypeName;
    static const cstring egIMForOPInstName;

    static IR::IndexedVector<IR::Parameter>* createIngressIMParams();
    static IR::Vector<IR::Argument>* createIngressIMArgs();

    static IR::IndexedVector<IR::Parameter>* createEgressIMParams();
    static IR::Vector<IR::Argument>* createEgressIMArgs();
};




class ToTofino final : public PassManager {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

  public:
    ToTofino(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
              const P4ControlPartitionInfoMap* partitionsMap,
              const std::vector<cstring>* partitions,
              unsigned* minExtLen, unsigned* maxExtLen, unsigned hdrBitWidth,
              unsigned stackSize, unsigned* numFullStacks,
              unsigned* residualStackSize)
        : refMap(refMap), typeMap(typeMap) {

        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        CHECK_NULL(partitionsMap); CHECK_NULL(partitions);
        CHECK_NULL(minExtLen); CHECK_NULL(maxExtLen);
        CHECK_NULL(numFullStacks); CHECK_NULL(residualStackSize);

        passes.push_back(new MSAStdMetaSubstituter(refMap, typeMap, partitionsMap, partitions));
        passes.push_back(new P4::ResolveReferences(refMap, true));
        passes.push_back(new P4::TypeInference(refMap, typeMap, false));
        passes.push_back(new CreateTofinoArchBlock(refMap, typeMap, 
              NameConstants::headerTypeName, partitionsMap, partitions, minExtLen, 
              maxExtLen, hdrBitWidth, stackSize, numFullStacks, 
              residualStackSize));
    }


    static std::vector<const IR::P4Control*> getControls(
        const IR::P4Program* prog, const P4ControlPartitionInfoMap* partitionsMap, 
        const std::vector<cstring>* partitions, bool ingress);

    void end_apply(const IR::Node* node) override { 
        refMap->clear();
        typeMap->clear();
        PassManager::end_apply(node);
    }

};


}   // namespace CSA
#endif  /* _EXTENSIONS_CSA_BACKEND_TOFINO_TOTOFINO_H_ */

