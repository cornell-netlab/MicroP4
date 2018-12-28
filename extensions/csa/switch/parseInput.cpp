#include <fstream>
#include "extensions/csa/switch/parseInput.h"
#include "ir/json_loader.h"
#include "lib/nullstream.h"

namespace CSA {

std::vector<const IR::P4Program*> getPreCompiledIRs(CSAOptions& options) {

    std::cout<<options.inputIRFiles;

    std::vector<const IR::P4Program*> retVec(options.inputIRFiles.size(), nullptr);

    for (size_t index = 0; index<options.inputIRFiles.size(); index++) {
        std::ifstream irJSON(options.inputIRFiles[index]);
        if (irJSON.fail()) {
            std::cout<<"could not read "<<options.inputIRFiles[index]<<std::endl;
            exit(0);
        }
        JSONLoader loader(irJSON);
        loader >> retVec[index];
    }
    return retVec;
}

}

