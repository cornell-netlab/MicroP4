/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_MIDEND_NAMECONSTANTS_H_ 
#define _EXTENSIONS_CSA_MIDEND_NAMECONSTANTS_H_ 

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

    static const cstring headerValidityOpStrTypeName;
    static const cstring headerValidityOpStrParamName;
    static const cstring parserMetaStrTypeName;
    static const cstring parserMetaStrParamName;

    static const cstring hdrValidFlagSuffix;
    static const cstring hdrSetValidOpFlagSuffix;
    static const cstring hdrSetInvalidOpFlagSuffix;

    static const cstring intermediateVarDeclSuffix;
    static const cstring csaPktGetPacketStruct;
    static const cstring csaPktSetPacketStruct;

    static const cstring csaPktStuLenFName;
    static const cstring csaPktStuCurrOffsetFName;
    static const cstring csaPktStuInitOffsetFName;


    static const cstring csaParserRejectStatus;
  private:
    NameConstants() {}

};

}   // namespace CSA
#endif  /* _EXTENSIONS_CSA_MIDEND_NAMECONSTANTS_H_ */

