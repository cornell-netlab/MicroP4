/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_MIDEND_CONTROLSTATERECONINFO_H_ 
#define _EXTENSIONS_CSA_MIDEND_CONTROLSTATERECONINFO_H_ 

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"
#include "midend/parserUnroll.h"


namespace CSA {

class PartitionInfo {
  public:
    cstring origControlName;
    IR::Type_Struct* sharedStructType; 
    std::vector<const IR::Declaration_Instance*> sharedDeclInsts;
    std::map<cstring, cstring> param2InstPart1;
    std::map<cstring, cstring> param2InstPart2;
    IR::P4Control* partition1;
    IR::P4Control* partition2;

    // These are kept as Type_Declaration to allow optimization depending on
    // architecture.
    // e.g., for It is be possible to generate IngressDeparser as IR::P4Control 
    // and EgressParser as IR::P4Parser for PSA.
    IR::Type_Declaration* deparser;
    IR::Type_Declaration* parser;

    PartitionInfo(cstring origControlName, IR::Type_Struct* structType, 
        std::vector<const IR::Declaration_Instance*> sharedDeclInsts,
        std::map<cstring, cstring> param2InstPart1,
        std::map<cstring, cstring> param2InstPart2,
        IR::P4Control* part1, IR::P4Control* part2, 
        IR::Type_Declaration* deparser = nullptr, 
        IR::Type_Declaration* parser = nullptr)
      : origControlName(origControlName), sharedStructType(structType), 
        sharedDeclInsts(sharedDeclInsts), param2InstPart1(param2InstPart1),
        param2InstPart2(param2InstPart2), partition1(part1), partition2(part2),
        deparser(deparser), parser(parser) { }

};

typedef std::map<cstring, PartitionInfo> P4ControlPartitionInfoMap;



/*
 * This class stores required information to reconstruct the packet processing
 * state of the partitioned control
 */
class ControlStateReconInfo {

  public:
    cstring controlName;
    cstring headerTypeName;

    IR::P4Control* deparser;
    IR::P4Control* parser;

    // Populated by parserConverter.
    // allPossileFinalValueMaps is used to generate MAT to (de)serialize headers
    P4::ParserStructure* parserStructure = nullptr;

    unsigned numberOfheaders = 16;
    const IR::Type* sharedVariableType;

    ControlStateReconInfo(cstring controlName, cstring headerTypeName, 
                          IR::P4Control* deparser = nullptr,
                          P4::ParserStructure* parserStructure = nullptr) 
      : controlName(controlName), headerTypeName(headerTypeName), deparser(deparser),
        parserStructure(parserStructure) {
        sharedVariableType = IR::Type::Bits::get(numberOfheaders, false);
    }

};

// This map stores control name argument type which should be deparsed and
// parsed, in case the control is paritioned.
typedef std::map<cstring, ControlStateReconInfo*> P4ControlStateReconInfoMap;



}   // namespace CSA
#endif  /* _EXTENSIONS_CSA_MIDEND_CONTROLSTATERECONINFO_H_  */

