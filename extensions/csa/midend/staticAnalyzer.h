/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _MIDEND_STATICANALYZER_H_
#define _MIDEND_STATICANALYZER_H_

#include "ir/ir.h"
#include "frontends/common/resolveReferences/referenceMap.h"
#include "frontends/p4/typeMap.h"
#include "frontends/p4/coreLibrary.h"
#include "frontends/p4/typeChecking/typeChecker.h"

#include "midend/composablePackageInterpreter.h"  

namespace CSA {

class StaticAnalyzer : public Inspector {
    P4::ReferenceMap*         refMap;
    P4::TypeMap*              typeMap;
    P4::ParserStructuresMap*  parserStructures;
    cstring*                  mainPackageTypeName;

    unsigned* minExtLen;
    unsigned* maxExtLen;
    unsigned* byteStackSize;

 public:
    StaticAnalyzer(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
                    P4::ParserStructuresMap* parserStructures, 
                    cstring* mainPackageTypeName, unsigned* minExtLen, 
                    unsigned* maxExtLen, unsigned* byteStackSize)
        : refMap(refMap), typeMap(typeMap), parserStructures(parserStructures), 
          mainPackageTypeName(mainPackageTypeName), minExtLen(minExtLen), 
          maxExtLen(maxExtLen), byteStackSize(byteStackSize) {

        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        CHECK_NULL(parserStructures); CHECK_NULL(mainPackageTypeName);
        CHECK_NULL(minExtLen); CHECK_NULL(maxExtLen); CHECK_NULL(byteStackSize);
        *minExtLen = 0;
        *maxExtLen = 0;
        *byteStackSize = 0;
    }

    Visitor::profile_t init_apply(const IR::Node* node) override;
    bool preorder(const IR::P4ComposablePackage* p4cp) override;
    bool preorder(const IR::P4Program* p4Program) override;

};


/*
class Analyze final : public PassManager {
    P4::ReferenceMap*         refMap;
    P4::TypeMap*              typeMap;
    P4::ParserStructuresMap*  parserStructures;
    cstring*                  mainPackageTypeName;

  public:
    Analyze(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
              cstring* mainPackageTypeName, 
              P4::ParserStructuresMap *parserStructures)
        : refMap(refMap), typeMap(typeMap), parserStructures(parserStructures),
          mainPackageTypeName(mainPackageTypeName) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        CHECK_NULL(mainPackageTypeName);
        passes.push_back(new P4::TypeChecking(refMap, typeMap)); 
        passes.push_back(new StaticAnalyzer(refMap, typeMap, parserStructures, 
                                            mainPackageTypeName));
    }
};
*/



}  // namespace P4

#endif /* _MIDEND_STATICANALYZER_H_ */
