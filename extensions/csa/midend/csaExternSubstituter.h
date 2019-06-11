#ifndef _EXTENSIONS_CSA_MIDEND_CSAEXTERNSUBSTITUTER_H_ 
#define _EXTENSIONS_CSA_MIDEND_CSAEXTERNSUBSTITUTER_H_ 

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"

namespace CSA {

class CSAPacketSubstituter final : public Transform {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    const P4ControlPartitionInfoMap* partitionsMap;
    const std::vector<cstring>* controlTypeNames;


    cstring controlName;

    std::map<cstring, const IR::P4Control*> transformedP4Controls;
  public:
    typedef std::map<const IR::IDeclaration*, const IR::IDeclaration*>
        DeclarationMAP;

  private:
    class Mappings {

        DeclarationMAP paramMap;
        DeclarationMAP localDeclMap;

        const IR::IDeclaration* findByName(const DeclarationMAP* map, 
                                           const IR::IDeclaration* key) {
            for (auto kv : (*map)) {
                if (key->getName() == kv.first->getName()) {
                    return kv.second;
                }
            }
            return nullptr;
        }

      public:
        cstring name; // stores name of the P4Control to BUG_CHECK the push and 
                      // pop operations
        std::set<const IR::IDeclaration*> substituted;

        Mappings(cstring name) : name(name){ }
        const IR::IDeclaration* getMappedDecl(const IR::IDeclaration* decl) {
          /*
            auto iter = localDeclMap.find(decl);
            if (iter != localDeclMap.end())
                return iter->second;
            auto iterParamMap = paramMap.find(decl);
            if (iterParamMap != paramMap.end())
                return iterParamMap->second;
            return nullptr;
          */
          auto idecl = findByName(&paramMap, decl);
          if (idecl != nullptr)
              return idecl;
          return findByName(&localDeclMap, decl);
        }
        void insertMapping(const IR::IDeclaration* decl, 
                           const IR::IDeclaration* mappedTo) {
            if (decl->is<IR::Parameter>()) {
                auto d = findByName(&paramMap, decl);
                if (d == nullptr)
                    paramMap.emplace(decl, mappedTo);
                return;
            }
            auto d = findByName(&localDeclMap, decl);
            if (d == nullptr)
                localDeclMap.emplace(decl, mappedTo);
            return;
        }

        const IR::IDeclaration* getParamMappingByName(cstring paramName) {
            for (auto p : paramMap) {
                if (p.first->getName() == paramName)
                    return p.second;
            }
            return nullptr;
        }
        const DeclarationMAP& getParamMap() const {
            return paramMap;
        }
        size_t getSize() {
            return paramMap.size() + localDeclMap.size();
        }

        void print() {
            for (auto kv : paramMap)
                std::cout<<kv.first<<"-----"<<kv.second<<"\n";
            for (auto kv : localDeclMap)
                std::cout<<kv.first<<"-----"<<kv.second<<"\n";
        }
    };
    std::vector<Mappings*> declMapStack;

  public:
    using Transform::preorder;
    using Transform::postorder;

    CSAPacketSubstituter(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
                         const P4ControlPartitionInfoMap* partitionsMap,
                         const std::vector<cstring>* controlTypeNames)
      : refMap(refMap), typeMap(typeMap), partitionsMap(partitionsMap), 
        controlTypeNames(controlTypeNames) {
        setName("CSAPacketSubstituter");
        // visitDagOnce = true;
    }

    const IR::Node* preorder(IR::Parameter* param) override;
    const IR::Node* preorder(IR::Type_Control* tc) override;
    const IR::Node* preorder(IR::Declaration* decl) override;
    const IR::Node* preorder(IR::P4Control* p4Control) override;

    const IR::Node* preorder(IR::MethodCallStatement* mcs) override;
    const IR::Node* preorder(IR::AssignmentStatement* as) override;

    const IR::Node* preorder(IR::Path* path) override;

    const IR::Node* preorder(IR::P4Program* p4Program) override;
};


class CSAExternSubstituter final : public PassManager {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    const P4ControlPartitionInfoMap* partitionsMap;
    const std::vector<cstring>* controlTypeNames;

  public:
    CSAExternSubstituter(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
        const P4ControlPartitionInfoMap* partitionsMap,
        const std::vector<cstring>* controlTypeNames)
        : refMap(refMap), typeMap(typeMap), partitionsMap(partitionsMap), 
          controlTypeNames(controlTypeNames) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap); CHECK_NULL(controlTypeNames);
        passes.push_back(new P4::ResolveReferences(refMap, true)); 
        passes.push_back(new P4::TypeInference(refMap, typeMap, false)); 
        passes.push_back(new CSAPacketSubstituter(refMap, typeMap, 
                              partitionsMap, controlTypeNames));
    }

   /*
    Visitor::profile_t init_apply(const IR::Node* node) override { 
        for (auto c : *controlTypeNames)
            std::cout<<c<<"\n";
        return PassManager::init_apply(node);
    }
    */

};


}   // namespace CSA
#endif  /* _EXTENSIONS_CSA_MIDEND_CSAEXTERNSUBSTITUTER_H_  */

