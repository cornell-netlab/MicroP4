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
#include "extensions/csa/midend/parserConverter.h"
#include "frontends/common/parseInput.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/evaluator/evaluator.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"
#include "frontends/p4/unusedDeclarations.h"
#include "frontends/parsers/parserDriver.h"
#include "midend/parserUnroll.h"
#include "midend/midEndLast.h"
#include "mergeDeclarations.h"
#include "slicePipeControl.h"
#include "toControl.h"
#include "toV1Model.h"
#include "controlStateReconInfo.h"
#include "csaExternSubstituter.h"

namespace CSA {

const IR::P4Program* CSAMidEnd::run(const IR::P4Program* program, 
                                    std::vector<const IR::P4Program*> precompiledIRs) {

    cstring mainP4ControlTypeName;
    if (program == nullptr)
        return nullptr;

    auto v1modelP4Program = getV1ModelIR();
    auto coreP4Program = getCoreIR();
    std::vector<const IR::P4Program*> irs = precompiledIRs;
    irs.insert(irs.begin(), coreP4Program);

    std::vector<const IR::P4Program*> v1ModelIR;
    v1ModelIR.push_back(v1modelP4Program);

    std::vector<cstring> partitions;
  
    P4ControlStateReconInfoMap controlToReconInfoMap ;
    P4ControlPartitionInfoMap partitionsMap;
    // auto evaluator = new P4::EvaluatorPass(&refMap, &typeMap);
    PassManager csaMidEnd = {
        // new P4::MidEndLast(),
        new CSA::MergeDeclarations(irs),
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),
        new CSA::ToControl(&refMap, &typeMap, &mainP4ControlTypeName, 
                           &controlToReconInfoMap),
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
                                     &partitionsMap, &controlToReconInfoMap, 
                                     &partitions),
        new CSA::MergeDeclarations(v1ModelIR), 

        new P4::MidEndLast(),
        new CSA::CSAExternSubstituter(&refMap, &typeMap, &partitionsMap, 
                                      &partitions),
        new P4::MidEndLast(),
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),
        new CSA::ToV1Model(&refMap, &typeMap, &partitionsMap, &partitions),
        new P4::MidEndLast(),
        new P4::ResolveReferences(&refMap, true),
        new P4::RemoveAllUnusedDeclarations(&refMap),
        new P4::ResolveReferences(&refMap, true),
        new P4::TypeInference(&refMap, &typeMap, false),
        new P4::MidEndLast(),
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

} 
