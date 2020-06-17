/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include <stdio.h>
#include <string>
#include <iostream>

#include "ir/ir.h"
#include "ir/json_generator.h"
#include "control-plane/p4RuntimeSerializer.h"
#include "frontends/common/applyOptionsPragmas.h"
#include "frontends/common/parseInput.h"
#include "frontends/p4/frontend.h"
#include "lib/error.h"
#include "lib/exceptions.h"
#include "frontends/p4/toP4/toP4.h"
#include "lib/gc.h"
#include "lib/log.h"
#include "lib/path.h"
#include "lib/nullstream.h"
#include "extensions/csa/switch/version.h"
#include "extensions/csa/switch/msaOptions.h"
#include "extensions/csa/switch/parseInput.h"
#include "extensions/csa/midend/csamidend.h"
#include "extensions/csa/backend/v1model/msaV1ModelBackend.h"
#include "extensions/csa/backend/tofino/msaTofinoBackend.h"


bool hasMain(const IR::P4Program* p4Program) {
    auto mainDecls = p4Program->getDeclsByName(IR::P4Program::main)->toVector();
    return (mainDecls->size() != 0);
}


const IR::P4Program* getIRFromTargetArchP4(CSA::MSAOptions& msaOptions) {
    FILE* in = nullptr;
#ifdef __clang__
    std::string cmd("cc -E -x c -Wno-comment");
#else
    std::string cmd("cpp");
#endif

    cstring absFilePath = "";
    if (msaOptions.targetArchP4 != nullptr)
        absFilePath = msaOptions.targetArchP4;
    else if (msaOptions.targetArch != nullptr)
        absFilePath = p4includePath+cstring("/")+msaOptions.targetArch+".p4";
    else {
        ::error("Error finding target arch P4 source");
        return nullptr;
    }

    char * driverP4IncludePath = getenv("P4C_16_INCLUDE_PATH");
    cmd += cstring(" -C -undef -nostdinc -x assembler-with-cpp") + " " + 
           msaOptions.preprocessor_options
        + (driverP4IncludePath ? " -I" + cstring(driverP4IncludePath) : "")
        + " -I" + (p4includePath) + " " + absFilePath;

    // std::cout<<"p4includePath "<<p4includePath<<"\n";
    // file = p4includePath+cstring("/")+file;
    in = popen(cmd.c_str(), "r");
    if (in == nullptr) {
        ::error("Error invoking preprocessor");
        perror("");
        return nullptr;
    }

    //auto p4program = P4::P4ParserDriver::parse(in, file);
    auto p4program = P4::P4ParserDriver::parse(in, absFilePath);
    // std::cout<<"v1model objects size : "<<p4program->objects.size()<<"\n";
    if (::errorCount() > 0) { 
        ::error("%1% errors encountered, aborting compilation", ::errorCount());
        return nullptr;
    }
    return p4program;
}


int main(int argc, char *const argv[]) {
    setup_gc_logging();

    AutoCompileContext autoCSAContext(new CSA::CSAContext);
    auto& options = CSA::CSAContext::get().options();
    options.langVersion = CompilerOptions::FrontendVersion::P4_16;
    options.compilerVersion = CSA_SWITCH_VERSION_STRING;

    if (options.process(argc, argv) != nullptr)
        options.setInputFile();
    if (::errorCount() > 0)
        return 1;

    auto hook = options.getDebugHook();

    auto precompiledP4Programs = CSA::getPreCompiledIRs(options);
    // std::cout<<"in Main number of IRs "<<precompiledP4Programs.size()<<"\n";

    auto program = P4::parseP4File(options);
    if (program == nullptr || ::errorCount() > 0)
        return 1;

    P4::P4COptionPragmaParser optionsPragmaParser;
    program->apply(P4::ApplyOptionsPragmas(optionsPragmaParser));
    
    if (program == nullptr || ::errorCount() > 0)
        return 1;

    try {
        P4::FrontEnd frontend;
        frontend.addDebugHook(hook);
        program = frontend.run(options, program);
    } catch (const Util::P4CExceptionBase &bug) {
        std::cerr << bug.what() << std::endl;
        return 1;
    }

    if (program == nullptr || ::errorCount() > 0) {
        std::cout<<"nullptr or error after frontend \n";
        return 1;
    }


    if (options.outputFile || !hasMain(program)) {
        // std::cout<<"Generating P4Runtime APIs...\n";
        P4::serializeP4RuntimeIfRequired(program, options);
        if (::errorCount() > 0) {
            std::cout<<"error in generating P4Runtime APIs\n";
            return 1;
        }
        JSONGenerator(*openFile(options.outputFile, true)) << program << std::endl;
        return 0;
    }

    if (hasMain(program)) {
        if (options.targetArch == nullptr) {
            std::cout<<"--targetArch mandatory [v1model  or tna]\n";
            return 0;
        }
        std::cout<<"Running MicroP4 Midend \n";
        auto midendContext = new CSA::MidendContext();
        CSA::CSAMidEnd csaMidend(options);
        program = csaMidend.run(program, precompiledP4Programs, midendContext);
        if (::errorCount() > 0) {
            std::cout<<"error in running MicroP4 Midend\n";
            return 1;
        }

        //////////// invoking appropriate backend //////////// 

        // preparing filename to dump translated code
        Util::PathName fname(options.file);
        Util::PathName newName(fname.getBasename() + "-"+options.targetArch 
            + ".p4");
        auto fn = Util::PathName(options.dumpFolder).join(newName.toString());
        cstring fileName = fn.toString();
        // getting target IR

        std::cout<<"Running MicroP4 Backend \n";

        if (options.targetArch == nullptr) {
            std::cout<<"targetArch not provided \n";
            return 1;
        }
        
        auto targetArchIR = getIRFromTargetArchP4(options);

        if (options.targetArch == "v1model") {
            CSA::MSAV1ModelBackend msaV1ModelBackend(options);
            program = msaV1ModelBackend.run(program, midendContext, targetArchIR);
        }
        else if (options.targetArch == "tna") {
            CSA::MSATofinoBackend msaTofinoBackend(options);
            program = msaTofinoBackend.run(program, midendContext, targetArchIR);
        } else {
            std::cout<<"unknown target architecture \n";
        }
        if (::errorCount() > 0) {
            std::cout<<"error in running "<<options.targetArch<<"backend \n";
            return 1;
        }

        auto stream = openFile(fileName, true);
        if (stream != nullptr) {
            P4::ToP4 toP4(stream, Log::verbose(), options.file);
            program->apply(toP4);
        }
        return 0;
    }

    return ::errorCount() > 0;
}



