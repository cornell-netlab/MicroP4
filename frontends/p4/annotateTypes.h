#ifndef _P4_ANNOTATETYPES_H_
#define _P4_ANNOTATETYPES_H_

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"

#include "./typeChecking/typeSubstitution.h"
/*
 * Need a pass to determine derived types for Composable Package.
 * In future, this pass should be used to decorate extended/implemented
 * types/interfaces.
 * Subtype decoration and relationship among them.
 *
 * It needs refMap.
 */
namespace P4 {

/*
class ReplaceTypeName final : public Transform {
    ReferenceMap* refMap;
    const TypeVariableSubstitution* tvs;

  public:
    using Transform::preorder;

    explicit ReplaceTypeName(ReferenceMap* refMap, 
                             const TypeVariableSubstitution* tvs) 
      : refMap(refMap), tvs(tvs) { 
        CHECK_NULL(refMap);
        setName("ReplaceTypeName"); 
    }

    const IR::Type_Name* preorder(IR::Type_Name* cp) override;

};
*/

class AnnotateTypes final : public Transform {
    ReferenceMap* refMap;

    static unsigned int i;
 public:
    using Transform::preorder;

    explicit AnnotateTypes(ReferenceMap* refMap) : refMap(refMap) { 
        CHECK_NULL(refMap);
        setName("AnnotateTypes"); 
    }

    // void postorder(IR::P4ComposablePackage* cp) override;
    const IR::P4ComposablePackage* preorder(IR::P4ComposablePackage* cp) override;

    void end_apply(const IR::Node* node) override {
        if (node->is<IR::P4ComposablePackage>()) {
            std::cout<<"Cleaning refMap\n";
            refMap->clear();
        }
    }
};

}  // namespace P4

#endif /* _P4_P4_ANNOTATETYPES_H_ */
