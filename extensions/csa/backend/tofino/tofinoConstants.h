/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_BACKEND_TOFINO_TOFINOCONSTANTS_H_ 
#define _EXTENSIONS_CSA_BACKEND_TOFINO_TOFINOCONSTANTS_H_ 

#include "ir/ir.h"

namespace CSA {

class TofinoConstants {

  public:
    static const std::unordered_set<cstring> archP4ControlNames;

    static const cstring csaPacketStructInstanceName;
    static const cstring metadataArgName;
    static const cstring userMetadataStructTypeName;

    static const cstring ingressParserName;
    static const cstring egressParserName; 
    static const cstring ingressDeparserName;
    static const cstring egressDeparserName;

    static const cstring ingressControlName; 
    static const cstring egressControlName;

    static const cstring igIMTypeName;
    static const cstring igIMArgName;

    static const cstring igIMResubmitFlag;

    static const cstring igIMFrmParTypeName;
    static const cstring igIMFrmParInstName;

    static const cstring igIMForDePTypeName;
    static const cstring igIMForDePInstName;

    static const cstring igIMForTMTypeName;
    static const cstring igIMForTMInstName;

    static const cstring egIMTypeName; 
    static const cstring egIMArgName;

    static const cstring egIMFrmParTypeName;
    static const cstring egIMFrmParInstName;
    
    static const cstring egIMForDePTypeName;
    static const cstring egIMForDePInstName;

    static const cstring egIMForOPTypeName;
    static const cstring egIMForOPInstName;

    static const cstring parseResubmitStateName;
    static const cstring parsePortMetaStateName;

    static IR::IndexedVector<IR::Parameter>* createIngressIMParams();
    static IR::Vector<IR::Argument>* createIngressIMArgs();

    static IR::IndexedVector<IR::Parameter>* createEgressIMParams();
    static IR::Vector<IR::Argument>* createEgressIMArgs();

  private:
    explicit TofinoConstants() {}
};

}   // namespace CSA
#endif  /* _EXTENSIONS_CSA_BACKEND_TOFINO_TOFINOCONSTANTS_H_ */
