/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _MIDEND_COMPOSABLEPACKAGEINTERPRETER_H_
#define _MIDEND_COMPOSABLEPACKAGEINTERPRETER_H_

#include "ir/ir.h"
#include "frontends/common/resolveReferences/referenceMap.h"
#include "frontends/p4/typeMap.h"
#include "frontends/p4/coreLibrary.h"
#include "controlBlockInterpreter.h"


namespace P4 {

class ComposablePackageInterpreter : public Inspector {
    ReferenceMap*       refMap;
    TypeMap*            typeMap;
    P4::ParserStructuresMap* parserStructures;
    P4::HdrValidityOpsPkgMap* hdrValidityOpsPkgMap;

    std::vector<cstring> p4cpCallStack;

    cstring parser_fqn = "";

    unsigned minExtLen;
    unsigned maxExtLen;
    unsigned maxIncrPktLen;
    unsigned maxDecrPktLen;

    // TODO: tighten the bound for maxIncrPktLen using them
    // if minIncrPktLen > 0, maxDecrPktLen = minDecrPktLen = 0
    unsigned minIncrPktLen;

    // if minDecrPktLen > 0, maxIncrPktLen = minIncrPktLen = 0
    unsigned minDecrPktLen;


 public:
     ComposablePackageInterpreter(ReferenceMap* refMap, TypeMap* typeMap,
         P4::ParserStructuresMap* parserStructures, 
         P4::HdrValidityOpsPkgMap* hdrValidityOpsPkgMap)
       : refMap(refMap), typeMap(typeMap), parserStructures(parserStructures),
        hdrValidityOpsPkgMap(hdrValidityOpsPkgMap) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap); CHECK_NULL(parserStructures);
        CHECK_NULL(hdrValidityOpsPkgMap);
        minExtLen = 0; maxExtLen = 0;
        maxIncrPktLen = 0; maxDecrPktLen = 0;
    }

    Visitor::profile_t init_apply(const IR::Node* node) override;

    bool preorder(const IR::P4Control* p4Control) override;

    bool preorder(const IR::P4Parser* p4Parser) override;

    bool preorder(const IR::P4ComposablePackage* p4cp) override;

    unsigned getMinExtLen() const { return minExtLen; }
    unsigned getMaxExtLen() const { return maxExtLen; }
    unsigned getMaxIncrPktLen() const { return maxIncrPktLen; }
    unsigned getMaxDecrPktLen() const { return maxDecrPktLen; }

};

}  // namespace P4

#endif /* _MIDEND_COMPOSABLEPACKAGEINTERPRETER_H_ */
