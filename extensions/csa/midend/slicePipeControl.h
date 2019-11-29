/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_MIDEND_SLICEPIPECONTROL_H_ 
#define _EXTENSIONS_CSA_MIDEND_SLICEPIPECONTROL_H_ 

#include "ir/ir.h"
#include "lib/ordered_map.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"
#include "midend/parserUnroll.h"
#include "controlStateReconInfo.h"
#include "msaNameConstants.h"


namespace CSA {

typedef P4::CallGraph<const IR::Node*> StmtExecGraph;

enum ControlConstraintStates { 
    ES_RW_IM_R = 0, // EgressSpec Read/Write, Ingress Metdata Read.
    ES_R_EM_R = 1, // EgressSpec Read, Egress Metadata Read
};

class GetUsedDeclarations final : public Inspector {

    const IR::P4Control* p4Control;
    IR::IndexedVector<IR::Declaration>* usedDecls;
  public:
    explicit GetUsedDeclarations(const IR::P4Control* p4Control, 
                                 IR::IndexedVector<IR::Declaration>* usedDecls)
      : p4Control(p4Control), usedDecls(usedDecls) {
        CHECK_NULL(usedDecls); CHECK_NULL(p4Control);
        setName("GetUsedDeclarations"); 
    }

    bool preorder(const IR::PathExpression* pathExpression) override;

    // TODO:: Fix this incomplete traversal, if needed
    Visitor::profile_t init_apply(const IR::Node* node) override { 
        BUG_CHECK(node->is<IR::Statement>(), "%1%: expected a Statement", node);
        return Inspector::init_apply(node);
    }
};


class RereferenceDeclPathsToArg final : public Transform {

    const IR::IndexedVector<IR::Declaration>* movedToStructArgDecls;
    cstring argName;
  public:
    explicit RereferenceDeclPathsToArg(
        const IR::IndexedVector<IR::Declaration>* movedToStructArgDecls, 
        cstring argName)
      : movedToStructArgDecls(movedToStructArgDecls), argName(argName) {
        CHECK_NULL(movedToStructArgDecls);
        setName("RereferenceDeclPathsToArg"); 
    }

    const IR::Node* postorder(IR::PathExpression* lvalue) override;
    const IR::Node* preorder(IR::Path* path) override {
        return new IR::Path(path->name.name);
    }

    /*
    Visitor::profile_t init_apply(const IR::Node* node) override { 
        BUG_CHECK(node->is<IR::Statement>(), "%1%: expected a Statement", node);
        return Transform::init_apply(node);
    }
    */
};


/*
class RenamePathsToNewDecl final : public Transform {
    const std::map<cstring, cstring> renameMap;
  public:
    explicit RenamePathsToNewDecl(const std::map<cstring, cstring>& renameMap)
      : renameMap(renameMap) {
        setName("RenamePathsToNewDecl"); 
    }

    const IR::Node* preorder(IR::Path* path) override {
        auto iter = renameMap.find(path->name);
        if (iter != renameMap.end()){
            path->name = iter->second;
        }
    }

    Visitor::profile_t init_apply(const IR::Node* node) override { 
        BUG_CHECK(node->is<IR::BlockStatement>(), 
            "%1%: expected a BlockStatement", node);
        return Transform::init_apply(node);
    }
};
*/


/*
 *  This pass does not rename parameters. Correlated parameter names should be
 *  the same for both the partitions.
 *  e.g., cpart1 (my_struct_t my_struct)
 *        cpart2 (my_struct_t my_struct)
 *  my_struct should be the same
 */
class AddInstancesInApplyParameterList final : public Transform {

    std::vector<const IR::Declaration_Instance*>  sharedLocalDeclInsts;

    // instance name to param name
    std::map<cstring, cstring>* paramToInstanceName;
  public:
    explicit AddInstancesInApplyParameterList(
        std::vector<const IR::Declaration_Instance*>  sharedLocalDeclInsts,
        std::map<cstring, cstring>* paramToInstanceName)
      : sharedLocalDeclInsts(sharedLocalDeclInsts),
        paramToInstanceName(paramToInstanceName) {
        
        CHECK_NULL(paramToInstanceName);
        setName("AddInstancesInApplyParameterList"); 
    }

    const IR::Node* preorder(IR::P4Control* p4c) override;
    const IR::Node* preorder(IR::Type_Control* tc) override;
    const IR::Node* preorder(IR::ParameterList* pl) override;

    Visitor::profile_t init_apply(const IR::Node* node) override { 
        BUG_CHECK(node->is<IR::P4Control>(), "%1%: expected a P4Control", node);
        return Transform::init_apply(node);
    }
};


class SlicePipeControl final : public Transform {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    cstring sharedStructTypeName;
    cstring p4ControlPart1Name;
    P4ControlStateReconInfoMap *controlToReconInfoMap;

    cstring sharedStructInstArgName;
    bool slice;
    bool track;

    bool isConvertedCPackage = false;
    cstring intermediateCSAPacketHeaderInst ;

    // The part of the statement executed in the upper partition
    IR::Statement* slicedHalf; 
    std::vector<IR::Statement*> newStmtVec;

    IR::MethodCallExpression* splitApplyMCE = nullptr;
    // field name and bit size
    std::vector<std::pair<cstring, unsigned>> newFieldsInfo;
    // these variables will be part of a metdata type of struct passed in args
    std::vector<IR::Declaration_Variable*>  sharedVariableDecls;
    // these instances will be part of the apply parameters
    std::vector<const IR::Declaration_Instance*>  sharedLocalDeclInsts;
    std::map<cstring, cstring> param2InstPart1;
    std::map<cstring, cstring> param2InstPart2;

    // these are new control instances created due to partitioning of 
    // ".apply(...)" statements.
    std::vector<const IR::Declaration_Instance*>  newControlInsts;
    
    ControlConstraintStates partitionState;
    const IR::Type_Struct* sharedMetadataStruct;

    std::map<cstring, PartitionInfo> partitionsMap;
    // GetUsedDeclarations* getUsedDeclarations;

    cstring msaPktParamName;

    void processExternMethodCall(const P4::ExternMethod* em);
    cstring getFieldNameForSlice(bool ifSwitch = true, unsigned valRange = 3);
    IR::Statement* createAssignmentStatement(cstring fieldName, unsigned value);
    IR::Statement* createIfStatement(cstring lname, unsigned rv, 
                                     IR::Statement* ifTrue);
    IR::Statement* appendStatement(IR::Statement* currStmt, IR::Statement* inStmt);
    // void identifyUsedDecls(IR::Statement* stmt);
    IR::P4Control* createPartitionedP4Control(const IR::P4Control* orig, 
                                              const IR::BlockStatement* newBody);
    cstring getUniqueControlName(cstring prefix);

    IR::Type_Struct* createSharedStructType(IR::P4Control** p4C1, 
        IR::P4Control** p4C2, std::set<cstring> replicateDecls);
    unsigned uniqueControlIDGen = 0;


    IR::Type_Declaration* createIntermediateDeparser(
        cstring packetOutTypeName, ControlStateReconInfo* info);

    IR::Type_Declaration* createIntermediateParser(
        cstring packetInTypeName, ControlStateReconInfo* info);


 public:
    using Transform::preorder;

    explicit SlicePipeControl(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
          cstring sharedStructTypeName,
          ControlConstraintStates partitionState,
          P4ControlStateReconInfoMap *controlToReconInfoMap)
      : refMap(refMap), typeMap(typeMap), 
        sharedStructTypeName(sharedStructTypeName),
        partitionState(partitionState),
        controlToReconInfoMap(controlToReconInfoMap) {

        setName("SlicePipeControl"); 
        slice = false;
        track = true;
        // visitDagOnce = false;
        sharedStructInstArgName = sharedStructTypeName+"_arg";
    }

    const IR::Node* preorder(IR::P4Control* p4control) override;
    const IR::Node* preorder(IR::Type_Control* type) override;
    const IR::Node* preorder(IR::BlockStatement* blockStatement) override;
    // const IR::Node* postorder(IR::BlockStatement* blockStatement) override;
    const IR::Node* preorder(IR::IfStatement* ifStmt) override;
    // const IR::Node* postorder(IR::IfStatement* ifStmt) override;
    // const IR::Node* postorder(IR::Statement* stmt) override;
    const IR::Node* preorder(IR::MethodCallExpression* mce) override;

    //const IR::Node* postorder(IR::AssignmentStatement* asignmentStmt) override; 

    const IR::Node* preorder(IR::Declaration_Variable* dv) override; 

    Visitor::profile_t init_apply(const IR::Node* node) override { 
        BUG_CHECK(node->is<IR::P4Control>(), "%1%: expected a P4Control", node);
        newFieldsInfo.clear();
        return Transform::init_apply(node);
    }

    void setCurrentPartitionCond(ControlConstraintStates currentState) {
        partitionState = currentState;
    }

    // TODO: combine map and sharedLocalDeclInsts into one stucture
    std::map<cstring, PartitionInfo> getPartitionInfo() const {
        return partitionsMap;
    }

    std::vector<const IR::Declaration_Instance*> 
                                        getSharedDeclarationInstances() const {
        return sharedLocalDeclInsts;
    }
    static cstring getSharedStructTypeName(cstring controlTypeName);

};


class PartitionP4Control final : public Transform {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    cstring* controlTypeName;
    P4ControlStateReconInfoMap *controlToReconInfoMap;

    std::vector<cstring>* partitions;
    ControlConstraintStates* constraintState;

    P4ControlPartitionInfoMap* partitionsMap;
    // local map instance
    P4ControlPartitionInfoMap partMap;
    
  public:
    using Transform::preorder;

    explicit PartitionP4Control(P4::ReferenceMap* refMap, P4::TypeMap* typeMap,
        cstring* controlTypeName, 
        P4ControlPartitionInfoMap* partitionsMap,
        P4ControlStateReconInfoMap *controlToReconInfoMap,
        std::vector<cstring>* partitions,
        ControlConstraintStates* constraintState)
      : refMap(refMap), typeMap(typeMap), controlTypeName(controlTypeName),
        partitionsMap(partitionsMap), controlToReconInfoMap(controlToReconInfoMap),
        partitions(partitions),
        constraintState(constraintState) {

        CHECK_NULL(refMap); CHECK_NULL(typeMap); CHECK_NULL(controlTypeName);
        CHECK_NULL(controlToReconInfoMap); CHECK_NULL(constraintState);

        setName("PartitionP4Control"); 
    }

    void setNextControlConstraintStates() {
        if (*constraintState == ControlConstraintStates::ES_RW_IM_R) 
            *constraintState = ControlConstraintStates::ES_R_EM_R;
        else if (*constraintState == ControlConstraintStates::ES_R_EM_R) 
            *constraintState = ControlConstraintStates::ES_RW_IM_R;
        else {
            BUG("Unexpected partition state");
        }
    }
    const IR::Node* preorder(IR::P4Control* p4control) override;
    const IR::Node* postorder(IR::P4Program* p4program) override;

    void end_apply(const IR::Node* node) override { 
        typeMap->clear();
        refMap->clear();
        Transform::end_apply(node);
    }
};


class CreateAllPartitions : public PassRepeated {

    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    ControlConstraintStates initState;
  public:
    explicit CreateAllPartitions(P4::ReferenceMap* refMap, P4::TypeMap* typeMap,
        cstring* mainControlTypeName,
        P4ControlPartitionInfoMap* partitionsMap,
        P4ControlStateReconInfoMap *controlToReconInfoMap,
        std::vector<cstring>* partitions) 
      : PassManager({}), refMap(refMap), typeMap(typeMap) {

      CHECK_NULL(refMap); CHECK_NULL(typeMap); setName("CreateAllPartitions");

      initState = ControlConstraintStates::ES_RW_IM_R;

      passes.emplace_back(new P4::ResolveReferences(refMap, true)); 
      passes.emplace_back(new P4::TypeInference(refMap, typeMap, false)); 
      passes.emplace_back(new PartitionP4Control(refMap, typeMap, 
            mainControlTypeName, partitionsMap, controlToReconInfoMap, 
            partitions, &initState));
    }

    void end_apply(const IR::Node* node) override { 
        refMap->clear();
        typeMap->clear();
        PassManager::end_apply(node);
    }

};




}  // namespace CSA

#endif /* _EXTENSIONS_CSA_MIDEND_SLICEPIPECONTROL_H_  */
