/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "removeMSAConstructs.h"

namespace CSA {

const IR::Node* RemoveMSAConstructs::preorder(IR::Type_Extern* te) {

    if (te->getName() == P4::P4CoreLibrary::instance.pkt.name ||
        te->getName() == P4::P4CoreLibrary::instance.extractor.name || 
        te->getName() == P4::P4CoreLibrary::instance.emitter.name ||
        te->getName() == "multicast_engine" ||
        te->getName() == "in_buf" ||
        te->getName() == "out_buf" ||
        te->getName() == "mc_buf" ) {
        prune();
        return nullptr;
    }
    return te;
}


}// namespace CSA
