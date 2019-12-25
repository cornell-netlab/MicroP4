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
                callees->push_back(p4Control);
                visit(p4Control);
            }
        }
    }
    return false;
}


const IR::Node* MSAStdMetaSubstituter::preorder(IR::Path* path) {
    return path;
}

const IR::Node* MSAStdMetaSubstituter::preorder(IR::Argument* arg) {
    auto type = typeMap->getType(arg->expression, true);
    if (auto te = type->to<IR::Type_Extern>()) {
        if (te->getName() == P4::P4CoreLibrary::instance.im.name) {
            auto args = CreateTofinoArchBlock::createIngressIMArgs();
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
            prune();
            auto imParams = CreateTofinoArchBlock::createIngressIMParams();
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
            auto exp = mcs->methodCall->arguments->at(0)->expression;
            pathExp = new IR::PathExpression(
                            IR::ID(CreateTofinoArchBlock::igIMForTMInstName));
            auto lexp = new IR::Member(pathExp, "ucast_egress_port");
            prune();
            return new IR::AssignmentStatement(mcs->srcInfo, lexp, exp);
        }
        if (em->method->name.name == "drop") {
            pathExp = new IR::PathExpression(
                            IR::ID(CreateTofinoArchBlock::igIMForDePInstName));
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

        if (em->method->name.name 
            == P4::P4CoreLibrary::instance.im.getOutPort.name) {
            IR::PathExpression* pe = new IR::PathExpression(
                IR::ID(CreateTofinoArchBlock::igIMForTMInstName));
            cstring memberName = "ucast_egress_port"; // "egress_port"
            auto member = new IR::Member(mce->srcInfo, pe, memberName);
            prune();
            return member;
        }
        if (em->method->name.name 
            == P4::P4CoreLibrary::instance.im.getValue.name) {
            IR::Expression* pathExp = nullptr;
            pathExp = new IR::PathExpression(
                            IR::ID(CreateTofinoArchBlock::egIMArgName));
            auto exp = mce->arguments->at(0)->expression;
            auto mem = exp->to<IR::Member>();
            BUG_CHECK(mem != nullptr, "unable to identify arg %1%", exp);
            if (mem->member == "QUEUE_DEPTH_AT_DEQUEUE") {
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

const IR::Node* CreateTofinoArchBlock::createTofinoIngressParser() {

    cstring packetInArgName = "pin";
    cstring parseTwoBytesStateName = "parse_two_bytes";
    cstring parseResidualByteStateName = "parse_residual";
    cstring parserCounterInstName = "pc";
    std::vector<std::pair<cstring, unsigned>> pcInstNameMaxPairVec;
    cstring parserCounterTypeName = "ParserCounter";


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
    }


    
    // creating start state
    IR::IndexedVector<IR::StatOrDecl> components;
    for (unsigned i = 0; i<nc; i++) {
        auto pcInstName = pcInstNameMaxPairVec[i].first;
        auto counterValue = pcInstNameMaxPairVec[i].second;
        auto pcPE = new IR::PathExpression(pcInstName);
        auto setCounterM = new IR::Member(pcPE, "set");
        auto argPCPE = new IR::Vector<IR::Argument>();
        auto carg = new IR::Argument(new IR::Constant(counterValue));
        argPCPE->push_back(carg);
        auto mce = new IR::MethodCallExpression(setCounterM, argPCPE);
        auto setCounterMCS =  new IR::MethodCallStatement(mce);
        components.push_back(setCounterMCS);
    }
    auto startPE = new IR::PathExpression(parseTwoBytesStateName);
    auto startState = new IR::ParserState(IR::ParserState::start, components, startPE);
    states.push_back(startState);
     
    
    cstring currStateName = "";
    cstring nextStateName = "";
    for (unsigned i = 0; i<nc; i++) {
        auto hdrStackInstName = ReplaceMSAByteHdrStack::getHdrStackInstName(i);
        currStateName = "parse_"+hdrStackInstName;
        auto pcInstName = pcInstNameMaxPairVec[i].first;
      
        if (i == nc-1) {
            if (extctResidualByteHdr > 0) 
                nextStateName = parseResidualByteStateName;
            else 
                nextStateName = IR::ParserState::accept;
        } else {
            nextStateName = "parse_"+ ReplaceMSAByteHdrStack::getHdrStackInstName(i+1);
        }

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
        pcPE = new IR::PathExpression(parserCounterInstName);
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


const IR::Node* CreateTofinoArchBlock::createTofinoIngressDeparser() {
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


std::vector<const IR::P4Control*>
CreateTofinoArchBlock::getControls(const IR::P4Program* prog, bool ingress) {
  
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
    std::cout<<"Partition Map size: "<<partitionsMap->size()<<"\n";
    std::cout<<"Total Partitions: "<<partitions->size()<<"\n";
    for (; i<partitions->size(); i = i+2) {
        if (i == partitions->size()-1) {
            auto it = partitionsMap->find((*partitions)[i-1]);
            BUG_CHECK(it != partitionsMap->end(), "P4Control partition not found");
            auto pi = it->second;

            std::cout<<"Name : "<<pi.partition2->getName()<<"\n";
            auto cv = prog->getDeclsByName(pi.partition2->getName())->toVector();
            BUG_CHECK(cv->size() == 1, "expected one P4Control with name %1%", 
                                       pi.partition2->getName());
            auto p4c = cv->at(0)->to<IR::P4Control>();
            controls.push_back(p4c);

        } else {
            auto it = partitionsMap->find((*partitions)[i]);
            BUG_CHECK(it != partitionsMap->end(), "P4Control partition not found");
            auto pi = it->second;
         
            std::cout<<"Name : "<<pi.partition1->getName()<<"\n";
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

    p = new IR::Parameter(IR::ID(igIMForTMTypeName), IR::Direction::InOut, 
                                  new IR::Type_Name(igIMForTMInstName));
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
    pl->parameters.pushBackOrAppend(imParams);
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
                if (ts->getName() == NameConstants::csaPacketStructTypeName) {
                    auto pe = new IR::PathExpression(csaPacketStructInstanceName);
                    auto arg = new IR::Argument(pe);
                    controlArgs->push_back(arg);
                    continue;
                }
                fieldType = new IR::Type_Name(ts->getName());
            } else if (type->is<IR::Type_Base>()) {
                fieldType = p->type;
            } else if (type->is<IR::Type_Extern>()) {
                auto te = type->to<IR::Type_Extern>();
                BUG_CHECK(te->getName() == P4::P4CoreLibrary::instance.im.name,
                    "unexpected extern in controls for ingress block");
                std::vector<cstring> argNames;
                argNames.push_back(igIMArgName);
                argNames.push_back(igIMFrmParInstName);
                argNames.push_back(igIMForDePInstName);
                argNames.push_back(igIMForTMInstName);
                for (auto an : argNames) {
                    auto arg = new IR::Argument(new IR::PathExpression(an));
                    controlArgs->push_back(arg);
                }
                continue;
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

        IR::IndexedVector<IR::Type_Declaration> callees;
        GetCalleeP4Controls getCallees(refMap, typeMap, &callees);
        c->apply(getCallees);
        callees.push_back(c);

        for (auto con : callees) {
            MSAStdMetaSubstituter msStdMetaSubstituter(refMap, typeMap);
            auto control = con->to<IR::P4Control>()->apply(msStdMetaSubstituter);
            // std::cout<<"Type_Control : \n"<<control->type<<"\n";
            updateP4Controls.push_back(control);
        }
    }

    auto ic = new IR::P4Control(IR::ID(ingressControlName), tc, cls, bs);
    return ic;
}


/*
const IR::Node* CreateTofinoArchBlock::createEgressControl(
    std::vector<const IR::P4Control*>& p4Controls, IR::Type_Struct*  typeStruct) {

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
                if (ts->getName() == NameConstants::csaPacketStructTypeName) {
                    auto pe = new IR::PathExpression(csaPacketStructInstanceName);
                    auto arg = new IR::Argument(pe);
                    controlArgs->push_back(arg);
                    continue;
                }
                if (ts->getName() == P4V1::V1Model::instance.standardMetadataType.name) {
                    auto pe = new IR::PathExpression(stdMetadataArgName);
                    auto arg = new IR::Argument(pe);
                    controlArgs->push_back(arg);
                    continue;
                }
                fieldType = new IR::Type_Name(ts->getName());
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
    auto ic = createTofinoPipelineControl(egressControlName, bs);
    ic->controlLocals = cls;
    return ic;
}








*/

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

    /*
    auto tnep = new IR::Type_Name(egressParserName);
    auto ptnep = new IR::Argument(new IR::ConstructorCallExpression(tnep, eva->clone()));
    args->push_back(ptnep);

    auto tnec = new IR::Type_Name(egressControlName);
    auto ptnec = new IR::Argument(new IR::ConstructorCallExpression(tnec, eva->clone()));
    args->push_back(ptnec);

    auto tndep = new IR::Type_Name(egressDeparserName);
    auto ptndep = new IR::Argument(new IR::ConstructorCallExpression(tndep, eva->clone()));
    args->push_back(ptndep);
    */

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
    p4program->objects.push_back(createTofinoIngressParser());

    auto ingressControls = getControls(p4program, true);

    auto ic = createIngressP4Control(ingressControls, userMetaStruct);
    p4program->objects.push_back(ic);
    p4program->objects.push_back(createTofinoIngressDeparser());

    /*
    p4program->objects.push_back(createTofinoEgressParser());

    std::vector<const IR::P4Control*> egressControls;
    if (partitions->size() > 1)
        egressControls = getControls(p4program, false);
    auto ec = createEgressControl(egressControls, userMetaStruct);
    p4program->objects.push_back(ec);
    p4program->objects.push_back(createTofinoEgressDeparser());
    */


    p4program->objects.append(createMainPackageInstance());


    for (auto&& ob : p4program->objects) {
        auto con = ob->to<IR::P4Control>();
        if (con != nullptr) {
            // std::cout<<con->getName()<<"\n";
            auto newCon = updateP4Controls.getDeclaration(con->getName());
            if (newCon != nullptr) {
                ob = newCon->to<IR::P4Control>();
            }
        }
    }
    return p4program;

}



}// namespace CSA
