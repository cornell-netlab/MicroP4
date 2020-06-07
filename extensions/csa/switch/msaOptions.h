/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_SWITCH_OPTIONS_H_
#define _EXTENSIONS_CSA_SWITCH_OPTIONS_H_

#include <getopt.h>
#include "frontends/common/options.h"

namespace CSA {

class MSAOptions : public CompilerOptions {
 public:

    // file to output to
    cstring outputFile = nullptr;
    cstring targetArch = nullptr;

    cstring targetArchP4 = nullptr;
    std::vector<cstring> inputIRFiles;

    MSAOptions() {
        registerOption("-o", "outfile",
                [this](const char* arg) { outputFile = arg; return true; },
                "Write output to outfile");
        registerOption("--target-arch", "v1model or tna",
                [this](const char* arg) { targetArch = arg; return true; },
                "Write output to outfile");
        registerOption("--target-arch-p4", "absolute file path to .p4",
                [this](const char* arg) { targetArchP4 = arg; return true; },
                "Target Architecture Definitions in P4, if --target-arch == tna, provide location of tna.p4 and put dependent .p4s in p4include directory");
        registerOption("-l", "IRFile1[,IRFile2]",
                [this](const char* arg) {
                       auto copy = strdup(arg);
                       while (auto pass = strsep(&copy, ",")) {
                           inputIRFiles.push_back(pass);
                        }
                       return true;
                },
                "links IRFiles...");
    }
};

using CSAContext = P4CContextWithOptions<MSAOptions>;

};  // namespace CSA

#endif /* _EXTENSIONS_CSA_SWITCH_OPTIONS_H_ */

