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

/*
class MSAStdMetaSubstituter final : public Transform {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;

    const IR::Parameter* getStandardMetadataParam(const IR::P4Control* p4c);
  public:
    MSAStdMetaSubstituter(P4::ReferenceMap* refMap, P4::TypeMap* typeMap)
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
*/


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
    

    const IR::Node* createTofinoIngressParser();
    /*
    const IR::Node* createIngressControl(std::vector<const IR::P4Control*>& p4c,
                                         IR::Type_Struct* typeStruct);
    const IR::Node* createTofinoIngressDeparser();

    const IR::Node* createTofinoEgressParser();
    const IR::Node* createEgressControl(std::vector<const IR::P4Control*>& p4c,
                                        IR::Type_Struct*  typeStruct);
    const IR::Node* createTofinoEgressDeparser();
    */
    const IR::Node* createMainPackageInstance();

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
    static const cstring egIMTypeName; 
    static const cstring egIMArgName;


    static const cstring igIMFrmParTypeName;
    static const cstring igIMForDePTypeName;

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

        // passes.push_back(new MSAStdMetaSubstituter(refMap, typeMap));

        /*
        passes.push_back(new P4::ResolveReferences(refMap, true));
        passes.push_back(new P4::TypeInference(refMap, typeMap, false));
        */
        passes.push_back(new CreateTofinoArchBlock(refMap, typeMap, 
              ToControl::headerTypeName, partitionsMap, partitions, minExtLen, 
              maxExtLen, hdrBitWidth, stackSize, numFullStacks, 
              residualStackSize));
    }

};


}   // namespace CSA
#endif  /* _EXTENSIONS_CSA_BACKEND_TOFINO_TOTOFINO_H_ */

