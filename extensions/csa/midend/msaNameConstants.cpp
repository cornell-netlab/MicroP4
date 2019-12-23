/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "msaNameConstants.h"


namespace CSA {

const cstring NameConstants::csaHeaderInstanceName = "msa_hdr_stack";
const cstring NameConstants::csaStackInstanceName = "csa_stack";
const cstring NameConstants::csaPacketStructTypeName ="msa_packet_struct_t";
const cstring NameConstants::csaPacketStructName ="mp";

const cstring NameConstants::headerTypeName = "msa_byte_h";

const cstring NameConstants::multiByteHdrTypeName = "msa_twobytes_h";
const cstring NameConstants::msaOneByteHdrInstName = "msa_byte";

const cstring NameConstants::indicesHeaderTypeName = "csa_indices_h";
const cstring NameConstants::indicesHeaderInstanceName = "indices";
const cstring NameConstants::bitStreamFieldName = "data";
              
const cstring NameConstants::csaPktStuLenFName = "pkt_len";
const cstring NameConstants::csaPktStuCurrOffsetFName = "curr_offset";

// used by CSAPacketSubstituter
const cstring NameConstants::csaPktGetPacketStruct = "get_packet_struct";
const cstring NameConstants::csaPktSetPacketStruct = "set_packet_struct";

const cstring NameConstants::csaPakcetOutGetPacketIn = "get_packet_in";
const cstring NameConstants::csaPakcetInExternTypeName = "csa_packet_in";
const cstring NameConstants::csaPakcetOutExternTypeName = "csa_packet_out";


const cstring NameConstants::csaParserRejectStatus = "packet_reject";
const cstring NameConstants::convertedParserMetaParamName = "pr";
}// namespace CSA
