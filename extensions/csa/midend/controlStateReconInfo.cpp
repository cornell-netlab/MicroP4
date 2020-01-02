/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */
#include "controlStateReconInfo.h"
#include "deparserConverter.h"
#include "deparserInverter.h"
#include "cloneWithFreshPath.h"

namespace CSA {

const IR::P4Control* ControlStateReconInfo::getDeparser(bool woVOPs) {

    /*
    if (woVOPs)
        std::cout<<"Deparser without VOPs used for "<<controlName<<" ingress \n";
    */
    const IR::P4Control* depCon = woVOPs ? deparserWoVOPs : deparser;

    auto ntc = const_cast<IR::Type_Control*>(depCon->type->to<IR::Type_Control>());
    auto nc = const_cast<IR::P4Control*>(depCon);

    auto depName = controlName+"_ingress_deparser";
    ntc->name.name = depName;
    nc->name.name = depName;

    CloneWithFreshPath cp;
    auto nw  = nc->apply(cp)->to<IR::P4Control>();
    return nw;
}

const IR::P4Control* ControlStateReconInfo::getParser(bool woVOPs) {

    /*
    if (woVOPs)
        std::cout<<"Inverting deparser without VOPs for "<<controlName<<" egress \n";
    */
    const IR::P4Control* depCon = woVOPs ? deparserWoVOPs : deparser;

    cstring pn = controlName+"_egress_parser";
    DeparserInverter dpi(pn, headerTypeName, deparserHeaderTypeParamName);
    auto parser = depCon->apply(dpi)->clone();
    //std::cout<<"\n"<<parser<<"\n";
    return parser;
}

const IR::Vector<IR::Argument>* ControlStateReconInfo::getDeparserArgs() {
    CloneWithFreshPath cp;
    auto nw  = deparserArgs->apply(cp)->to<IR::Vector<IR::Argument>>();
    return nw;
}

const IR::Vector<IR::Argument>* ControlStateReconInfo::getParserArgs() {
    CloneWithFreshPath cp;
    auto nw  = deparserArgs->apply(cp)->to<IR::Vector<IR::Argument>>();
    return nw;
}

cstring ControlStateReconInfo::getHeaderInstName() {
    return headerParamName;
}

}// namespace CSA
