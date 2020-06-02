/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include <getopt.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <unordered_set>
#include "msaV1ModelBackend.h"
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
#include "toV1Model.h"
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

const IR::P4Program* MSAV1ModelBackend::run(const IR::P4Program* program) {

    cstring mainP4ControlTypeName;
    if (program == nullptr)
        return nullptr;

    std::vector<const IR::P4Program*> targetIR;
    targetIR.push_back(v1modelP4Program);

    std::vector<cstring> partitions;

    /*
    unsigned minExtLen = 0;
    unsigned maxExtLen = 0;
  
    P4ControlStateReconInfoMap controlToReconInfoMap ;
    */
    P4ControlPartitionInfoMap partitionsMap;
    
    PassManager msaV1ModelBackend = {
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),
        // new P4::MidEndLast(),
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

        new CSA::ToV1Model(&refMap, &typeMap, &partitionsMap, &partitions, 
                           &(midendContext->minExtLen), 
                           &(midendContext->maxExtLen)),

        new P4::MidEndLast(),
        new CSA::HdrToStructs(&refMap, &typeMap),
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),
        new CSA::RemoveMSAConstructs(), 
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),

        // RmUnusedApplyParams should be final pass. It makes translation legible
        // for debugging on target. It is PassRepeated, needs a dummy
        // Transform pass after it before.
        new CSA::RmUnusedApplyParams(&refMap, &typeMap, 
                                     &(V1ModelConstants::archP4ControlNames)),
        new CSA::CloneWithFreshPath(),
        new P4::ResolveReferences(&refMap, true),
        new P4::RemoveAllUnusedDeclarations(&refMap),
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),
        new P4::MidEndLast(),
        new CSA::DeadFieldElimination(&refMap, &typeMap),
        new P4::MidEndLast(),

        // evaluator
    };

    msaV1ModelBackend.setName("MSAV1ModelBackendPasses");
    msaV1ModelBackend.addDebugHooks(hooks);
    program = program->apply(msaV1ModelBackend);
    if (::errorCount() > 0)
        return nullptr;

    return program;
}

} 
