#include "csamidend.h"
#include "frontends/common/constantFolding.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/evaluator/evaluator.h"
#include "frontends/p4/fromv1.0/v1model.h"
#include "frontends/p4/moveDeclarations.h"
#include "frontends/p4/simplify.h"
#include "frontends/p4/simplifyParsers.h"
#include "frontends/p4/strengthReduction.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"
#include "frontends/p4/uniqueNames.h"
#include "frontends/p4/unusedDeclarations.h"
#include "midend/actionSynthesis.h"
#include "midend/checkSize.h"
#include "midend/complexComparison.h"
#include "midend/convertEnums.h"
#include "midend/copyStructures.h"
#include "midend/eliminateTuples.h"
#include "midend/eliminateNewtype.h"
#include "midend/eliminateSerEnums.h"
#include "midend/flattenInterfaceStructs.h"
#include "midend/local_copyprop.h"
#include "midend/nestedStructs.h"
#include "midend/removeLeftSlices.h"
#include "midend/removeParameters.h"
#include "midend/removeUnusedParameters.h"
#include "midend/simplifyKey.h"
#include "midend/simplifySelectCases.h"
#include "midend/simplifySelectList.h"
#include "midend/removeSelectBooleans.h"
#include "midend/validateProperties.h"
#include "midend/compileTimeOps.h"
#include "midend/orderArguments.h"
#include "midend/predication.h"
#include "midend/expandLookahead.h"
#include "midend/expandEmit.h"
#include "midend/tableHit.h"
#include "midend/midEndLast.h"

namespace CSA {

const IR::P4Program* CSAMidEnd::run(const IR::P4Program* program) {

    if (program == nullptr)
        return nullptr;

    auto evaluator = new P4::EvaluatorPass(&refMap, &typeMap);
    PassManager csaMidEnd = {
        new P4::ResolveReferences(&refMap, true),
        new P4::CheckTableSize(),
        new P4::EliminateNewtype(&refMap, &typeMap),
        new P4::EliminateSerEnums(&refMap, &typeMap),
        new P4::RemoveActionParameters(&refMap, &typeMap),
        convertEnums,
        new VisitFunctor([this, convertEnums]() { enumMap = convertEnums->getEnumMapping(); }),
        new P4::OrderArguments(&refMap, &typeMap),
        new P4::TypeChecking(&refMap, &typeMap),
        new P4::SimplifyKey(&refMap, &typeMap,
                            new P4::OrPolicy(
                                new P4::IsValid(&refMap, &typeMap),
                                new P4::IsMask())),
        new P4::ConstantFolding(&refMap, &typeMap),
        new P4::StrengthReduction(),
        new P4::SimplifySelectCases(&refMap, &typeMap, true),  // require constant keysets

        new P4::ExpandLookahead(&refMap, &typeMap), // Marked for removal
        new P4::ExpandEmit(&refMap, &typeMap), // Marked for removal
        
        new P4::SimplifyParsers(&refMap),
        new P4::StrengthReduction(),
        new P4::EliminateTuples(&refMap, &typeMap),
        new P4::SimplifyComparisons(&refMap, &typeMap),
        new P4::CopyStructures(&refMap, &typeMap),
        new P4::NestedStructs(&refMap, &typeMap),
        new P4::SimplifySelectList(&refMap, &typeMap),
        new P4::RemoveSelectBooleans(&refMap, &typeMap),
        new P4::FlattenInterfaceStructs(&refMap, &typeMap),
        new P4::Predication(&refMap),
        new P4::MoveDeclarations(),  // more may have been introduced
        new P4::ConstantFolding(&refMap, &typeMap),
        new P4::LocalCopyPropagation(&refMap, &typeMap),
        new P4::ConstantFolding(&refMap, &typeMap),
        new P4::SimplifyKey(&refMap, &typeMap,
                            new P4::OrPolicy(
                                new P4::IsValid(&refMap, &typeMap),
                                new P4::IsMask())),
        new P4::MoveDeclarations(),
        new P4::ValidateTableProperties({ "implementation",
                                          "size",
                                          "counters",
                                          "meters",
                                          "support_timeout" }),
        new P4::SimplifyControlFlow(&refMap, &typeMap),
        new P4::CompileTimeOperations(),
        new P4::TableHit(&refMap, &typeMap),
        new P4::RemoveLeftSlices(&refMap, &typeMap),

        new P4::TypeChecking(&refMap, &typeMap),
        new P4::MidEndLast(),
        evaluator
        //new VisitFunctor([this, evaluator]() { toplevel = evaluator->getToplevelBlock(); }),

    };
    csaMidEnd.setName("PreFrontEnd");
    csaMidEnd.addDebugHooks(hooks);
    program = program->apply(csaMidEnd);
    if (::errorCount() > 0)
        return nullptr;

    return program;
}

} 
