/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include <getopt.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <unordered_set>
#include "csamidend.h"
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
#include "csaExternSubstituter.h"
#include "parserConverter.h"
#include "msaPacketSubstituter.h"
#include "removeMSAConstructs.h"
#include "staticAnalyzer.h"
#include "hdrToStructs.h"
#include "removeUnusedApplyParams.h"
#include "cloneWithFreshPath.h"
#include "deadFieldElimination.h"
#include "paraDeParMerge.h"
#include "../backend/tofino/replaceByteHdrStack.h"
#include "../backend/tofino/toTofino.h"
#include "../backend/tofino/annotateFields.h"

namespace CSA {

unsigned DebugPass::i = 0;
const IR::P4Program* CSAMidEnd::run(const IR::P4Program* program, 
                                    std::vector<const IR::P4Program*> precompiledIRs) {

    cstring mainP4ControlTypeName;
    if (program == nullptr)
        return nullptr;

    auto v1modelP4Program = getV1ModelIR();
    auto tnaP4Program = getTofinoIR();

    auto coreP4Program = getCoreIR();

    std::vector<const IR::P4Program*> irs = precompiledIRs;
    irs.insert(irs.begin(), coreP4Program);

    std::vector<const IR::P4Program*> targetIR;
    // targetIR.push_back(v1modelP4Program);
    targetIR.push_back(tnaP4Program);

    std::vector<cstring> partitions;

    unsigned minExtLen = 0;
    unsigned maxExtLen = 0;
    unsigned byteStackSize = 0;
  
    P4ControlStateReconInfoMap controlToReconInfoMap ;
    P4ControlPartitionInfoMap partitionsMap;
    // auto evaluator = new P4::EvaluatorPass(&refMap, &typeMap);
    
    // For tofino backend pass
    // I will split this pass later
    unsigned stackSize = 32;
    unsigned newFieldBitWidth = 16;
    unsigned numFullStacks;
    unsigned residualStackSize;

    PassManager csaMidEnd = {
        new P4::MidEndLast(),
        new CSA::MergeDeclarations(irs),
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),
        new P4::MidEndLast(),
        new CSA::HardcodedMergeTest(&refMap, &typeMap),
        new P4::MidEndLast(),
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),
        


        /*

        // new CSA::DebugPass(),
        new CSA::ToControl(&refMap, &typeMap, &mainP4ControlTypeName, 
                           &controlToReconInfoMap, &minExtLen, &maxExtLen),
        new P4::MidEndLast(),

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
                                     &partitionsMap, &controlToReconInfoMap, 
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
            &minExtLen, &maxExtLen, newFieldBitWidth, stackSize, &numFullStacks, 
            &residualStackSize),
        // new P4::MidEndLast(),
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),
        //////////////////////////////////////////

        // new CSA::ToV1Model(&refMap, &typeMap, &partitionsMap, &partitions, 
        //                   &minExtLen, &maxExtLen),
        // new P4::MidEndLast(),

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
        */

        // evaluator
    };

    csaMidEnd.setName("CSAMidEndPasses");
    csaMidEnd.addDebugHooks(hooks);
    program = program->apply(csaMidEnd);
    if (::errorCount() > 0)
        return nullptr;

    return program;
}

const IR::P4Program* CSAMidEnd::getCoreIR() {
    FILE* in = nullptr;

    cstring file = "core.p4";
#ifdef __clang__
    std::string cmd("cc -E -x c -Wno-comment");
#else
    std::string cmd("cpp");
#endif

    char * driverP4IncludePath = getenv("P4C_16_INCLUDE_PATH");
    cmd += cstring(" -C -undef -nostdinc -x assembler-with-cpp") + " " + 
           csaOptions.preprocessor_options
        + (driverP4IncludePath ? " -I" + cstring(driverP4IncludePath) : "")
        + " -I" + (p4includePath) + " " + p4includePath+"/"+file;

    // std::cout<<"p4includePath "<<p4includePath<<"\n";
    file = p4includePath+cstring("/")+file;
    in = popen(cmd.c_str(), "r");
    if (in == nullptr) {
        ::error("Error invoking preprocessor");
        perror("");
        return nullptr;
    }

    auto p4program = P4::P4ParserDriver::parse(in, file);
    // std::cout<<"v1model objects size : "<<p4program->objects.size()<<"\n";
    if (::errorCount() > 0) { 
        ::error("%1% errors encountered, aborting compilation", ::errorCount());
        return nullptr;
    }
    return p4program;
}


const IR::P4Program* CSAMidEnd::getV1ModelIR() {
    FILE* in = nullptr;

    cstring file = "v1model.p4";
#ifdef __clang__
    std::string cmd("cc -E -x c -Wno-comment");
#else
    std::string cmd("cpp");
#endif

    char * driverP4IncludePath = getenv("P4C_16_INCLUDE_PATH");
    cmd += cstring(" -C -undef -nostdinc -x assembler-with-cpp") + " " + 
           csaOptions.preprocessor_options
        + (driverP4IncludePath ? " -I" + cstring(driverP4IncludePath) : "")
        + " -I" + (p4includePath) + " " + p4includePath+"/"+file;

    // std::cout<<"p4includePath "<<p4includePath<<"\n";
    file = p4includePath+cstring("/")+file;
    in = popen(cmd.c_str(), "r");
    if (in == nullptr) {
        ::error("Error invoking preprocessor");
        perror("");
        return nullptr;
    }

    auto p4program = P4::P4ParserDriver::parse(in, file);
    // std::cout<<"v1model objects size : "<<p4program->objects.size()<<"\n";
    if (::errorCount() > 0) { 
        ::error("%1% errors encountered, aborting compilation", ::errorCount());
        return nullptr;
    }
    return p4program;
}


const IR::P4Program* CSAMidEnd::getTofinoIR() {
    FILE* in = nullptr;

    cstring file = "tna.p4";
#ifdef __clang__
    std::string cmd("cc -E -x c -Wno-comment");
#else
    std::string cmd("cpp");
#endif

    char * driverP4IncludePath = getenv("P4C_16_INCLUDE_PATH");
    cmd += cstring(" -C -undef -nostdinc -x assembler-with-cpp") + " " + 
           csaOptions.preprocessor_options
        + (driverP4IncludePath ? " -I" + cstring(driverP4IncludePath) : "")
        + " -I" + (p4includePath) + " " + p4includePath+"/"+file;

    // std::cout<<"p4includePath "<<p4includePath<<"\n";
    file = p4includePath+cstring("/")+file;
    in = popen(cmd.c_str(), "r");
    if (in == nullptr) {
        ::error("Error invoking preprocessor");
        perror("");
        return nullptr;
    }

    auto p4program = P4::P4ParserDriver::parse(in, file);
    // std::cout<<"v1model objects size : "<<p4program->objects.size()<<"\n";
    if (::errorCount() > 0) { 
        ::error("%1% errors encountered, aborting compilation", ::errorCount());
        return nullptr;
    }
    return p4program;
}


} 
