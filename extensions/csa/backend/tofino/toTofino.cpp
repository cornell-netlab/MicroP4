/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "frontends/p4/coreLibrary.h"
#include "frontends/p4/methodInstance.h"
#include "toTofino.h"
#include "replaceByteHdrStack.h"


namespace CSA {

const cstring CreateTofinoArchBlock::csaPacketStructInstanceName = "mpkt";
const cstring CreateTofinoArchBlock::metadataArgName = "msa_um";
const cstring CreateTofinoArchBlock::stdMetadataArgName = "msa_sm";
const cstring CreateTofinoArchBlock::userMetadataStructTypeName = "msa_user_metadata_t";

const cstring CreateTofinoArchBlock::ingressParserName = "msa_tofino_ig_parser";
const cstring CreateTofinoArchBlock::egressParserName = "msa_tofino_eg_parser";
const cstring CreateTofinoArchBlock::ingressDeparserName = "msa_tofino_ig_deparser";
const cstring CreateTofinoArchBlock::egressDeparserName = "msa_tofino_eg_deparser";

const cstring CreateTofinoArchBlock::ingressControlName = "msa_tofino_ig_control";
const cstring CreateTofinoArchBlock::egressControlName = "msa_tofino_eg_control";

const cstring CreateTofinoArchBlock::igIMTypeName = "ingress_intrinsic_metadata_t";
const cstring CreateTofinoArchBlock::igIMArgName = "ig_intr_md";

const cstring CreateTofinoArchBlock::igIMFrmParTypeName = "ingress_intrinsic_metadata_from_parser_t";
const cstring CreateTofinoArchBlock::igIMFrmParInstName = "ig_intr_md_from_prsr";

const cstring CreateTofinoArchBlock::igIMForDePTypeName = "ingress_intrinsic_metadata_for_deparser_t";
const cstring CreateTofinoArchBlock::igIMForDePInstName = "ig_intr_md_for_dprsr";

const cstring CreateTofinoArchBlock::igIMForTMTypeName = "ingress_intrinsic_metadata_for_tm_t";
const cstring CreateTofinoArchBlock::igIMForTMInstName = "ig_intr_md_for_tm";

const cstring CreateTofinoArchBlock::egIMTypeName = "egress_intrinsic_metadata_t";
const cstring CreateTofinoArchBlock::egIMArgName = "eg_intr_md";

const cstring CreateTofinoArchBlock::egIMFrmParTypeName = "egress_intrinsic_metadata_from_parser_t";
const cstring CreateTofinoArchBlock::egIMFrmParInstName = "eg_intr_md_from_prsr";

const cstring CreateTofinoArchBlock::egIMForDePTypeName = "egress_intrinsic_metadata_for_deparser_t";
const cstring CreateTofinoArchBlock::egIMForDePInstName = "eg_intr_md_for_dprsr";

const cstring CreateTofinoArchBlock::egIMForOPTypeName = "egress_intrinsic_metadata_for_output_port_t";
const cstring CreateTofinoArchBlock::egIMForOPInstName = "eg_intr_md_for_oport";




const std::unordered_set<cstring> TofinoConstants::archP4ControlNames = {
    CreateTofinoArchBlock::ingressDeparserName,
    CreateTofinoArchBlock::egressDeparserName,
    CreateTofinoArchBlock::ingressControlName,
    CreateTofinoArchBlock::egressControlName
};

bool GetCalleeP4Controls::preorder(const IR::P4Control* control) {
    visit(control->body);
    return false;
}

bool GetCalleeP4Controls::preorder(const IR::MethodCallStatement* mcs) {
    
    auto mi = P4::MethodInstance::resolve(mcs, refMap, typeMap);
    if (mi->isApply()) {
        auto a = mi->to<P4::ApplyMethod>();
        const IR::P4Control* p4Control = nullptr;
        if (auto di = a->object->to<IR::Declaration_Instance>()) {
            auto inst = P4::Instantiation::resolve(di, refMap, typeMap);
            if (auto ci = inst->to<P4::ControlInstantiation>()) {
                p4Control = ci->control;
                if (callees->getDeclaration(p4Control->name) == nullptr)
                    callees->push_back(p4Control);
                visit(p4Control);
            }
        }
    }
    return false;
}

const IR::Node* MSAStdMetaSubstituter::preorder(IR::P4Program* program) {

    auto ic = ToTofino::getControls(program, partitionsMap, partitions, true);
    auto ec = ToTofino::getControls(program, partitionsMap, partitions, false);
    for (auto c : ic) {
        GetCalleeP4Controls getCallees(refMap, typeMap, &ingressControls);
        c->apply(getCallees);
        ingressControls.push_back(c);
    }
    for (auto c : ec) {
        GetCalleeP4Controls getCallees(refMap, typeMap, &egressControls);
        c->apply(getCallees);
        egressControls.push_back(c);
    }

    return program;
}


const IR::Node* MSAStdMetaSubstituter::preorder(IR::P4Control* p4c) {
    if (ingressControls.getDeclaration(p4c->name) != nullptr)
        ingress = true;
    else if (egressControls.getDeclaration(p4c->name) != nullptr)
        ingress = false;
    return p4c;
}


const IR::Node* MSAStdMetaSubstituter::preorder(IR::Path* path) {
    return path;
}

const IR::Node* MSAStdMetaSubstituter::preorder(IR::Argument* arg) {
    auto type = typeMap->getType(arg->expression, true);
    if (auto te = type->to<IR::Type_Extern>()) {
        if (te->getName() == P4::P4CoreLibrary::instance.im.name) {
            IR::Vector<IR::Argument>* args = nullptr;
            if (ingress) 
                args =  CreateTofinoArchBlock::createIngressIMArgs();
            else
                args =  CreateTofinoArchBlock::createEgressIMArgs();
                
            prune();
            return args;
        }
    }
    return arg;
}

const IR::Node* MSAStdMetaSubstituter::preorder(IR::Parameter* param) {
    auto type = typeMap->getTypeType(param->type, true);
    if (auto te = type->to<IR::Type_Extern>()) {
        if (te->getName() == P4::P4CoreLibrary::instance.im.name) {
            IR::IndexedVector<IR::Parameter>* imParams = nullptr;
            if (ingress) 
                imParams = CreateTofinoArchBlock::createIngressIMParams();
            else
                imParams = CreateTofinoArchBlock::createEgressIMParams();
            prune();
            return imParams;
        }
    }
    prune();
    return param;
}

const IR::Node* MSAStdMetaSubstituter::preorder(IR::MethodCallStatement* mcs) {
    auto mi = P4::MethodInstance::resolve(mcs, refMap, typeMap);
    if (mi->is<P4::ExternMethod>()) {
        auto em = mi->to<P4::ExternMethod>();
        if (em->originalExternType->name.name != P4::P4CoreLibrary::instance.im.name)
            return mcs;
        IR::Expression* pathExp = nullptr;
        if (em->method->name.name == P4::P4CoreLibrary::instance.im.setOutPort.name){
            // std::cout<<"Method name :"<<em->method->name<<"\n";
            // std::cout<<"decl :"<<em->object<<"\n";
            BUG_CHECK(ingress, "Trying translate set_out_port for egress");
            auto exp = mcs->methodCall->arguments->at(0)->expression;
            pathExp = new IR::PathExpression(
                            IR::ID(CreateTofinoArchBlock::igIMForTMInstName));
            auto lexp = new IR::Member(pathExp, "ucast_egress_port");
            prune();
            return new IR::AssignmentStatement(mcs->srcInfo, lexp, exp);
        }
        if (em->method->name.name == "drop") {
            cstring instName = "";
            if (ingress)
                instName = CreateTofinoArchBlock::igIMForDePInstName;
            else
                instName = CreateTofinoArchBlock::egIMForDePInstName;

            pathExp = new IR::PathExpression(IR::ID(instName));
            auto lexp = new IR::Member(pathExp, "drop_ctl");
            auto constant =  new IR::Constant(1, 16);
            prune();
            return new IR::AssignmentStatement(mcs->srcInfo, lexp, constant);
        }

    }
    return mcs;
}

const IR::Node* MSAStdMetaSubstituter::preorder(IR::MethodCallExpression* mce) {

    auto mi = P4::MethodInstance::resolve(mce, refMap, typeMap);
    if (mi->is<P4::ExternMethod>()) {
        auto em = mi->to<P4::ExternMethod>();
        if (em->originalExternType->name.name != P4::P4CoreLibrary::instance.im.name)
            return mce;

        cstring memberName;
        cstring instName;
        if (em->method->name.name 
            == P4::P4CoreLibrary::instance.im.getOutPort.name) {
            if (ingress) {
                instName = CreateTofinoArchBlock::igIMForTMInstName;
                memberName = "ucast_egress_port";
            } else {
                instName = CreateTofinoArchBlock::egIMArgName;
                memberName = "egress_port";
            }
            IR::PathExpression* pe = new IR::PathExpression(IR::ID(instName));
            auto member = new IR::Member(mce->srcInfo, pe, memberName);
            prune();
            return member;
        }
        if (em->method->name.name 
            == P4::P4CoreLibrary::instance.im.getValue.name) {
            IR::Expression* pathExp = nullptr;
            auto exp = mce->arguments->at(0)->expression;
            auto mem = exp->to<IR::Member>();
            BUG_CHECK(mem != nullptr, "unable to identify arg %1%", exp);
            if (mem->member == "QUEUE_DEPTH_AT_DEQUEUE") {
                instName = CreateTofinoArchBlock::egIMArgName;
                pathExp = new IR::PathExpression(IR::ID(instName));
                auto m = new IR::Member(mce->srcInfo, pathExp, "deq_qdepth");
                auto tc = IR::Type_Bits::get(32, false);
                auto cm = new IR::Cast(tc, m);
                prune();
                return cm;
            }
        }
    }
    return mce;
}


IR::ParameterList* CreateTofinoArchBlock::getHeaderMetaPL(IR::Direction dirMSAPkt,
                                                          IR::Direction dirUserMeta) {
    auto pl = new IR::ParameterList();
    auto phdr = new IR::Parameter(IR::ID(csaPacketStructInstanceName), 
        dirMSAPkt, new IR::Type_Name(NameConstants::csaPacketStructTypeName));
    auto pum = new IR::Parameter(IR::ID(metadataArgName), 
        dirUserMeta, new IR::Type_Name(userMetadataStructTypeName));
    pl->push_back(phdr);
    pl->push_back(pum);
    return pl;
}

IR::Type_Struct* CreateTofinoArchBlock::createUserMetadataStructType() {
    auto fiv = new IR::IndexedVector<IR::StructField>();
    auto ts = new IR::Type_Struct(userMetadataStructTypeName, *fiv);
    return ts;
}

IR::P4Control* CreateTofinoArchBlock::createP4Control(cstring name,
                              IR::ParameterList* pl, IR::BlockStatement* bs) {
    auto tc = new IR::Type_Control(IR::ID(name), pl);
    auto p4c = new IR::P4Control(IR::ID(name), tc, bs);
    return p4c;
}

const IR::P4Parser* CreateTofinoArchBlock::createTofinoIngressParser() {

    cstring packetInArgName = "pin";
    cstring parseTwoBytesStateName = "parse_two_bytes_stack";
    cstring parseResidualByteStateName = "parse_residual";
    cstring parserCounterInstName = "pc";
    std::vector<std::pair<cstring, unsigned>> pcInstNameMaxPairVec;
    cstring parserCounterTypeName = "ParserCounter";

    std::vector<cstring> statesName;

    auto pl = getHeaderMetaPL(IR::Direction::Out, IR::Direction::Out);
    auto pin = new IR::Parameter(IR::ID(packetInArgName), 
        IR::Direction::None, new IR::Type_Name(P4::P4CoreLibrary::instance.packetIn.name));
    pl->parameters.insert(pl->parameters.begin(), pin);

    auto pigIM = new IR::Parameter(IR::ID(igIMArgName), 
        IR::Direction::Out, new IR::Type_Name(igIMTypeName));
    pl->parameters.push_back(pigIM);
    auto tp = new IR::Type_Parser(ingressParserName, pl);

    auto csaPktInstPE = new IR::PathExpression(csaPacketStructInstanceName);
    
    IR::IndexedVector<IR::Declaration> parserLocals;
    IR::IndexedVector<IR::ParserState> states;

    unsigned nc = 0;
    for (; nc<maxFullStToExct; nc++) {
        cstring pcInstName = parserCounterInstName+cstring::to_cstring(nc);
        pcInstNameMaxPairVec.emplace_back(pcInstName, stackSize);
    }
    if (maxHdrsToExctResSt > 0) {
        cstring pcInstName = parserCounterInstName+cstring::to_cstring(nc++);
        pcInstNameMaxPairVec.emplace_back(pcInstName, maxHdrsToExctResSt);
    }

    for (unsigned i = 0; i < nc; i++) {
        auto pcInstName = pcInstNameMaxPairVec[i].first;
        auto di = new IR::Declaration_Instance(pcInstName, 
            new IR::Type_Name(parserCounterTypeName), new IR::Vector<IR::Argument>());
        parserLocals.push_back(di);

        auto hdrStackInstName = ReplaceMSAByteHdrStack::getHdrStackInstName(i);
        statesName.push_back("parse_"+hdrStackInstName);
    }

    if (extctResidualByteHdr > 0) 
        statesName.push_back(parseResidualByteStateName);
    else 
        statesName.push_back(IR::ParserState::accept);

    // creating start state
    IR::IndexedVector<IR::StatOrDecl> components;
    for (unsigned i = 0; i<nc; i++) {
        auto pcInstName = pcInstNameMaxPairVec[i].first;
        auto counterValue = pcInstNameMaxPairVec[i].second;
        auto pcPE = new IR::PathExpression(pcInstName);
        auto setCounterM = new IR::Member(pcPE, "set");

        auto argPCPE = new IR::Vector<IR::Argument>();
        auto castType = IR::Type::Bits::get(8, false);
        auto cv = new IR::Constant(counterValue);
        auto carg = new IR::Argument(new IR::Cast(castType, cv));
        argPCPE->push_back(carg);
        auto mce = new IR::MethodCallExpression(setCounterM, argPCPE);
        auto setCounterMCS =  new IR::MethodCallStatement(mce);
        components.push_back(setCounterMCS);
    }
    auto startPE = new IR::PathExpression(statesName[0]);
    auto startState = new IR::ParserState(IR::ParserState::start, components, startPE);
    states.push_back(startState);
     
    
    cstring currStateName = "";
    cstring nextStateName = "";
    for (unsigned i = 0; i<nc; i++) {
        auto hdrStackInstName = ReplaceMSAByteHdrStack::getHdrStackInstName(i);
        currStateName = statesName[i];
        nextStateName = statesName[i+1];
        auto pcInstName = pcInstNameMaxPairVec[i].first;

        IR::IndexedVector<IR::StatOrDecl> components;

        auto pcPE = new IR::PathExpression(pcInstName);
        auto decrCtM = new IR::Member(pcPE, "decrement");
        auto argPCPE = new IR::Vector<IR::Argument>();
        auto carg = new IR::Argument(new IR::Constant(1));
        argPCPE->push_back(carg);
        auto mce = new IR::MethodCallExpression(decrCtM, argPCPE);
        auto decrCtMCS = new IR::MethodCallStatement(mce);
        components.push_back(decrCtMCS);

        auto em = new IR::Member(csaPktInstPE->clone(), hdrStackInstName);
        auto exArg = new IR::Argument(new IR::Member(em, "next"));
        auto exArgs = new IR::Vector<IR::Argument>();
        exArgs->push_back(exArg);
        auto extract = new IR::Member(new IR::PathExpression(packetInArgName),
            IR::ID(P4::P4CoreLibrary::instance.packetIn.extract.name));
        auto emptyTypeVec = new IR::Vector<IR::Type>(); 
        mce = new IR::MethodCallExpression(extract, emptyTypeVec, exArgs);
        auto mcs = new IR::MethodCallStatement(mce);
        components.push_back(mcs);

        IR::Vector<IR::Expression> ev;
        pcPE = new IR::PathExpression(pcInstName);
        auto isZeroM = new IR::Member(pcPE, "is_zero");
        auto cond = new IR::MethodCallExpression(isZeroM);
        ev.push_back(cond);
        auto ls = new IR::ListExpression(ev);
        auto selectCases = new IR::Vector<IR::SelectCase>();
        auto scf = new IR::SelectCase(new IR::BoolLiteral(false), 
            new IR::PathExpression(currStateName));
        auto sct = new IR::SelectCase(new IR::BoolLiteral(true), 
            new IR::PathExpression(nextStateName));
        selectCases->push_back(scf);
        selectCases->push_back(sct);
        auto se = new IR::SelectExpression(ls, *selectCases);
        auto ps = new IR::ParserState(currStateName, components, se);
        states.push_back(ps);
    }   

    if (extctResidualByteHdr > 0) {
        IR::IndexedVector<IR::StatOrDecl> components;
        auto em = new IR::Member(csaPktInstPE->clone(), 
                                 NameConstants::msaOneByteHdrInstName);
        auto exArgs = new IR::Vector<IR::Argument>();
        exArgs->push_back(new IR::Argument(em));
        auto extract = new IR::Member(new IR::PathExpression(packetInArgName),
            IR::ID(P4::P4CoreLibrary::instance.packetIn.extract.name));
        auto mce = new IR::MethodCallExpression(extract, exArgs);
        auto mcs = new IR::MethodCallStatement(mce);
        components.push_back(mcs);
        auto pe = new IR::PathExpression(IR::ParserState::accept);
        auto ps = new IR::ParserState(nextStateName, components, pe);
        states.push_back(ps);
    }

    states.push_back(new IR::ParserState(IR::ParserState::accept, nullptr));

    return new IR::P4Parser(ingressParserName, tp, parserLocals, states);
}


const IR::P4Control* CreateTofinoArchBlock::createTofinoIngressDeparser() {
    cstring packetOutArgName = "po";
    auto pl = getHeaderMetaPL(IR::Direction::InOut, IR::Direction::In);
    auto po = new IR::Parameter(IR::ID(packetOutArgName), 
        IR::Direction::None, new IR::Type_Name(P4::P4CoreLibrary::instance.packetOut.name));

    auto pIgIMForDeP = new IR::Parameter(IR::ID(igIMForDePInstName), 
        IR::Direction::In, new IR::Type_Name(igIMForDePTypeName));
    pl->parameters.insert(pl->parameters.begin(),  po);
    pl->push_back(pIgIMForDeP);

    std::vector<cstring> hdrInsts;
    unsigned i = 0;
    for (; i < maxFullStToExct; i++)
        hdrInsts.push_back(ReplaceMSAByteHdrStack::getHdrStackInstName(i));
    if (*residualStackSize > 0)
        hdrInsts.push_back(ReplaceMSAByteHdrStack::getHdrStackInstName(i));
    
    hdrInsts.push_back(NameConstants::msaOneByteHdrInstName);

    auto csaPktInstPE = new IR::PathExpression(csaPacketStructInstanceName);
    auto bs = new IR::BlockStatement();
    for (auto hdrIns : hdrInsts) {
        auto argExp = new IR::Member(csaPktInstPE->clone(), IR::ID(hdrIns));
        auto args = new IR::Vector<IR::Argument>();
        auto arg = new IR::Argument(argExp);
        args->push_back(arg);
        auto member = new IR::Member(new IR::PathExpression(packetOutArgName),
            IR::ID(P4::P4CoreLibrary::instance.packetOut.emit.name));
        auto emptyTypeVec = new IR::Vector<IR::Type>(); 
        auto mce = new IR::MethodCallExpression(member, emptyTypeVec, args);
        auto mcs = new IR::MethodCallStatement(mce);
        bs->push_back(mcs);
    }

    return createP4Control(ingressDeparserName, pl, bs);
}


std::vector<const IR::P4Control*> ToTofino::getControls(const IR::P4Program* prog, 
                                  const P4ControlPartitionInfoMap* partitionsMap, 
                          const std::vector<cstring>* partitions, bool ingress) {
  
    std::vector<const IR::P4Control*> controls;
    if (partitions->size() == 1) {
        auto it = partitionsMap->find((*partitions)[0]);
        BUG_CHECK(it != partitionsMap->end(), "P4Control partition not found");
        auto pi = it->second;
        auto cv = prog->getDeclsByName(pi.partition1->getName())->toVector();
        BUG_CHECK(cv->size() == 1, "expected one P4Control with name %1%", 
                                   pi.partition1->getName());
        auto p4c = cv->at(0)->to<IR::P4Control>();
        controls.push_back(p4c);
        return controls;

    }

    unsigned i = 0;
    if (!ingress) {
       i = 1;
    }
    /*
    std::cout<<"Partition Map size: "<<partitionsMap->size()<<"\n";
    std::cout<<"Total Partitions: "<<partitions->size()<<"\n";
    */
    for (; i<partitions->size(); i = i+2) {
        if (i == partitions->size()-1) {
            auto it = partitionsMap->find((*partitions)[i-1]);
            BUG_CHECK(it != partitionsMap->end(), "P4Control partition not found");
            auto pi = it->second;

            // std::cout<<"Name : "<<pi.partition2->getName()<<"\n";
            auto cv = prog->getDeclsByName(pi.partition2->getName())->toVector();
            BUG_CHECK(cv->size() == 1, "expected one P4Control with name %1%", 
                                       pi.partition2->getName());
            auto p4c = cv->at(0)->to<IR::P4Control>();
            controls.push_back(p4c);

        } else {
            auto it = partitionsMap->find((*partitions)[i]);
            BUG_CHECK(it != partitionsMap->end(), "P4Control partition not found");
            auto pi = it->second;
         
            // std::cout<<"Name : "<<pi.partition1->getName()<<"\n";
            auto cv = prog->getDeclsByName(pi.partition1->getName())->toVector();
            BUG_CHECK(cv->size() == 1, "expected one P4Control with name %1%", 
                                       pi.partition1->getName());
            auto p4c = cv->at(0)->to<IR::P4Control>();
            controls.push_back(p4c);
        }

    }
    return controls;
}


IR::IndexedVector<IR::Parameter>* CreateTofinoArchBlock::createIngressIMParams() {
  
    auto parameters = new IR::IndexedVector<IR::Parameter>();
    auto p = new IR::Parameter(IR::ID(igIMArgName), IR::Direction::In, 
                                  new IR::Type_Name(igIMTypeName));
    parameters->push_back(p);
    p = new IR::Parameter(IR::ID(igIMFrmParInstName), IR::Direction::In, 
                                  new IR::Type_Name(igIMFrmParTypeName));
    parameters->push_back(p);
    p = new IR::Parameter(IR::ID(igIMForDePInstName), IR::Direction::InOut, 
                                  new IR::Type_Name(igIMForDePTypeName));
    parameters->push_back(p);
    p = new IR::Parameter(IR::ID(igIMForTMInstName), IR::Direction::InOut, 
                                  new IR::Type_Name(igIMForTMTypeName));
    parameters->push_back(p);
    return parameters;
}

IR::Vector<IR::Argument>* CreateTofinoArchBlock::createIngressIMArgs() {
    std::vector<cstring> argNames;
    auto args =  new IR::Vector<IR::Argument>();
    argNames.push_back(igIMArgName);
    argNames.push_back(igIMFrmParInstName);
    argNames.push_back(igIMForDePInstName);
    argNames.push_back(igIMForTMInstName);
    for (auto an : argNames) {
      auto arg = new IR::Argument(new IR::PathExpression(an));
      args->push_back(arg);
    }
    return args;
}


const IR::Type_Control* CreateTofinoArchBlock::createIngressTypeControl() {
    
    auto pl = getHeaderMetaPL(IR::Direction::InOut, IR::Direction::InOut);
    auto imParams = createIngressIMParams();
    for (auto p : *(imParams))
        pl->parameters.push_back(p);
    return new IR::Type_Control(IR::ID(ingressControlName), pl);
}

const IR::Node* CreateTofinoArchBlock::createIngressP4Control(
    std::vector<const IR::P4Control*>& p4Controls, IR::Type_Struct*  typeStruct) {

    auto tc =  CreateTofinoArchBlock::createIngressTypeControl();
    IR::IndexedVector<IR::Declaration> cls;
    auto bs  = new IR::BlockStatement();

    for (auto c : p4Controls) {
      // Every control should go in if-cond, if we are wrapping around pipeline
      // using resubmit and all.
        auto controlArgs = new IR::Vector<IR::Argument>();
        auto params = c->getApplyParameters()->parameters;
        for (auto p : params) {
            auto type = typeMap->getTypeType(p->type, true);
            auto ts = type->to<IR::Type_Struct>();
            const IR::Type* fieldType = nullptr;
            if (ts != nullptr) {
                auto tsn = ts->name;
                if (tsn == NameConstants::csaPacketStructTypeName) {
                    auto pe = new IR::PathExpression(csaPacketStructInstanceName);
                    auto arg = new IR::Argument(pe);
                    controlArgs->push_back(arg);
                    continue;
                } else if (tsn == igIMFrmParTypeName 
                    || tsn == igIMForDePTypeName || tsn == igIMForTMTypeName) {
                    auto pe = new IR::PathExpression(new IR::Path(p->name));
                    auto arg = new IR::Argument(pe);
                    controlArgs->push_back(arg);
                    continue;
                }
                fieldType = new IR::Type_Name(ts->getName());
            } else if (auto th = type->to<IR::Type_Header>()) {
                if (th->name == igIMTypeName) {
                    auto pe = new IR::PathExpression(igIMArgName);
                    auto arg = new IR::Argument(pe);
                    controlArgs->push_back(arg);
                    continue;
                }
            } else if (type->is<IR::Type_Base>()) {
                fieldType = p->type;
            } 
            auto itbool = metadataFields.emplace(p->getName());
            if (itbool.second) {
                /*
                std::cout<<"is type name :"<<p->type->is<IR::Type_Name>()<<"\n";
                std::cout<<p->type<<"\n"<<p->getName()<<"\n";
                */
                auto f = new IR::StructField(p->getName(), fieldType);
                typeStruct->fields.push_back(f);
            }
            auto pe = new IR::PathExpression(metadataArgName);
            auto mem = new IR::Member(pe, p->getName());
            auto arg = new IR::Argument(mem);
            controlArgs->push_back(arg);
        }

        auto di = new IR::Declaration_Instance(IR::ID(c->getName()+"_inst"), 
            new IR::Type_Name(c->getName()), new IR::Vector<IR::Argument>());
        cls.push_back(di);

        auto m = new IR::Member(new IR::PathExpression(di->getName()), 
                                IR::ID("apply"));
        auto mce = new IR::MethodCallExpression(m, controlArgs); 
        auto mcs =new IR::MethodCallStatement(mce);
        bs->push_back(mcs);

    }

    auto ic = new IR::P4Control(IR::ID(ingressControlName), tc, cls, bs);
    return ic;
}

IR::IndexedVector<IR::Parameter>* CreateTofinoArchBlock::createEgressIMParams() {
  
    auto parameters = new IR::IndexedVector<IR::Parameter>();
    auto p = new IR::Parameter(IR::ID(egIMArgName), IR::Direction::In, 
                                  new IR::Type_Name(egIMTypeName));
    parameters->push_back(p);
    p = new IR::Parameter(IR::ID(egIMFrmParInstName), IR::Direction::In, 
                                  new IR::Type_Name(egIMFrmParTypeName));
    parameters->push_back(p);
    p = new IR::Parameter(IR::ID(egIMForDePInstName), IR::Direction::InOut, 
                                  new IR::Type_Name(egIMForDePTypeName));
    parameters->push_back(p);
    p = new IR::Parameter(IR::ID(egIMForOPInstName), IR::Direction::InOut, 
                                  new IR::Type_Name(egIMForOPTypeName));
    parameters->push_back(p);
    return parameters;
}

IR::Vector<IR::Argument>* CreateTofinoArchBlock::createEgressIMArgs() {
    std::vector<cstring> argNames;
    auto args =  new IR::Vector<IR::Argument>();
    argNames.push_back(egIMArgName);
    argNames.push_back(egIMFrmParInstName);
    argNames.push_back(egIMForDePInstName);
    argNames.push_back(egIMForOPInstName);
    for (auto an : argNames) {
      auto arg = new IR::Argument(new IR::PathExpression(an));
      args->push_back(arg);
    }
    return args;
}


const IR::Type_Control* CreateTofinoArchBlock::createEgressTypeControl() {
    
    auto pl = getHeaderMetaPL(IR::Direction::InOut, IR::Direction::InOut);
    auto imParams = createEgressIMParams();
    for (auto p : *(imParams)) 
        pl->parameters.push_back(p);
    return new IR::Type_Control(IR::ID(egressControlName), pl);
}

const IR::Node* CreateTofinoArchBlock::createEgressP4Control(
    std::vector<const IR::P4Control*>& p4Controls, IR::Type_Struct*  typeStruct) {

    auto tc =  CreateTofinoArchBlock::createEgressTypeControl();
    IR::IndexedVector<IR::Declaration> cls;
    auto bs  = new IR::BlockStatement();

    for (auto c : p4Controls) {
        auto controlArgs = new IR::Vector<IR::Argument>();
        auto params = c->getApplyParameters()->parameters;
        for (auto p : params) {
            auto type = typeMap->getTypeType(p->type, true);
            auto ts = type->to<IR::Type_Struct>();
            const IR::Type* fieldType = nullptr;
            if (ts != nullptr) {
                auto tsn = ts->name;
                if (tsn == NameConstants::csaPacketStructTypeName) {
                    auto pe = new IR::PathExpression(csaPacketStructInstanceName);
                    auto arg = new IR::Argument(pe);
                    controlArgs->push_back(arg);
                    continue;
                } else if (tsn == egIMTypeName || tsn == egIMFrmParTypeName 
                    || tsn == egIMForDePTypeName || tsn == egIMForOPTypeName) {
                    auto pe = new IR::PathExpression(p->name);
                    auto arg = new IR::Argument(pe);
                    controlArgs->push_back(arg);
                    continue;
                }
                fieldType = new IR::Type_Name(ts->getName());
            } else if (auto th = type->to<IR::Type_Header>()) {
                if (th->name == egIMTypeName) {
                    auto pe = new IR::PathExpression(Util::SourceInfo(), 
                        new IR::Path(p->name));
                    auto arg = new IR::Argument(pe);
                    controlArgs->push_back(arg);
                    continue;
                }
            } else if (type->is<IR::Type_Base>()) {
                fieldType = p->type;
            } 
            auto itbool = metadataFields.emplace(p->getName());
            if (itbool.second) {
                auto f = new IR::StructField(p->getName(), fieldType);
                typeStruct->fields.push_back(f);
            }
            auto pe = new IR::PathExpression(metadataArgName);
            auto mem = new IR::Member(pe, p->getName());
            auto arg = new IR::Argument(mem);
            controlArgs->push_back(arg);
        }
        auto di = new IR::Declaration_Instance(IR::ID(c->getName()+"_inst"), 
            new IR::Type_Name(c->getName()), new IR::Vector<IR::Argument>());
        cls.push_back(di);
        auto m = new IR::Member(new IR::PathExpression(di->getName()), 
                                IR::ID("apply"));
        auto mce = new IR::MethodCallExpression(m, controlArgs); 
        auto mcs =new IR::MethodCallStatement(mce);
        bs->push_back(mcs);

    }
    auto ec = new IR::P4Control(IR::ID(egressControlName), tc, cls, bs);
    return ec;
}


const IR::Node* CreateTofinoArchBlock::createTofinoEgressParser() {

    cstring packetInArgName = "pin";
    cstring parseTwoBytesStateName = "parse_two_bytes";
    cstring parseResidualByteStateName = "parse_residual";
    cstring parserCounterInstName = "pc";
    std::vector<std::pair<cstring, unsigned>> pcInstNameMaxPairVec;
    cstring parserCounterTypeName = "ParserCounter";

    std::vector<cstring> statesName;

    auto pl = getHeaderMetaPL(IR::Direction::Out, IR::Direction::Out);
    auto pin = new IR::Parameter(IR::ID(packetInArgName), 
        IR::Direction::None, new IR::Type_Name(P4::P4CoreLibrary::instance.packetIn.name));
    pl->parameters.insert(pl->parameters.begin(), pin);

    auto pigIM = new IR::Parameter(IR::ID(egIMArgName), 
        IR::Direction::Out, new IR::Type_Name(egIMTypeName));
    pl->parameters.push_back(pigIM);
    auto tp = new IR::Type_Parser(egressParserName, pl);

    auto csaPktInstPE = new IR::PathExpression(csaPacketStructInstanceName);
    
    IR::IndexedVector<IR::Declaration> parserLocals;
    IR::IndexedVector<IR::ParserState> states;

    unsigned nc = 0;
    for (; nc<maxFullStToExct; nc++) {
        cstring pcInstName = parserCounterInstName+cstring::to_cstring(nc);
        pcInstNameMaxPairVec.emplace_back(pcInstName, stackSize);
    }
    if (maxHdrsToExctResSt > 0) {
        cstring pcInstName = parserCounterInstName+cstring::to_cstring(nc++);
        pcInstNameMaxPairVec.emplace_back(pcInstName, maxHdrsToExctResSt);
    }

    for (unsigned i = 0; i < nc; i++) {
        auto pcInstName = pcInstNameMaxPairVec[i].first;
        auto di = new IR::Declaration_Instance(pcInstName, 
            new IR::Type_Name(parserCounterTypeName), new IR::Vector<IR::Argument>());
        parserLocals.push_back(di);

        auto hdrStackInstName = ReplaceMSAByteHdrStack::getHdrStackInstName(i);
        statesName.push_back("parse_"+hdrStackInstName);
    }

    if (extctResidualByteHdr > 0) 
        statesName.push_back(parseResidualByteStateName);
    else 
        statesName.push_back(IR::ParserState::accept);
    // creating start state
    IR::IndexedVector<IR::StatOrDecl> components;
    for (unsigned i = 0; i<nc; i++) {
        auto pcInstName = pcInstNameMaxPairVec[i].first;
        auto counterValue = pcInstNameMaxPairVec[i].second;
        auto pcPE = new IR::PathExpression(pcInstName);
        auto setCounterM = new IR::Member(pcPE, "set");
        auto argPCPE = new IR::Vector<IR::Argument>();
        auto castType = IR::Type::Bits::get(8, false);
        auto cv = new IR::Constant(counterValue);
        auto carg = new IR::Argument(new IR::Cast(castType, cv));
        argPCPE->push_back(carg);
        auto mce = new IR::MethodCallExpression(setCounterM, argPCPE);
        auto setCounterMCS =  new IR::MethodCallStatement(mce);
        components.push_back(setCounterMCS);
    }
    auto startPE = new IR::PathExpression(statesName[0]);
    auto startState = new IR::ParserState(IR::ParserState::start, components, startPE);
    states.push_back(startState);
     
    
    cstring currStateName = "";
    cstring nextStateName = "";
    for (unsigned i = 0; i<nc; i++) {
        auto hdrStackInstName = ReplaceMSAByteHdrStack::getHdrStackInstName(i);
        currStateName = statesName[i];
        nextStateName = statesName[i+1];
        auto pcInstName = pcInstNameMaxPairVec[i].first;
      
        IR::IndexedVector<IR::StatOrDecl> components;

        auto pcPE = new IR::PathExpression(pcInstName);
        auto decrCtM = new IR::Member(pcPE, "decrement");
        auto argPCPE = new IR::Vector<IR::Argument>();
        auto carg = new IR::Argument(new IR::Constant(1));
        argPCPE->push_back(carg);
        auto mce = new IR::MethodCallExpression(decrCtM, argPCPE);
        auto decrCtMCS = new IR::MethodCallStatement(mce);
        components.push_back(decrCtMCS);

        auto em = new IR::Member(csaPktInstPE->clone(), hdrStackInstName);
        auto exArg = new IR::Argument(new IR::Member(em, "next"));
        auto exArgs = new IR::Vector<IR::Argument>();
        exArgs->push_back(exArg);
        auto extract = new IR::Member(new IR::PathExpression(packetInArgName),
            IR::ID(P4::P4CoreLibrary::instance.packetIn.extract.name));
        auto emptyTypeVec = new IR::Vector<IR::Type>(); 
        mce = new IR::MethodCallExpression(extract, emptyTypeVec, exArgs);
        auto mcs = new IR::MethodCallStatement(mce);
        components.push_back(mcs);

        IR::Vector<IR::Expression> ev;
        pcPE = new IR::PathExpression(pcInstName);
        auto isZeroM = new IR::Member(pcPE, "is_zero");
        auto cond = new IR::MethodCallExpression(isZeroM);
        ev.push_back(cond);
        auto ls = new IR::ListExpression(ev);
        auto selectCases = new IR::Vector<IR::SelectCase>();
        auto scf = new IR::SelectCase(new IR::BoolLiteral(false), 
            new IR::PathExpression(currStateName));
        auto sct = new IR::SelectCase(new IR::BoolLiteral(true), 
            new IR::PathExpression(nextStateName));
        selectCases->push_back(scf);
        selectCases->push_back(sct);
        auto se = new IR::SelectExpression(ls, *selectCases);
        auto ps = new IR::ParserState(currStateName, components, se);
        states.push_back(ps);
    }   

    if (extctResidualByteHdr > 0) {
        IR::IndexedVector<IR::StatOrDecl> components;
        auto em = new IR::Member(csaPktInstPE->clone(), 
                                 NameConstants::msaOneByteHdrInstName);
        auto exArgs = new IR::Vector<IR::Argument>();
        exArgs->push_back(new IR::Argument(em));
        auto extract = new IR::Member(new IR::PathExpression(packetInArgName),
            IR::ID(P4::P4CoreLibrary::instance.packetIn.extract.name));
        auto mce = new IR::MethodCallExpression(extract, exArgs);
        auto mcs = new IR::MethodCallStatement(mce);
        components.push_back(mcs);
        auto pe = new IR::PathExpression(IR::ParserState::accept);
        auto ps = new IR::ParserState(nextStateName, components, pe);
        states.push_back(ps);
    }

    states.push_back(new IR::ParserState(IR::ParserState::accept, nullptr));

    return new IR::P4Parser(egressParserName, tp, parserLocals, states);
}

const IR::Node* CreateTofinoArchBlock::createTofinoEgressDeparser() {
    cstring packetOutArgName = "pkt_out";
    auto pl = getHeaderMetaPL(IR::Direction::InOut, IR::Direction::In);
    auto po = new IR::Parameter(IR::ID(packetOutArgName), 
        IR::Direction::None, new IR::Type_Name(P4::P4CoreLibrary::instance.packetOut.name));

    auto pIgIMForDeP = new IR::Parameter(IR::ID(egIMForDePInstName), 
        IR::Direction::In, new IR::Type_Name(egIMForDePTypeName));
    pl->parameters.insert(pl->parameters.begin(),  po);
    pl->push_back(pIgIMForDeP);

    std::vector<cstring> hdrInsts;
    unsigned i = 0;
    for (; i < maxFullStToExct; i++)
        hdrInsts.push_back(ReplaceMSAByteHdrStack::getHdrStackInstName(i));
    if (*residualStackSize > 0)
        hdrInsts.push_back(ReplaceMSAByteHdrStack::getHdrStackInstName(i));
    
    hdrInsts.push_back(NameConstants::msaOneByteHdrInstName);
    auto csaPktInstPE = new IR::PathExpression(csaPacketStructInstanceName);
    auto bs = new IR::BlockStatement();
    for (auto hdrIns : hdrInsts) {
        auto argExp = new IR::Member(csaPktInstPE->clone(), IR::ID(hdrIns));
        auto args = new IR::Vector<IR::Argument>();
        auto arg = new IR::Argument(argExp);
        args->push_back(arg);
        auto member = new IR::Member(new IR::PathExpression(packetOutArgName),
            IR::ID(P4::P4CoreLibrary::instance.packetOut.emit.name));
        auto emptyTypeVec = new IR::Vector<IR::Type>(); 
        auto mce = new IR::MethodCallExpression(member, emptyTypeVec, args);
        auto mcs = new IR::MethodCallStatement(mce);
        bs->push_back(mcs);
    }
    return createP4Control(egressDeparserName, pl, bs);
}

IR::Vector<IR::Node> CreateTofinoArchBlock::createMainPackageInstance() {
    auto args = new IR::Vector<IR::Argument>();
    auto eva = new IR::Vector<IR::Argument>();

    auto tnip = new IR::Type_Name(ingressParserName);
    auto ptnip = new IR::Argument(new IR::ConstructorCallExpression(tnip, eva));
    args->push_back(ptnip);

    auto tnic = new IR::Type_Name(ingressControlName);
    auto ptnic = new IR::Argument(new IR::ConstructorCallExpression(tnic, eva->clone()));
    args->push_back(ptnic);

    auto tndip = new IR::Type_Name(ingressDeparserName);
    auto ptndip = new IR::Argument(new IR::ConstructorCallExpression(tndip, eva->clone()));
    args->push_back(ptndip);

    auto tnep = new IR::Type_Name(egressParserName);
    auto ptnep = new IR::Argument(new IR::ConstructorCallExpression(tnep, eva->clone()));
    args->push_back(ptnep);

    auto tnec = new IR::Type_Name(egressControlName);
    auto ptnec = new IR::Argument(new IR::ConstructorCallExpression(tnec, eva->clone()));
    args->push_back(ptnec);
  
    auto tndep = new IR::Type_Name(egressDeparserName);
    auto ptndep = new IR::Argument(new IR::ConstructorCallExpression(tndep, eva->clone()));
    args->push_back(ptndep);

    cstring pipe = "pipe";
    auto tnpipeline =  new IR::Type_Name("Pipeline");
    auto dl = new IR::Declaration_Instance(pipe, tnpipeline, args);

    auto ma = new IR::Vector<IR::Argument>();
    ma->push_back(new IR::Argument(new IR::PathExpression(pipe)));
    auto mainType = new IR::Type_Name("Switch");
    auto mdl = new IR::Declaration_Instance(IR::P4Program::main, mainType, ma);

    IR::Vector<IR::Node> nodes;
    nodes.push_back(dl);
    nodes.push_back(mdl);
    return nodes;
}


const IR::Node* CreateTofinoArchBlock::preorder(IR::P4Program* p4program) {

    unsigned maxExtHdr = (*maxExtLen)/(hdrBitWidth);
    unsigned minExtHdr = (*minExtLen)/(hdrBitWidth);

    maxFullStToExct = maxExtHdr / (stackSize);
    maxHdrsToExctResSt = maxExtHdr % (stackSize);
    extctResidualByteHdr = (*maxExtLen) % (hdrBitWidth);

    auto userMetaStruct = createUserMetadataStructType();
    p4program->objects.push_back(userMetaStruct);

    //ingress
    auto ip = createTofinoIngressParser();
    p4program->objects.push_back(ip);

    auto ingressControls = ToTofino::getControls(p4program, partitionsMap, partitions, true);
    auto ic = createIngressP4Control(ingressControls, userMetaStruct);
    p4program->objects.push_back(ic);

    auto idp = createTofinoIngressDeparser();
    p4program->objects.push_back(idp);

    //egress
    p4program->objects.push_back(createTofinoEgressParser());

    std::vector<const IR::P4Control*> egressControls;
    if (partitions->size() > 1)
        egressControls = ToTofino::getControls(p4program, partitionsMap, partitions, false);
    auto ec = createEgressP4Control(egressControls, userMetaStruct);
    p4program->objects.push_back(ec);

    p4program->objects.push_back(createTofinoEgressDeparser());

    p4program->objects.append(createMainPackageInstance());

    return p4program;

}


}// namespace CSA
