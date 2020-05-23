/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "tofinoConstants.h"

namespace CSA {

const cstring TofinoConstants::csaPacketStructInstanceName = "mpkt";
const cstring TofinoConstants::metadataArgName = "msa_um";
const cstring TofinoConstants::userMetadataStructTypeName = "msa_user_metadata_t";

const cstring TofinoConstants::ingressParserName = "msa_tofino_ig_parser";
const cstring TofinoConstants::egressParserName = "msa_tofino_eg_parser";
const cstring TofinoConstants::ingressDeparserName = "msa_tofino_ig_deparser";
const cstring TofinoConstants::egressDeparserName = "msa_tofino_eg_deparser";

const cstring TofinoConstants::ingressControlName = "msa_tofino_ig_control";
const cstring TofinoConstants::egressControlName = "msa_tofino_eg_control";

const cstring TofinoConstants::igIMTypeName = "ingress_intrinsic_metadata_t";
const cstring TofinoConstants::igIMArgName = "ig_intr_md";

const cstring TofinoConstants::igIMResubmitFlag = "resubmit_flag";

const cstring TofinoConstants::igIMFrmParTypeName = "ingress_intrinsic_metadata_from_parser_t";
const cstring TofinoConstants::igIMFrmParInstName = "ig_intr_md_from_prsr";

const cstring TofinoConstants::igIMForDePTypeName = "ingress_intrinsic_metadata_for_deparser_t";
const cstring TofinoConstants::igIMForDePInstName = "ig_intr_md_for_dprsr";

const cstring TofinoConstants::igIMForTMTypeName = "ingress_intrinsic_metadata_for_tm_t";
const cstring TofinoConstants::igIMForTMInstName = "ig_intr_md_for_tm";

const cstring TofinoConstants::egIMTypeName = "egress_intrinsic_metadata_t";
const cstring TofinoConstants::egIMArgName = "eg_intr_md";

const cstring TofinoConstants::egIMFrmParTypeName = "egress_intrinsic_metadata_from_parser_t";
const cstring TofinoConstants::egIMFrmParInstName = "eg_intr_md_from_prsr";

const cstring TofinoConstants::egIMForDePTypeName = "egress_intrinsic_metadata_for_deparser_t";
const cstring TofinoConstants::egIMForDePInstName = "eg_intr_md_for_dprsr";

const cstring TofinoConstants::egIMForOPTypeName = "egress_intrinsic_metadata_for_output_port_t";
const cstring TofinoConstants::egIMForOPInstName = "eg_intr_md_for_oport";


const cstring TofinoConstants::parseResubmitStateName = "parse_resubmit";
const cstring TofinoConstants::parsePortMetaStateName = "parse_port_metadata";

const std::unordered_set<cstring> TofinoConstants::archP4ControlNames = {
    TofinoConstants::ingressDeparserName,
    TofinoConstants::egressDeparserName,
    TofinoConstants::ingressControlName,
    TofinoConstants::egressControlName
};

IR::IndexedVector<IR::Parameter>* TofinoConstants::createIngressIMParams() {
  
    auto parameters = new IR::IndexedVector<IR::Parameter>();
    auto p = new IR::Parameter(IR::ID(TofinoConstants::igIMArgName), IR::Direction::In, 
                                  new IR::Type_Name(TofinoConstants::igIMTypeName));
    parameters->push_back(p);
    p = new IR::Parameter(IR::ID(TofinoConstants::igIMFrmParInstName), IR::Direction::In, 
                                  new IR::Type_Name(TofinoConstants::igIMFrmParTypeName));
    parameters->push_back(p);
    p = new IR::Parameter(IR::ID(TofinoConstants::igIMForDePInstName), IR::Direction::InOut, 
                                  new IR::Type_Name(TofinoConstants::igIMForDePTypeName));
    parameters->push_back(p);
    p = new IR::Parameter(IR::ID(TofinoConstants::igIMForTMInstName), IR::Direction::InOut, 
                                  new IR::Type_Name(TofinoConstants::igIMForTMTypeName));
    parameters->push_back(p);
    return parameters;
}

IR::Vector<IR::Argument>* TofinoConstants::createIngressIMArgs() {
    std::vector<cstring> argNames;
    auto args =  new IR::Vector<IR::Argument>();
    argNames.push_back(TofinoConstants::igIMArgName);
    argNames.push_back(TofinoConstants::igIMFrmParInstName);
    argNames.push_back(TofinoConstants::igIMForDePInstName);
    argNames.push_back(TofinoConstants::igIMForTMInstName);
    for (auto an : argNames) {
      auto arg = new IR::Argument(new IR::PathExpression(an));
      args->push_back(arg);
    }
    return args;
}

IR::IndexedVector<IR::Parameter>* TofinoConstants::createEgressIMParams() {
  
    auto parameters = new IR::IndexedVector<IR::Parameter>();
    auto p = new IR::Parameter(IR::ID(TofinoConstants::egIMArgName), IR::Direction::In, 
                                  new IR::Type_Name(TofinoConstants::egIMTypeName));
    parameters->push_back(p);
    p = new IR::Parameter(IR::ID(TofinoConstants::egIMFrmParInstName), IR::Direction::In, 
                                  new IR::Type_Name(TofinoConstants::egIMFrmParTypeName));
    parameters->push_back(p);
    p = new IR::Parameter(IR::ID(TofinoConstants::egIMForDePInstName), IR::Direction::InOut, 
                                  new IR::Type_Name(TofinoConstants::egIMForDePTypeName));
    parameters->push_back(p);
    p = new IR::Parameter(IR::ID(TofinoConstants::egIMForOPInstName), IR::Direction::InOut, 
                                  new IR::Type_Name(TofinoConstants::egIMForOPTypeName));
    parameters->push_back(p);
    return parameters;
}

IR::Vector<IR::Argument>* TofinoConstants::createEgressIMArgs() {
    std::vector<cstring> argNames;
    auto args =  new IR::Vector<IR::Argument>();
    argNames.push_back(TofinoConstants::egIMArgName);
    argNames.push_back(TofinoConstants::egIMFrmParInstName);
    argNames.push_back(TofinoConstants::egIMForDePInstName);
    argNames.push_back(TofinoConstants::egIMForOPInstName);
    for (auto an : argNames) {
      auto arg = new IR::Argument(new IR::PathExpression(an));
      args->push_back(arg);
    }
    return args;
}


}
