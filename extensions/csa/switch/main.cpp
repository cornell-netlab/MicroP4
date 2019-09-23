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
#include "extensions/csa/switch/options.h"
#include "extensions/csa/switch/parseInput.h"
#include "extensions/csa/midend/csamidend.h"


bool hasMain(const IR::P4Program* p4Program) {
    auto mainDecls = p4Program->getDeclsByName(IR::P4Program::main)->toVector();
    return (mainDecls->size() != 0);
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

        /*
        CSA::CSAMidEnd csaMidend(options);
        program = csaMidend.run(program, precompiledP4Programs);
        */

    if (options.outputFile || !hasMain(program)) {
        std::cout<<"Generating P4Runtime APIs...\n";
        P4::serializeP4RuntimeIfRequired(program, options);
        if (::errorCount() > 0) {
            std::cout<<"error in generating P4Runtime APIs\n";
            return 1;
        }
        JSONGenerator(*openFile(options.outputFile, true)) << program << std::endl;
        return 0;
    }

    if (hasMain(program)) {
        std::cout<<"Running CSAMidend \n";
        CSA::CSAMidEnd csaMidend(options);
        program = csaMidend.run(program, precompiledP4Programs);
        if (options.arch == nullptr)
            options.arch = "v1model";

        Util::PathName fname(options.file);
        Util::PathName newName(fname.getBasename() + options.arch + "." + fname.getExtension());
        auto fn = Util::PathName(options.dumpFolder).join(newName.toString());
        cstring fileName = fn.toString();
        auto stream = openFile(fileName, true);
        if (stream != nullptr) {
            if (Log::verbose())
                std::cerr << "Writing program for "<<options.arch<< " to " << fileName << std::endl;
            P4::ToP4 toP4(stream, Log::verbose(), options.file);
            program->apply(toP4);
        }

        if (::errorCount() > 0) {
            std::cout<<"error in running CSAMidend\n";
            return 1;
        }
        return 0;
    }



/*
    const IR::ToplevelBlock* toplevel = nullptr;
    BMV2::SimpleSwitchMidEnd midEnd(options);
    midEnd.addDebugHook(hook);
    try {
        toplevel = midEnd.process(program);
        if (::errorCount() > 1 || toplevel == nullptr ||
            toplevel->getMain() == nullptr)
            return 1;
        if (options.dumpJsonFile)
            JSONGenerator(*openFile(options.dumpJsonFile, true)) << program << std::endl;
    } catch (const Util::P4CExceptionBase &bug) {
        std::cerr << bug.what() << std::endl;
        return 1;
    }
    if (::errorCount() > 0)
        return 1;
*/

/*
    auto backend = new BMV2::SimpleSwitchBackend(options, &midEnd.refMap,
                                                 &midEnd.typeMap, &midEnd.enumMap);

    try {
        backend->convert(toplevel);
    } catch (const Util::P4CExceptionBase &bug) {
        std::cerr << bug.what() << std::endl;
        return 1;
    }
    if (::errorCount() > 0)
        return 1;

    if (!options.outputFile.isNullOrEmpty()) {
        std::ostream* out = openFile(options.outputFile, false);
        if (out != nullptr) {
            backend->serialize(*out);
            out->flush();
        }
    }
*/

    return ::errorCount() > 0;
}
