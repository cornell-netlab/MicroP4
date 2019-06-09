#include <fstream>
#include "extensions/csa/switch/parseInput.h"
#include "ir/json_loader.h"
#include "lib/nullstream.h"

namespace CSA {

/*
std::string getFileName(cstring filePath) {
    std::vector<char*> tokens;
    char* path = new char[strlen(filePath.c_str())+1];
    std::strcpy(path, filePath.c_str());
    
    char *token = std::strtok(path, "/.");
    while (token != NULL) {
        tokens.push_back(token);
        std::cout << token << '\n';
        token = std::strtok(NULL, "/.");
    }
    if (tokens.size() < 2)
        return "";
    return std::string(tokens[tokens.size()-2]);
}

std::vector<std::pair<std::string, const IR::P4Program*>> 
getPreCompiledIRs(CSAOptions& options) {

    std::cout<<options.inputIRFiles;

    std::vector<std::pair<std::string, const IR::P4Program*>> 
          retVec(options.inputIRFiles.size(), std::make_pair("", nullptr));

    for (size_t index = 0; index<options.inputIRFiles.size(); index++) {
        std::ifstream irJSON(options.inputIRFiles[index]);
        if (irJSON.fail()) {
            std::cout<<"could not read "<<options.inputIRFiles[index]<<std::endl;
            exit(0);
        }
        JSONLoader loader(irJSON);
        loader >> retVec[index].second;
        retVec[index].first = getFileName(options.inputIRFiles[index]);
        std::cout<<"file name: "<<retVec[index].first<<"\n";
    }
    return retVec;
}
*/

std::vector<const IR::P4Program*> getPreCompiledIRs(CSAOptions& options) {


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

