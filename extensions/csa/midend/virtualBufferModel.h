/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_LINKER_MODELVB_H_
#define _EXTENSIONS_CSA_LINKER_MODELVB_H_

#include "ir/ir.h"
#include "frontends/p4/callGraph.h"
#include "referenceMap.h"
#include "lib/exceptions.h"
#include "lib/cstring.h"

#include "extensions/csa/switch/virtualBuffer.h"

namespace CSA {

class VirtualBufferModel : public Inspector {

    /// stack of 
    std::vector<ComposableUnit> ;

 private:

 public:
    explicit VirtualBufferModel(/* out */ P4::ReferenceMap* refMap,
                               bool checkShadow = false);

    Visitor::profile_t init_apply(const IR::Node* node) override;
    void end_apply(const IR::Node* node) override;
    using Inspector::preorder;
    using Inspector::postorder;


#define DECLARE(TYPE)                           \
    bool preorder(const IR::TYPE* t) override;  \
    void postorder(const IR::TYPE* t) override; \

    DECLARE(P4Program)
    DECLARE(P4ComposablePackage)
    DECLARE(P4Control)
    DECLARE(P4Parser)
    DECLARE(Function)
#undef DECLARE

    bool preorder(const IR::P4Table* table) override;

};

}  // namespace P4

#endif /* _COMMON_RESOLVEREFERENCES_RESOLVEREFERENCES_H_ */
