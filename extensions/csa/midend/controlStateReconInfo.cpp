/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "controlStateReconInfo.h"
#include "deparserConverter.h"
#include "deparserInverter.h"

namespace CSA {


const IR::P4Control* ControlStateReconInfo::getDeparser(bool woVOPs) {

    const IR::P4Control* depCon = woVOPs ? deparserWoVOPs : deparser;

    auto ntc = const_cast<IR::Type_Control*>(depCon->type->to<IR::Type_Control>());
    auto nc = const_cast<IR::P4Control*>(depCon);

    auto depName = controlName+"_ingress_deparser";
    ntc->name.name = depName;
    nc->name.name = depName;
    return nc;
}


const IR::P4Control* ControlStateReconInfo::getParser(bool woVOPs) {

    const IR::P4Control* depCon = woVOPs ? deparserWoVOPs : deparser;

    cstring pn = controlName+"_egress_parser";
    DeparserInverter dpi(pn, headerTypeName, deparserHeaderTypeParamName);
    auto parser = depCon->apply(dpi)->clone();
    //std::cout<<"\n"<<parser<<"\n";
    return parser;
}

IR::Vector<IR::Argument>* ControlStateReconInfo::getDeparserArgs() {
    return deparserArgs->clone();
}

IR::Vector<IR::Argument>* ControlStateReconInfo::getParserArgs() {
    return deparserArgs->clone();
}

cstring ControlStateReconInfo::getHeaderInstName() {
    return headerParamName;
}




}// namespace CSA
