/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */
#include "msaPacketSubstituter.h"

namespace CSA {

const IR::Node* MSAPacketSubstituter::preorder(IR::Path* path) {
    auto p4c = findContext<IR::P4Control>();
    if (p4c == nullptr) {
        return path;
    }
        
    if (path->name.name == intermediatePath || path->name.name == pathToReplace)
        return new IR::Path(NameConstants::csaPacketStructName);
    else
        return path;
}


const IR::Node* MSAPacketSubstituter::preorder(IR::Parameter* param) {
    auto p4c = findContext<IR::P4Control>();
    if (p4c == nullptr)
        return param;

    auto tt = typeMap->getTypeType(param->type, false);
    if (tt != nullptr && tt->is<IR::Type_Extern>()) {
        auto te = tt->to<IR::Type_Extern>();
        if (te->getName() ==  P4::P4CoreLibrary::instance.pkt.name) {
            pathToReplace = param->getName();
            cstring pktStrTypeName = NameConstants::csaPacketStructTypeName;
            cstring pktStrName = NameConstants::csaPacketStructName;
            // std::cout<<"MSAPacketSubstituter param: "<<param->name <<"\n"; 
            prune();
            return new IR::Parameter(IR::ID(pktStrName),
                IR::Direction::InOut, new IR::Type_Name(IR::ID(pktStrTypeName)));
        }
    }
    return param;
}


const IR::Node* MSAPacketSubstituter::preorder(IR::Declaration_Variable* dv) {
    auto p4c = findContext<IR::P4Control>();
    if (p4c == nullptr)
        return dv;
    if (dv->getName() == intermediatePath)
        return nullptr;
    return dv;
}


const IR::Node* MSAPacketSubstituter::preorder(IR::P4Control* p4control) {
    pathToReplace = "";
    visit(p4control->type);
    visit(p4control->controlLocals);
    visit(p4control->body);
    prune();
    return p4control;
}

}

