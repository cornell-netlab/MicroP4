/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include <getopt.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <unordered_set>
#include "msaTofinoBackend.h"
#include "frontends/common/parseInput.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/evaluator/evaluator.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"
#include "frontends/p4/unusedDeclarations.h"
#include "frontends/parsers/parserDriver.h"
#include "midend/parserUnroll.h"
#include "midend/midEndLast.h"
#include "alignParamNames.h"
#include "mergeDeclarations.h"
#include "slicePipeControl.h"
#include "toControl.h"
#include "controlStateReconInfo.h"
#include "parserConverter.h"
#include "msaPacketSubstituter.h"
#include "removeMSAConstructs.h"
#include "staticAnalyzer.h"
#include "hdrToStructs.h"
#include "removeUnusedApplyParams.h"
#include "cloneWithFreshPath.h"
#include "deadFieldElimination.h"


namespace CSA {

const IR::P4Program* MSATofinoBackend::run(const IR::P4Program* program) {

    cstring mainP4ControlTypeName;
    if (program == nullptr)
        return nullptr;

    std::vector<const IR::P4Program*> targetIR;
    targetIR.push_back(tnaP4Program);

    std::vector<cstring> partitions;

    unsigned stackSize = 32;
    unsigned newFieldBitWidth = 16;
    unsigned numFullStacks;
    unsigned residualStackSize;

    P4ControlPartitionInfoMap partitionsMap;
    
    PassManager msaTofinoBackend = {

        new P4::MidEndLast(),
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),
        // CreateAllPartitions is PassRepeated with ResolveReferences & TypeInference.
        // It will terminate when p4program does not change.
        // Subsequent TypeInference fails due to stale const IR::Path* in
        // referenceMap. Not sure, why is that happening.
        // Therefore MergeDeclarations(a Transform Pass) without refMap and
        // typeMap is executed after it.
        new CSA::CreateAllPartitions(&refMap, &typeMap, &mainP4ControlTypeName,
                                     &partitionsMap, 
                                     &(midendContext->controlToReconInfoMap), 
                                     &partitions),
        // new P4::MidEndLast(),

        new CSA::MergeDeclarations(targetIR), 
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),
        // new P4::MidEndLast(),
        new CSA::MSAPacketSubstituter(&refMap, &typeMap), 
        // new P4::MidEndLast(),
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),
        // new P4::MidEndLast(),

        // These are Tofino specific passes
        //////////////////////////////////////////

        new CSA::ReplaceMSAByteHdrStack(&refMap, &typeMap, stackSize, 
            newFieldBitWidth, &numFullStacks, &residualStackSize),

        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),
        new CSA::RemoveExplicitSlices(&refMap, &typeMap),
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),
        // new P4::MidEndLast(),

        new CSA::ToTofino(&refMap, &typeMap, &partitionsMap, &partitions, 
            &(midendContext->minExtLen), &(midendContext->maxExtLen), newFieldBitWidth, stackSize, &numFullStacks, 
            &residualStackSize),
        // new P4::MidEndLast(),
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),
        //////////////////////////////////////////

        new P4::MidEndLast(),
        new CSA::HdrToStructs(&refMap, &typeMap),
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),
        new CSA::RemoveMSAConstructs(), 
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),

        // RmUnusedApplyParams should be final pass. It makes translation legible
        // for ease debugging on target. It is PassRepeated. so needs a dummy
        // Transform pass after it before.
        new CSA::RmUnusedApplyParams(&refMap, &typeMap, 
                                     &(TofinoConstants::archP4ControlNames)),
        new CSA::CloneWithFreshPath(),
        new P4::ResolveReferences(&refMap, true),
        new P4::RemoveAllUnusedDeclarations(&refMap),
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),
        new P4::MidEndLast(),
        new CSA::DeadFieldElimination(&refMap, &typeMap),
        // new CSA::AnnotateFields(&refMap, &typeMap),
        new P4::MidEndLast(),
    };

    msaTofinoBackend.setName("MSATofinoBackendPasses");
    msaTofinoBackend.addDebugHooks(hooks);
    program = program->apply(msaTofinoBackend);
    if (::errorCount() > 0)
        return nullptr;

    return program;
}


} 
