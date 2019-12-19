/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "frontends/p4/fromv1.0/v1model.h"
#include "frontends/p4/coreLibrary.h"
#include "toV1Model.h"
#include "toControl.h"

namespace CSA {

// struct csa_packet_struct_t {
//    csa_packet_h csa_packet;
// }
//
// control ingress (csa_packet_struct_t pkt, csa_user_metadata_t metadataArgName,
// standard_metadata_t csa_sm))
const cstring CreateV1ModelArchBlock::csaPacketStructInstanceName = "pkt_i";
const cstring CreateV1ModelArchBlock::metadataArgName = "csa_um";
const cstring CreateV1ModelArchBlock::stdMetadataArgName = "csa_sm";
const cstring CreateV1ModelArchBlock::userMetadataStructTypeName = "csa_user_metadata_t";

const cstring CreateV1ModelArchBlock::parserName = "csa_v1model_parser";
const cstring CreateV1ModelArchBlock::deparserName = "csa_v1model_deparser";
const cstring CreateV1ModelArchBlock::ingressControlName = "csa_ingress";
const cstring CreateV1ModelArchBlock::egressControlName = "csa_egress";
const cstring CreateV1ModelArchBlock::verifyChecksumName = "csa_verify_checksum";
const cstring CreateV1ModelArchBlock::computeChecksumName = "csa_compute_checksum";

const IR::Node* CreateV1ModelArchBlock::createMainPackageInstance() {

    auto args = new IR::Vector<IR::Argument>();
    auto eva = new IR::Vector<IR::Argument>();

    auto tnp = new IR::Type_Name(parserName);
    auto ptnp = new IR::Argument(new IR::ConstructorCallExpression(tnp, eva));
    args->push_back(ptnp);

    auto tnvc = new IR::Type_Name(verifyChecksumName);
    auto ptnvc = new IR::Argument(new IR::ConstructorCallExpression(tnvc, eva->clone()));
    args->push_back(ptnvc);

    auto tnic = new IR::Type_Name(ingressControlName);
    auto ptnic = new IR::Argument(new IR::ConstructorCallExpression(tnic, eva->clone()));
    args->push_back(ptnic);

    auto tnec = new IR::Type_Name(egressControlName);
    auto ptnec = new IR::Argument(new IR::ConstructorCallExpression(tnec, eva->clone()));
    args->push_back(ptnec);

    auto tncc = new IR::Type_Name(computeChecksumName);
    auto ptncc = new IR::Argument(new IR::ConstructorCallExpression(tncc, eva->clone()));
    args->push_back(ptncc);

    auto tndp = new IR::Type_Name(deparserName);
    auto ptndp = new IR::Argument(new IR::ConstructorCallExpression(tndp, eva->clone()));
    args->push_back(ptndp);

    auto tn =  new IR::Type_Name(P4V1::V1Model::instance.sw.name);
    return new IR::Declaration_Instance(IR::P4Program::main, tn, args);
}


const IR::Node* CreateV1ModelArchBlock::createV1ModelParser() {

    cstring packetInArgName = "pin";
    cstring parseByteStateName = "parse_byte";

    auto pl = getHeaderMetaStdMetaPL();
    pl->parameters.erase(pl->parameters.begin());
    auto ph = new IR::Parameter(IR::ID(csaPacketStructInstanceName), 
        IR::Direction::Out, new IR::Type_Name(NameConstants::csaPacketStructTypeName));
    auto pin = new IR::Parameter(IR::ID(packetInArgName), 
        IR::Direction::None, new IR::Type_Name(P4::P4CoreLibrary::instance.packetIn.name));
    pl->parameters.insert(pl->parameters.begin(), ph);
    pl->parameters.insert(pl->parameters.begin(), pin);

    auto tp = new IR::Type_Parser(parserName, pl);


    auto lhPE = new IR::PathExpression(csaPacketStructInstanceName);
    auto lhIndices = new IR::Member(lhPE, NameConstants::indicesHeaderInstanceName);
    auto lhs = new IR::Member(lhIndices, AddCSAByteHeader::csaPktStuLenFName);
    auto rhs = new IR::Constant(1);
    auto initAs = new IR::AssignmentStatement(lhs, rhs);

    
    IR::IndexedVector<IR::ParserState> states;
    { // creating start state

        auto svPE = new IR::PathExpression(csaPacketStructInstanceName);
        auto svM = new IR::Member(svPE, NameConstants::indicesHeaderInstanceName);
        auto sv = new IR::Member(svM, IR::Type_Header::setValid);
        auto mce = new IR::MethodCallExpression(sv);
        auto setValidMCS =  new IR::MethodCallStatement(mce);

        auto cel = new IR::Member(new IR::PathExpression(stdMetadataArgName),
                                  IR::ID("packet_length"));
        auto cer = new IR::Constant(100);
        auto verifyArg0 = new IR::Argument(new IR::Geq(cel, cer));
        auto verifyArg1 = new IR::Argument(new IR::Member(
              new IR::PathExpression("error"), IR::ID("PacketTooShort")));
        auto verifyArgs = new IR::Vector<IR::Argument>();
        verifyArgs->push_back(verifyArg0);
        verifyArgs->push_back(verifyArg1);
        auto verify = new IR::PathExpression("verify");
        auto emptyTypeVec = new IR::Vector<IR::Type>(); 
        mce = new IR::MethodCallExpression(verify, emptyTypeVec, verifyArgs);
        auto mcs = new IR::MethodCallStatement(mce);
        auto pe = new IR::PathExpression(parseByteStateName);
        IR::IndexedVector<IR::StatOrDecl> components;
        components.push_back(setValidMCS);
        components.push_back(initAs);
        components.push_back(mcs);
        auto ps = new IR::ParserState("start", components, pe);
        states.push_back(ps);
    }
     
    {
        IR::IndexedVector<IR::StatOrDecl> components;

        auto em = new IR::Member(new IR::PathExpression(
              csaPacketStructInstanceName), NameConstants::csaHeaderInstanceName);
        auto exArg = new IR::Argument(new IR::Member(em, "next"));
        auto exArgs = new IR::Vector<IR::Argument>();
        exArgs->push_back(exArg);
        auto extract = new IR::Member(new IR::PathExpression(packetInArgName),
            IR::ID(P4::P4CoreLibrary::instance.packetIn.extract.name));
        auto emptyTypeVec = new IR::Vector<IR::Type>(); 
        auto mce = new IR::MethodCallExpression(extract, emptyTypeVec, exArgs);
        auto mcs = new IR::MethodCallStatement(mce);
        components.push_back(mcs);
        
        auto pe = new IR::PathExpression(csaPacketStructInstanceName);
        auto rhIndices = new IR::Member(pe, NameConstants::indicesHeaderInstanceName);
        auto pkt = new IR::Member(rhIndices, NameConstants::csaPktStuLenFName);
        auto rinc = new IR::Add(pkt, new IR::Constant(1));
        pe = new IR::PathExpression(csaPacketStructInstanceName);
        auto lhIndices = new IR::Member(pe,  NameConstants::indicesHeaderInstanceName);
        auto lh = new IR::Member(lhIndices, NameConstants::csaPktStuLenFName);
        auto inc = new IR::AssignmentStatement(lh, rinc);
        components.push_back(inc);

        pe = new IR::PathExpression(csaPacketStructInstanceName);
        auto pktIndices = new IR::Member(pe, NameConstants::indicesHeaderInstanceName);
        pkt = new IR::Member(pktIndices, NameConstants::csaPktStuLenFName);
        auto rpe = new IR::PathExpression(stdMetadataArgName);
        auto castType = IR::Type::Bits::get(16, false);
        auto rpkt = new IR::Cast(castType, new IR::Member(rpe, "packet_length"));
        auto c1 = new IR::Leq(pkt, rpkt);
        pe = new IR::PathExpression(csaPacketStructInstanceName);
        pktIndices = new IR::Member(pe, NameConstants::indicesHeaderInstanceName);
        pkt = new IR::Member(pktIndices, NameConstants::csaPktStuLenFName);
        auto re = new IR::Constant(*maxExtLen);
        auto c2 = new IR::Leq(pkt, re);
        auto cond = new IR::LAnd(c1, c2);
        auto ev = new IR::Vector<IR::Expression>();
        ev->push_back(cond);
        auto ls = new IR::ListExpression(*ev);

        auto selectCases = new IR::Vector<IR::SelectCase>();

        auto scf = new IR::SelectCase(new IR::BoolLiteral(false), 
            new IR::PathExpression(IR::ParserState::accept));
        auto sct = new IR::SelectCase(new IR::BoolLiteral(true), 
            new IR::PathExpression(parseByteStateName));
        selectCases->push_back(scf);
        selectCases->push_back(sct);

        auto se = new IR::SelectExpression(ls, *selectCases);

        auto ps = new IR::ParserState(parseByteStateName, components, se);
        states.push_back(ps);
    }   

    states.push_back(new IR::ParserState(IR::ParserState::accept, nullptr));

    return new IR::P4Parser(parserName, tp, states);
}




const IR::Node* CreateV1ModelArchBlock::createV1ModelDeparser() {
    cstring packetOutArgName = "po";
    auto pl = new IR::ParameterList();
    auto po = new IR::Parameter(IR::ID(packetOutArgName), 
        IR::Direction::None, new IR::Type_Name(P4::P4CoreLibrary::instance.packetOut.name));
    auto ph = new IR::Parameter(IR::ID(csaPacketStructInstanceName), 
        IR::Direction::In, new IR::Type_Name(NameConstants::csaPacketStructTypeName));
    pl->push_back(po);
    pl->push_back(ph);

    auto argExp = new IR::Member(new IR::PathExpression(csaPacketStructInstanceName),
                                 IR::ID(NameConstants::csaHeaderInstanceName));
    auto args = new IR::Vector<IR::Argument>();
    auto arg = new IR::Argument(argExp);
    args->push_back(arg);

    auto member = new IR::Member(new IR::PathExpression(packetOutArgName),
        IR::ID(P4::P4CoreLibrary::instance.packetOut.emit.name));
    auto emptyTypeVec = new IR::Vector<IR::Type>(); 
    auto mce = new IR::MethodCallExpression(member, emptyTypeVec, args);
    auto mcs = new IR::MethodCallStatement(mce);
    auto bs = new IR::BlockStatement();
    bs->push_back(mcs);

    return createP4Control(deparserName, pl, bs);
}


IR::P4Control* CreateV1ModelArchBlock::createV1ModelPipelineControl(cstring name, 
                                            IR::BlockStatement* bs) {
    auto pl = getHeaderMetaStdMetaPL();
    return createP4Control(name, pl, bs);
}

const IR::Node* CreateV1ModelArchBlock::createV1ModelChecksumControl(cstring name) {
    auto pl = getHeaderMetaPL();
    return createP4Control(name, pl);
}


IR::P4Control* CreateV1ModelArchBlock::createP4Control(cstring name,
    IR::ParameterList* pl, IR::BlockStatement* bs) {
    auto tc = new IR::Type_Control(IR::ID(name), pl);
    auto p4c = new IR::P4Control(IR::ID(name), tc, bs);
    return p4c;
}


const IR::Node* CreateV1ModelArchBlock::createIngressControl(
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
    auto ic = createV1ModelPipelineControl(ingressControlName, bs);
    ic->controlLocals = cls;
    return ic;
}


const IR::Node* CreateV1ModelArchBlock::createEgressControl(
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
    auto ic = createV1ModelPipelineControl(egressControlName, bs);
    ic->controlLocals = cls;
    return ic;
}


IR::ParameterList* CreateV1ModelArchBlock::getHeaderMetaPL() {
    auto pl = new IR::ParameterList();
    auto phdr = new IR::Parameter(IR::ID(csaPacketStructInstanceName), 
        IR::Direction::InOut, new IR::Type_Name(NameConstants::csaPacketStructTypeName));
    auto pum = new IR::Parameter(IR::ID(metadataArgName), 
        IR::Direction::InOut, new IR::Type_Name(userMetadataStructTypeName));
    pl->push_back(phdr);
    pl->push_back(pum);
    return pl;
}


IR::ParameterList* CreateV1ModelArchBlock::getHeaderMetaStdMetaPL() {
    auto pl = getHeaderMetaPL();
    auto psm = new IR::Parameter(IR::ID(stdMetadataArgName), 
        IR::Direction::InOut, 
        new IR::Type_Name(P4V1::V1Model::instance.standardMetadataType.name));
    pl->push_back(psm);
    return pl;
}


std::vector<const IR::P4Control*>
CreateV1ModelArchBlock::getControls(const IR::P4Program* prog, bool ingress) {
  
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

IR::Type_Struct* CreateV1ModelArchBlock::createUserMetadataStructType() {
    auto fiv = new IR::IndexedVector<IR::StructField>();
    auto ts = new IR::Type_Struct(userMetadataStructTypeName, *fiv);
    return ts;
}


const IR::Node* CreateV1ModelArchBlock::preorder(IR::P4Program* p4program) {

    auto userMetaStruct = createUserMetadataStructType();
    p4program->objects.push_back(userMetaStruct);
    p4program->objects.push_back(createV1ModelParser());
    p4program->objects.push_back(createV1ModelDeparser());

    auto ingressControls = getControls(p4program, true);

    auto ic = createIngressControl(ingressControls, userMetaStruct);
    p4program->objects.push_back(ic);

    std::vector<const IR::P4Control*> egressControls;
    if (partitions->size() > 1)
        egressControls = getControls(p4program, false);
    auto ec = createEgressControl(egressControls, userMetaStruct);
    p4program->objects.push_back(ec);

    p4program->objects.push_back(createV1ModelChecksumControl(verifyChecksumName));
    p4program->objects.push_back(createV1ModelChecksumControl(computeChecksumName));
    p4program->objects.push_back(createMainPackageInstance());
    return p4program;

}




const IR::Node* CSAStdMetaSubstituter::preorder(IR::Path* path) {
    return path;
}


const IR::Node* CSAStdMetaSubstituter::preorder(IR::Parameter* param) {
    auto type = typeMap->getTypeType(param->type, true);
    if (auto te = type->to<IR::Type_Extern>()) {
        if (te->getName() == P4::P4CoreLibrary::instance.im.name) {
            prune();
            auto tn = new IR::Type_Name(
                            P4V1::V1Model::instance.standardMetadataType.name); 
            return new IR::Parameter(param->srcInfo, param->name, 
                param->annotations, IR::Direction::InOut, tn, 
                param->defaultValue);

        }
    }
    prune();
    return param;
}


const IR::Node* CSAStdMetaSubstituter::preorder(IR::MethodCallStatement* mcs) {
    auto mi = P4::MethodInstance::resolve(mcs, refMap, typeMap);
    if (mi->is<P4::ExternMethod>()) {
        auto em = mi->to<P4::ExternMethod>();
        if (em->method->name.name == P4::P4CoreLibrary::instance.im.setOutPort.name
            && em->originalExternType->name.name == P4::P4CoreLibrary::instance.im.name) {
            // std::cout<<"Method name :"<<em->method->name<<"\n";
            // std::cout<<"decl :"<<em->object<<"\n";
            auto exp = mcs->methodCall->arguments->at(0)->expression;

            auto p4c = findContext<IR::P4Control>();
            const IR::Parameter* stdMetaParam = getStandardMetadataParam(p4c);
            BUG_CHECK(stdMetaParam != nullptr,
                "standard_metadata parameter not available to replace %1%", mcs);
            auto pathExp = new IR::PathExpression(IR::ID(stdMetaParam->name));
            auto lexp = new IR::Member(pathExp, 
                P4V1::V1Model::instance.standardMetadataType.egress_spec.name);
            prune();
            return new IR::AssignmentStatement(mcs->srcInfo, lexp, exp);
        }
    }

    return mcs;
}
const IR::Node* CSAStdMetaSubstituter::preorder(IR::MethodCallExpression* mce) {

    auto mi = P4::MethodInstance::resolve(mce, refMap, typeMap);
    if (mi->is<P4::ExternMethod>()) {
        auto em = mi->to<P4::ExternMethod>();
        if (em->originalExternType->name.name 
            != P4::P4CoreLibrary::instance.im.name)
            return mce;

        auto p4c = findContext<IR::P4Control>();
        const IR::Parameter* stdMetaParam = getStandardMetadataParam(p4c);
        BUG_CHECK(p4c != nullptr, 
            "CSAStdMetaSubstituter:: unexpected use of %1%", mce);
        auto pathExp = new IR::PathExpression(IR::ID(stdMetaParam->name));
        if (em->method->name.name 
            == P4::P4CoreLibrary::instance.im.getOutPort.name) {           
            auto member = new IR::Member(mce->srcInfo, pathExp,
                P4V1::V1Model::instance.standardMetadataType.egress_spec.name);
            prune();
            return member;
        }
        if (em->method->name.name 
            == P4::P4CoreLibrary::instance.im.getValue.name) {
            auto exp = mce->arguments->at(0)->expression;
            auto mem = exp->to<IR::Member>();
            BUG_CHECK(mem != nullptr, "unable to identify arg %1%", exp);
            if (mem->member == "QUEUE_DEPTH_AT_DEQUEUE") {
                auto m = new IR::Member(mce->srcInfo, pathExp, "enq_qdepth");
                auto tc = IR::Type_Bits::get(32, false);
                auto cm = new IR::Cast(tc, m);
                prune();
                return cm;
            }
        }
        if (em->method->name.name == "drop") {
            auto pe = new IR::PathExpression("mark_to_drop");
            auto dropMce = new IR::MethodCallExpression(
                pe, new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
            prune();
            return dropMce;
        }

    }
    return mce;
}

/*
const IR::Node* CSAStdMetaSubstituter::preorder(IR::Argument* arg) {
    auto type = typeMap->getType(arg->expression, true);
    if (auto te = type->to<IR::Type_Extern>()) {
        if (te->getName() == "egress_spec") {
            prune();
            return nullptr;
        }
    }
    return arg;
}
*/

const IR::Node* CSAStdMetaSubstituter::preorder(IR::AssignmentStatement* as) {
    auto re = as->right->to<IR::BoolLiteral>();
    if (!(re != nullptr && re->value))
        return as;
    
    if (auto lm = as->left->to<IR::Member>()) {
        if (lm->member.name == "drop_flag") {
            auto type = typeMap->getType(lm->expr);
            if (auto td = type->to<IR::Type_Struct>()) {
                if (td->getName() == "csa_standard_metadata_t") {
                    auto pe = new IR::PathExpression("mark_to_drop");
                    auto mce = new IR::MethodCallExpression(
                        pe, new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
                    auto mcs = new IR::MethodCallStatement(mce);
                    prune();
                    return mcs;
                }
            }
        }
    } 
    return as;
}

const IR::Parameter* 
CSAStdMetaSubstituter::getStandardMetadataParam(const IR::P4Control* p4c) {
    BUG_CHECK(p4c != nullptr, 
        "CSAStdMetaSubstituter:: unexpected use of a method call");
    auto params = p4c->getApplyParameters()->parameters;
    const IR::Parameter* stdMetaParam = nullptr;
    for (auto p : params) {
        if (auto tn = p->type->to<IR::Type_Name>()) {
            if (tn->path->name.name == 
                P4V1::V1Model::instance.standardMetadataType.name) {
                return p;
            }
        }
    }
    return nullptr;
}

}// namespace CSA
