#ifndef _EXTENSIONS_CSA_MIDEND_MERGEDECLARATIONS_H_ 
#define _EXTENSIONS_CSA_MIDEND_MERGEDECLARATIONS_H_ 

#include "ir/ir.h"
#include "lib/ordered_map.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"
#include "midend/parserUnroll.h"


namespace CSA {

class MergeDeclarations final : public Transform {

    std::vector<const IR::P4Program*> p4Programs;

 public:
    using Transform::preorder;

    explicit MergeDeclarations(std::vector<const IR::P4Program*> 
                                   p4Programs)
        : p4Programs(p4Programs) {
        setName("MergeDeclarations"); 
    }
    const IR::Node* preorder(IR::P4Program* p4Program) override;

    Visitor::profile_t init_apply(const IR::Node* node) override { 
        BUG_CHECK(node->is<IR::P4Program>(), "%1%: expected a P4Program", node);
        return Transform::init_apply(node);
    }
};

// Dirtiest hack ever.
// if not done refernces will not be resolved due to comparison of
// srcinfo between declarations and paths.
// TODO: fix this
class InvalidateSourceInfo final : public Transform {

 public:
    using Transform::postorder;
    explicit InvalidateSourceInfo() {
        setName("InvalidateSourceInfo"); 
    }
    const IR::Node* postorder(IR::Node* node) override {
        //std::cout<<node->srcInfo<<"\t to -> ";
        node->srcInfo = Util::SourceInfo();
        // std::cout<<node->srcInfo<<"\n";
        // std::cout<<"reset source info \n";
        return node;
    }
};


class Consolidator final : public Transform {

    IR::Type_Error* typeError;
    bool remove = false;
    bool removeMatchKind = false;
    std::map<cstring, std::vector<IR::Method*>> seenMethods;
 
    IR::IndexedVector<IR::Type_Declaration> typeDecls;
    IR::IndexedVector<IR::Declaration> decls;

    bool isTopLevel();
    bool addTypeDecl(const IR::Type_Declaration* idecl);
    bool addDecl(const IR::Declaration* idecl);

    std::set<cstring> csaActions;
    // bool hasNoAction = false;
    // cstring noActionName = "csa_no_action";


  public:

    explicit Consolidator() {
        typeError = nullptr;
        setName("Consolidator"); 
    }

    const IR::Node* preorder(IR::Type_Declaration* typeDecl) override;
    const IR::Node* preorder(IR::Type_ComposablePackage* tcp) override;
    const IR::Node* preorder(IR::Type_Error* te) override;
    const IR::Node* postorder(IR::Type_Error* te) override;
    const IR::Node* preorder(IR::Declaration_ID* id) override;
    const IR::Node* preorder(IR::Declaration_MatchKind* matchKindDecl) override;

    const IR::Node* preorder(IR::P4Action* action) override;
    // const IR::Node* postorder(IR::P4Program* p4program) override;


    const IR::Node* preorder(IR::Method* method) override;


    Visitor::profile_t init_apply(const IR::Node* node) override { 
        BUG_CHECK(node->is<IR::P4Program>(), "%1%: expected a P4Program", node);
        return Transform::init_apply(node);
    }
};


}  // namespace CSA

#endif /* _EXTENSIONS_CSA_LINKER_PARSERCONVERTER_H_ */
