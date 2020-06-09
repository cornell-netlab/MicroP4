/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "v1modelConstants.h"

namespace CSA {

// struct csa_packet_struct_t {
//    csa_packet_h csa_packet;
// }
//
// control ingress (csa_packet_struct_t pkt, csa_user_metadata_t metadataArgName,
// standard_metadata_t csa_sm))
const cstring V1ModelConstants::csaPacketStructInstanceName = "mp";
const cstring V1ModelConstants::metadataArgName = "csa_um";
const cstring V1ModelConstants::stdMetadataArgName = "csa_sm";
const cstring V1ModelConstants::userMetadataStructTypeName = "csa_user_metadata_t";

const cstring V1ModelConstants::parserName = "csa_v1model_parser";
const cstring V1ModelConstants::deparserName = "csa_v1model_deparser";
const cstring V1ModelConstants::ingressControlName = "csa_ingress";
const cstring V1ModelConstants::egressControlName = "csa_egress";
const cstring V1ModelConstants::verifyChecksumName = "csa_verify_checksum";
const cstring V1ModelConstants::computeChecksumName = "csa_compute_checksum";

const std::unordered_set<cstring> V1ModelConstants::archP4ControlNames = {
    V1ModelConstants::deparserName,
    V1ModelConstants::ingressControlName,
    V1ModelConstants::egressControlName,
    V1ModelConstants::verifyChecksumName, 
    V1ModelConstants::computeChecksumName
};

}
