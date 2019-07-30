/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_CSAMODEL_H_
#define _EXTENSIONS_CSA_CSAMODEL_H_

#include "lib/cstring.h"
#include "frontends/common/model.h"
#include "frontends/p4/coreLibrary.h"
#include "ir/ir.h"
#include "lib/json.h"

namespace CSA {

struct EgressSpec_Model : public ::Model::Extern_Model {
    explicit EgressSpec_Model(cstring name) : ::Model::Extern_Model(name) {}
};


struct CSAPacketPathType_Model : public ::Model::Enum_Model { 
    CSAPacketPathType_Model(cstring name) : ::Model::Enum_Model(name) {}
};


// standard metadata fields
struct StandardMetadataType_Model : public ::Model::Type_Model {
    explicit StandardMetadataType_Model(cstring name) :
            ::Model::Type_Model(name), drop_flag("drop_flag"), packet_path("packet_path") {}
    ::Model::Elem drop_flag;
    CSAPacketPathType_Model packet_path;
};


struct Parser_Model : public ::Model::Elem {
    Parser_Model(Model::Type_Model headersType, 
                 Model::Type_Model userMetadataType,
                 Model::Type_Model standardMetadataType,
                 Model::Type_Model programScopeMetadataType) :
        Model::Elem("Parser"),
        packetParam("pin", P4::P4CoreLibrary::instance.packetIn, 0),
        headersParam("parsed_hdr", headersType, 1),
        metadataParam("meta", userMetadataType, 2),
        standardMetadataParam("standard_metadata", standardMetadataType, 3).
        standardMetadataParam("program_scope_metadata", programScopeMetadataType, 4)
    {}
    ::Model::Param_Model packetParam;
    ::Model::Param_Model headersParam;
    ::Model::Param_Model userMetadataParam;
    ::Model::Param_Model standardMetadataParam;
    ::Model::Param_Model programScopeMetadataParam;
};


struct Deparser_Model : public ::Model::Elem {
    explicit Deparser_Model(Model::Type_Model headersType) :
            Model::Elem("Deparser"),
            packetParam("pin", P4::P4CoreLibrary::instance.packetOut, 0),
            headersParam("parsed_hdr,", headersType, 1)
            standardMetadataParam("program_scope_metadata", programScopeMetadataType, 2)
    {}
    ::Model::Param_Model packetParam;
    ::Model::Param_Model headersParam;
};


struct Control_Model : public ::Model::Elem {
    Control_Model(cstring name, unsigned int paramStartIndex,
                  Model::Type_Model headersType, 
                  Model::Type_Model metadataType,
                  Model::Type_Model standardMetadataType
                  EgressSpec_Model egressSpecType) :
        Model::Elem(name),
        headersParam("parsed_hdr", headersType, paramStartIndex),
        userMetadataParam("meta", metadataType, paramStartIndex,+1),
        standardMetadataParam("standard_metadata", standardMetadataType, paramStartIndex,+2),
        egressSpecParam("es", egressSpecType, paramStartIndex+3) // slicing will happen here
    {}
    ::Model::Param_Model headersParam;
    ::Model::Param_Model userMetadataParam;
    ::Model::Param_Model standardMetadataParam;
    ::Model::Param_Model egressSpecParam;
};


struct Pipe_Model : public Control_Model {
    Pipe_Model(Model::Type_Model headersType, 
               Model::Type_Model metadataType,
               Model::Type_Model standardMetadataType
               EgressSpec_Model egressSpecType) 
      : Control_Model("Pipe", 0, headersType, metadataType, 
                      standardMetadataType egressSpecType) { }
};


struct Import_Model : public Control_Model {
    Pipe_Model(Model::Type_Model inMetadataType, 
               Model::Type_Model inOutMetadataType,
               Model::Type_Model headersType, 
               Model::Type_Model metadataType,
               Model::Type_Model standardMetadataType
               EgressSpec_Model egressSpecType) 
      : inMetadataParam("in_meta", inMetadataType, 0), 
        inOutMetadataParam("inout_meta", inOutMetadataType, 1),
        Control_Model("Import", 2, headersType, metadataType, 
            standardMetadataType egressSpecType) { }
    ::Model::Param_Model inMetadataParam;
    ::Model::Param_Model inOutMetadataParam;
};


struct Export_Model : public Control_Model {
    Pipe_Model(Model::Type_Model outMetadataType, 
               Model::Type_Model InOutMetadataType,
               Model::Type_Model headersType, 
               Model::Type_Model metadataType,
               Model::Type_Model standardMetadataType
               EgressSpec_Model egressSpecType) 
      : outMetadataParam("out_meta", outMetadataType, 0), 
        inOutMetadataParam("inout_meta", inOutMetadataType, 1),
        Control_Model("Export", 2, headersType, metadataType, 
                      standardMetadataType egressSpecType) { }
    ::Model::Param_Model outMetadataParam;
    ::Model::Param_Model inOutMetadataParam;
};


struct CSASwitch_Model : public ::Model::Elem {
    Switch_Model() : Model::Elem("CSASwitch") {}
    
    Parser_Model      parser;
    Pipe_Model        pipeControl;
    Import_Model      importControl;
    Export_Model      exportControl;
    Deparser_Model    deparser;
    
    struct ResultPipe_Model : public Control_Model {
        Pipe_Model(Model::Type_Model inMetadataType, 
                   Model::Type_Model outMetadataType,
                   Model::Type_Model inOutMetadataType,
                   Model::Type_Model headersType, 
                   Model::Type_Model metadataType,
                   Model::Type_Model standardMetadataType
                   EgressSpec_Model egressSpecType,
                   Model::Type_Model programScopeMetadataType,
                   Model::Type_Model calleeContextType)
          : inMetadataParam("in_meta", inMetadataType, 0), 
            outMetadataParam("out_meta", outMetadataType, 1),
            inOutMetadataParam("inout_meta", inOutMetadataType, 2),
            Control_Model("ResultPipe", 3, headersType, metadataType, 
                          standardMetadataType egressSpecType),
            programScopeMetadataParam("program_scope_metadata", programScopeMetadataType, 7),
            calleeContextParam("ctx", calleeContextType, 8)
            { }

        ::Model::Param_Model inMetadataParam;
        ::Model::Param_Model outMetadataParam;
        ::Model::Param_Model inOutMetadataParam;
        ::Model::Param_Model programScopeMetadataParam;
        ::Model::Param_Model calleeContextParam;
    };

    struct ParalleSwitch_Model : public ::Model::Elem {
        ParalleSwitch_Model() : ::Model::Elem("ParallelSwitch"){}


        ResultPipe_Model resultPipeControl;
    };
};


struct OrchestrationSwitch_Model : public ::Model::Elem {
    OrchestrationSwitch_Model() : Model::Elem("OrchestrationSwitch") {}

};


class CSAModel : public ::Model::Model {
 protected:
    CSAModel() :
            Model::Model("0.1"), file("csa.p4"),
            standardMetadata("standard_metadata"),
            headersType("headers")
    {}

 public:
    ::Model::Elem               file;
    ::Model::Elem               standardMetadata;
    ::Model::Type_Model         headersType;
    ::Model::Type_Model         metadataType;

    EgressSpec_Model            egress;
    StandardMetadataType_Model  standardMetadataType;

    CSASwitch_Model             csaSWModel;
    OrchestrationSwitch_Model   oswModel;

    static CSAModel instance;
};

}  // namespace CSA

#endif /* _EXTENSIONS_CSA_CSAMODEL_H_ */
