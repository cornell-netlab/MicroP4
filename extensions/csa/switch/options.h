#ifndef _EXTENSIONS_CSA_SWITCH_OPTIONS_H_
#define _EXTENSIONS_CSA_SWITCH_OPTIONS_H_

#include <getopt.h>
#include "frontends/common/options.h"

namespace CSA {

class CSAOptions : public CompilerOptions {
 public:

    // file to output to
    cstring outputFile = nullptr;

    std::vector<cstring> inputIRFiles;

    CSAOptions() {
        registerOption("-o", "outfile",
                [this](const char* arg) { outputFile = arg; return true; },
                "Write output to outfile");
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

using CSAContext = P4CContextWithOptions<CSAOptions>;

};  // namespace CSA

#endif /* _EXTENSIONS_CSA_SWITCH_OPTIONS_H_ */

