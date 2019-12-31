/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_MIDEND_NAMECONSTANTS_H_ 
#define _EXTENSIONS_CSA_MIDEND_NAMECONSTANTS_H_ 

#include "ir/ir.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"
#include "deparserConverter.h"
#include "controlStateReconInfo.h"
#include "parserConverter.h"


namespace CSA {




class NameConstants {
  public:
    static const cstring headerTypeName;

    static const cstring multiByteHdrTypeName;
    static const cstring msaOneByteHdrInstName;

    static const cstring indicesHeaderTypeName;
    static const cstring indicesHeaderInstanceName;
    static const cstring bitStreamFieldName;
    static const cstring csaPacketStructTypeName;
    static const cstring csaPacketStructName;
    static const cstring csaHeaderInstanceName;
    static const cstring csaStackInstanceName;
    static const cstring csaPakcetOutGetPacketIn;

    static const cstring csaPakcetInExternTypeName;
    static const cstring csaPakcetOutExternTypeName;

    static const cstring HeaderValidityOpStrTypeName;

    static const cstring csaPktGetPacketStruct;
    static const cstring csaPktSetPacketStruct;

    static const cstring csaPktStuLenFName;
    static const cstring csaPktStuCurrOffsetFName;


    static const cstring csaParserRejectStatus;
    static const cstring convertedParserMetaParamName;
  private:
    NameConstants() {}

};

}   // namespace CSA
#endif  /* _EXTENSIONS_CSA_MIDEND_NAMECONSTANTS_H_ */

