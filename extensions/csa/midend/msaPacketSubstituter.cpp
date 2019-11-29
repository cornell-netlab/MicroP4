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
        
    if (path->name.name == pathToReplace){
        std::cout<<"MSAPacketSubstituter: "<<path->name.name <<"\n"; 
      return new IR::Path(replacementPath);
    }
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
            cstring pktStr = NameConstants::csaPacketStructTypeName;
        std::cout<<"MSAPacketSubstituter param: "<<param->name <<"\n"; 
            param = new IR::Parameter(IR::ID(pktStr+"_var"),
                IR::Direction::InOut, new IR::Type_Name(IR::ID(pktStr)));
        }
    }
    return param;
}


const IR::Node* MSAPacketSubstituter::preorder(IR::Declaration_Variable* dv) {
    auto p4c = findContext<IR::P4Control>();
    if (p4c == nullptr)
        return dv;
    if (dv->getName() == replacementPath)
        return nullptr;
    return dv;
}


const IR::Node* MSAPacketSubstituter::preorder(IR::P4Control* p4control) {
    pathToReplace = "";
    visit(p4control->type);
    visit(p4control->body);
    visit(p4control->controlLocals);
    prune();
    return p4control;
}

}

