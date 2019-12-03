/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_MIDEND_TOCONTROL_H_ 
#define _EXTENSIONS_CSA_MIDEND_TOCONTROL_H_ 

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"
#include "deparserConverter.h"
#include "controlStateReconInfo.h"
#include "parserConverter.h"


namespace CSA {

class CPackageToControl final : public Transform {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    cstring* mainControlTypeName;
    P4ControlStateReconInfoMap *controlToReconInfoMap;

    const std::vector<cstring> archBlockOrder = {
        "micro_parser", 
        "micro_control", 
        "micro_deparser"
    };

    // Per P4ComposablePackage state
    std::map<cstring, cstring> typeRenameMap;
    std::map<cstring, IR::Statement*> mcsMap;
    std::map<cstring, cstring> ctrlInstanceName;
    // type to args bookkeeping
    std::map<cstring, IR::PathExpression*> typeToArgsMap;
    IR::IndexedVector<IR::Declaration> newDeclInsts;

    Util::SourceInfo cpSourceInfo;
    cstring getNamePrefix();
    void resetMCSRelatedObjects();
    void addMCSs(IR::BlockStatement* bs);
    void populateArgsMap(const IR::ParameterList* pl);

    bool isArchBlock(cstring name);
    void createMCS(const IR::Type_Control* tc);

    void addIntermediateExternCalls(IR::BlockStatement* bs);
  public:
    explicit CPackageToControl(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
        cstring* mainControlTypeName,
        P4ControlStateReconInfoMap *controlToReconInfoMap)
      : refMap(refMap), typeMap(typeMap), 
        mainControlTypeName(mainControlTypeName),
        controlToReconInfoMap(controlToReconInfoMap){
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        CHECK_NULL(mainControlTypeName); CHECK_NULL(controlToReconInfoMap);
        setName("CPackageToControl"); 
    }

    const IR::Node* preorder(IR::Type_Control* tc) override;
    const IR::Node* preorder(IR::Type_Name* tn) override;
    const IR::Node* preorder(IR::P4Control* p4control) override;
    const IR::Node* postorder(IR::P4Control* p4control) override;

    const IR::Node* preorder(IR::Type_ComposablePackage* tcp) override;

    const IR::Node* preorder(IR::P4ComposablePackage* cp) override;
    const IR::Node* postorder(IR::P4ComposablePackage* cp) override;

    const IR::Node* preorder(IR::Parameter* p) override;
    // Removing main control instance 
    const IR::Node* preorder(IR::Declaration_Instance* di) override {
        if (getContext()->node->is<IR::P4Program>() && di->getName() == "main") {
            if (auto tn = di->type->to<IR::Type_Name>()) {
                *mainControlTypeName = tn->path->name.name;
                return nullptr;
            }   
        }
        return di;
    }

    const IR::Node* createIntermediateDeparser(cstring name);
    const IR::Node* createIntermediateParser(cstring name);

};

class AddCSAByteHeader final : public Transform {
    cstring headerTypeName;
    cstring fieldName;
    unsigned* maxOffset;

 public:
    using Transform::preorder;
    using Transform::postorder;

    explicit AddCSAByteHeader(cstring headerTypeName, cstring fieldName, 
                              unsigned* maxOffset)
        : headerTypeName(headerTypeName), fieldName(fieldName), maxOffset(maxOffset) {
        CHECK_NULL(maxOffset);
        setName("AddCSAByteHeader"); 
    }
    const IR::Node* preorder(IR::P4Program* p4Program) override;

    const IR::Node* preorder(IR::Type_Extern* te) override;

    static const cstring csaPktStuLenFName;
    static const cstring csaPktStuCurrOffsetFName;
};

class Converter final : public Transform {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    cstring* mainControlTypeName;

    P4::ParserStructuresMap *parserStructures;
    P4ControlStateReconInfoMap *controlToReconInfoMap;
    std::vector<std::vector<unsigned>*> offsetsStack;
    IR::Vector<IR::Type_Declaration> updateP4ProgramObjects;
    IR::Vector<IR::Type_Declaration> addInP4ProgramObjects;

    bool isDeparser(const IR::P4Control* p4control);
  public:
    Converter(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
              cstring* mainControlTypeName, 
              P4::ParserStructuresMap *parserStructures, 
              P4ControlStateReconInfoMap *controlToReconInfoMap)
        : refMap(refMap), typeMap(typeMap), 
          mainControlTypeName(mainControlTypeName),
          parserStructures(parserStructures),
          controlToReconInfoMap(controlToReconInfoMap){
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        CHECK_NULL(mainControlTypeName);  CHECK_NULL(parserStructures);
    }

    // control the visit order of P4Parser nodes to visit in 
    // execution call order
    const IR::Node* preorder(IR::P4Program* p4Program) override;
    const IR::Node* preorder(IR::P4ComposablePackage* cp) override;
    // used to visit P4Parser of callee P4ComposablePackage
    const IR::Node* preorder(IR::P4Control* p4Control) override;
    const IR::Node* preorder(IR::P4Parser* p4Parser) override;
    const IR::Node* preorder(IR::MethodCallStatement* mcs) override;

};

class ToControl final : public PassManager {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    unsigned* maxOffset;
    cstring* mainControlTypeName;

    P4ControlStateReconInfoMap *controlToReconInfoMap;
  public:
    ToControl(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
              cstring* mainControlTypeName, 
              P4ControlStateReconInfoMap *controlToReconInfoMap, 
              P4::ParserStructuresMap *parserStructures)
        : refMap(refMap), typeMap(typeMap), 
          mainControlTypeName(mainControlTypeName),
          controlToReconInfoMap(controlToReconInfoMap) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        CHECK_NULL(mainControlTypeName);
        CHECK_NULL(controlToReconInfoMap);
        maxOffset = new unsigned(9600);
        passes.push_back(new Converter(refMap, typeMap, 
              mainControlTypeName, parserStructures, controlToReconInfoMap));
        passes.push_back(new AddCSAByteHeader(headerTypeName, 
              bitStreamFieldName, maxOffset));
        passes.push_back(new CPackageToControl(refMap, typeMap, 
              mainControlTypeName, controlToReconInfoMap));
    }
    static const cstring headerTypeName;
    static const cstring indicesHeaderTypeName;
    static const cstring indicesHeaderInstanceName;
    static const cstring bitStreamFieldName;
    static const cstring csaPacketStructTypeName;
    static const cstring csaPacketStructName;
    static const cstring csaHeaderInstanceName;
    static const cstring csaStackInstanceName;
    static const cstring csaPakcetInGetPacketStruct;
    static const cstring csaPakcetOutSetPacketStruct;
    static const cstring csaPakcetOutGetPacketIn;

    static const cstring csaPakcetInExternTypeName;
    static const cstring csaPakcetOutExternTypeName;

    void end_apply(const IR::Node* node) override { 
        refMap->clear();
        typeMap->clear();
        PassManager::end_apply(node);
    }


};

}   // namespace CSA
#endif  /* _EXTENSIONS_CSA_MIDEND_TOCONTROL_H_ */

