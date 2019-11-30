/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "toControl.h"

#include "parserConverter.h"

namespace CSA {

const cstring ToControl::csaHeaderInstanceName = "msa_packet";
const cstring ToControl::csaStackInstanceName = "csa_stack";
const cstring ToControl::csaPacketStructTypeName ="msa_packet_struct_t";
const cstring ToControl::csaPacketStructName ="csa_packet_struct";
const cstring ToControl::headerTypeName = "csa_byte_h";
const cstring ToControl::indicesHeaderTypeName = "csa_indices_h";
const cstring ToControl::indicesHeaderInstanceName = "indices";
const cstring ToControl::bitStreamFieldName = "data";



const cstring AddCSAByteHeader::csaPktStuLenFName = "pkt_len";
const cstring AddCSAByteHeader::csaPktStuCurrOffsetFName = "curr_offset";

// used by CSAPacketSubstituter
const cstring ToControl::csaPakcetInGetPacketStruct = "get_packet_struct";
const cstring ToControl::csaPakcetOutSetPacketStruct = "set_packet_struct";
const cstring ToControl::csaPakcetOutGetPacketIn = "get_packet_in";
const cstring ToControl::csaPakcetInExternTypeName = "csa_packet_in";
const cstring ToControl::csaPakcetOutExternTypeName = "csa_packet_out";


cstring CPackageToControl::getNamePrefix() {
    cstring namePrefix = "";
    auto cp = findContext<IR::P4ComposablePackage>();
    if (cp != nullptr) {
        namePrefix = cp->getName() +"_";
    }
    return namePrefix;
}


void CPackageToControl::resetMCSRelatedObjects() {
    typeRenameMap.clear();
    mcsMap.clear();
    ctrlInstanceName.clear();
    typeToArgsMap.clear();
    newDeclInsts.clear();
}


void CPackageToControl::addMCSs(IR::BlockStatement* bs) {
    for (auto cn : archBlockOrder) {
        auto iter = mcsMap.find(cn);
        if (iter != mcsMap.end()) {
            // std::cout<<iter->second<<"\n";
            bs->components.push_back(iter->second);
        }
    }
}


void CPackageToControl::populateArgsMap(const IR::ParameterList* pl) {
    for (auto p : pl->parameters) {
        cstring typeName = "";
        auto pe = new IR::PathExpression(IR::ID(p->getName()));
        if (auto tn = p->type->to<IR::Type_Name>())
            typeName = tn->path->name.name;
        else if (auto td = p->type->to<IR::Type_Declaration>())
            typeName = td->getName();
        else 
            typeName = p->type->toString();
        if (typeName != "") {
            // std::cout<<typeName<<"\n";
            cstring ds = "";
            if (p->direction != IR::Direction::None)
                ds = "_"+cstring::to_cstring(p->direction);
            typeToArgsMap[typeName+ds] = pe;
        }
    }
}


bool CPackageToControl::isArchBlock(cstring name) {

    for (auto c : archBlockOrder) {
        if (c == name)
            return true;
    }
    return false;
}

void CPackageToControl::createMCS(const IR::Type_Control* tc) {

    auto apl = tc->getApplyParameters();
    auto args = new IR::Vector<IR::Argument> ();
    for (auto p : apl->parameters) {
        cstring dir = "";
        if (p->direction != IR::Direction::None)
            dir = "_"+cstring::to_cstring(p->direction);
        if (auto tn = p->type->to<IR::Type_Name>()) {
            cstring typeName = tn->path->name.name;
            auto iter = typeToArgsMap.find(typeName + dir);
            if (iter != typeToArgsMap.end()) {
                args->push_back(new IR::Argument(iter->second->clone()));
            } else {
                cstring instName = typeName+"_var";
                auto pe = new IR::PathExpression(IR::ID(instName));
                auto dl = newDeclInsts.getDeclaration(instName);
                if (dl == nullptr) {
                    auto di = new IR::Declaration_Variable(IR::ID(instName), 
                              tn->clone());
                    newDeclInsts.push_back(di);
                    typeToArgsMap[typeName] = pe;
                }
                args->push_back(new IR::Argument(pe->clone()));
            }
        } else if (auto tb = p->type->to<IR::Type_Bits>()) {
            auto iter = typeToArgsMap.find(tb->toString() + dir);
            if (iter != typeToArgsMap.end()) {
                args->push_back(new IR::Argument(iter->second->clone()));
            }  else {
                cstring instName = "bit_var";
                auto di = new IR::Declaration_Variable(IR::ID(instName), 
                              tn->clone());
                newDeclInsts.push_back(di);
                auto pe = new IR::PathExpression(IR::ID(instName));
                typeToArgsMap[tb->toString() + dir] = pe;
                args->push_back(new IR::Argument(pe->clone()));
            }
        }
    }

    auto iter = ctrlInstanceName.find(tc->getName());
    BUG_CHECK(iter != ctrlInstanceName.end() ,
              " instance should have been created, unexpected situation");
    auto instanceName = iter->second;
    auto member = new IR::Member(new IR::PathExpression(instanceName), 
                                 IR::ID("apply"));
    auto mce = new IR::MethodCallExpression(member, new IR::Vector<IR::Type>(), 
                                            args);
    auto mcs = new IR::MethodCallStatement(mce);

    mcsMap[tc->getName()] = mcs;
}


void CPackageToControl::addIntermediateExternCalls(IR::BlockStatement* bs) {

    cstring typeToArgKey = NameConstants::csaPacketStructTypeName;
    auto args = new IR::Vector<IR::Argument>();
    auto arg = new IR::Argument(typeToArgsMap[typeToArgKey]->clone());
    args->push_back(arg);
    auto member = new IR::Member(
            typeToArgsMap[P4::P4CoreLibrary::instance.pkt.name]->clone(), 
            IR::ID(NameConstants::csaPktSetPacketStruct));
    auto mce = new IR::MethodCallExpression(member, new IR::Vector<IR::Type>(), 
                                            args);
    auto mcs = new IR::MethodCallStatement(mce);
    bs->components.push_back(mcs);

    auto m = new IR::Member(
            typeToArgsMap[P4::P4CoreLibrary::instance.pkt.name]->clone(), 
            IR::ID(NameConstants::csaPktGetPacketStruct));
    auto me = new IR::MethodCallExpression(m, new IR::Vector<IR::Type>(), 
                                           new IR::Vector<IR::Argument>());
    auto as = new IR::AssignmentStatement(
            typeToArgsMap[typeToArgKey]->clone(), me);
    bs->components.insert(bs->components.begin(), as);
}


const IR::Node* CPackageToControl::preorder(IR::Type_Control* tc) {

    auto namePrefix = getNamePrefix();
    if (namePrefix == "") {
        // std::cout<<"no rename : "<<tc->getName()<<"\n";
        return tc;
    }
    tc->srcInfo = cpSourceInfo;
    auto oldName = tc->name.name;
    cstring newName = namePrefix+oldName;
    tc->name = newName; 
    typeRenameMap[oldName] = newName;
    if (oldName == "micro_parser") {
        // auto p = tc->getApplyParameters()->getParameter(1);

        // First out argument of struct type is considered as struct of headers
        const IR::Type* parameterType = nullptr;
        const IR::Type_Struct* pts = nullptr;
        for (auto p : tc->getApplyParameters()->parameters) {
            if (p->direction == IR::Direction::Out) {
                parameterType = p->type;
                auto pType = typeMap->getTypeType(p->type, true);
                if (auto pt = pType->to<IR::Type_Struct>()) {
                    bool allHeaders = true;
                    for (auto f : pt->fields) {
                        auto ft = typeMap->getTypeType(f->type, true);
                        if (!(ft->is<IR::Type_Header>() || 
                            ft->is<IR::Type_HeaderUnion>())) {
                            allHeaders = false;
                            break;
                        }
                    }
                    if (allHeaders) {
                        pts = pt;
                        break;
                    }
                }
            }
        }
        BUG_CHECK(parameterType!=nullptr, 
            "micro_parser expected to have at least one out parameter");
        // auto pt = typeMap->getTypeType(parameterType, true);
        auto parentCpkg = findContext<IR::P4ComposablePackage>();
        // auto pts = pt->to<IR::Type_Struct>();
        if (parentCpkg && pts) {
            controlToReconInfoMap->emplace(parentCpkg->getName(), 
                new ControlStateReconInfo(parentCpkg->getName(), 
                                          pts->getName()));
            // std::cout<<__FILE__<<" "<<__LINE__<<" "<<pts->getName()<<"\n";
        }

    }
    return tc;
}


const IR::Node* CPackageToControl::preorder(IR::P4Control* p4control) {
    // std::cout<<"visiting "<<p4control->getName()<<"\n";;
    auto cp = findContext<IR::P4ComposablePackage>();
    if (cp != nullptr) {
        if (isArchBlock(p4control->getName())) {
            //std::cout<<"creating MCS for "<<p4control->getName()<<"\n";
            createMCS(p4control->type);
            p4control->srcInfo = cpSourceInfo;
        }
    }
    return p4control;
}

const IR::Node* CPackageToControl::postorder(IR::P4Control* p4control) {
    p4control->name = IR::ID(p4control->type->name.name);
    return p4control;
}


const IR::Node* CPackageToControl::preorder(IR::Type_ComposablePackage* tcp) {
    auto n = getContext()->node;
    if (n->is<IR::P4Program>()) {
        prune();
        return nullptr;
    }
    return tcp;
}


const IR::Node* CPackageToControl::preorder(IR::P4ComposablePackage* cp) {

    auto n = getContext()->node;
    // if (n->is<IR::P4Program>())
        // std::cout<<cp->getName()<<" parent is p4program \n";

    // cpSourceInfo = cp->srcInfo;
    std::cout<<"visiting CPackageToControl::preorder: "<<cp->getName()<<"\n";;
    resetMCSRelatedObjects();

    // Identify default instances and store them in ctrlInstanceName
    for (auto tdl : *(cp->type->typeLocalDeclarations)) {
        auto name = tdl->getName();
        for (auto dl : cp->packageLocalDeclarations) {
            if (auto di = dl->to<IR::Declaration_Instance>()) {
                if (auto tn = di->type->to<IR::Type_Name>()) {
                    if (tn->path->name.name == name) {
                        ctrlInstanceName[name] = di->name;
                    }
                }
            }
        }
    }
    
    // prepare type name to IR::PathExpression map, so controls can use the
    // PathExpression to supply arguments in MCS
    populateArgsMap(cp->getApplyParameters());
    return cp;
}

const IR::Node* CPackageToControl::postorder(IR::P4ComposablePackage* cp) {

    auto moveToTop = new IR::Vector<IR::Node>();
    for (auto td : *(cp->packageLocals)) {
        // std::cout<<td->getName()<<"\n";
        moveToTop->push_back(td->clone());
    }
    
    IR::IndexedVector<IR::Declaration> controlLocals;
    for (auto decl : cp->packageLocalDeclarations)
        controlLocals.push_back(decl->clone());
    for (auto decl : newDeclInsts) 
        controlLocals.push_back(decl);

    auto tc = new IR::Type_Control(cp->getName(), cp->annotations->clone(), 
                                   cp->getApplyParameters()->clone());
    
    auto bs = new IR::BlockStatement();
    addMCSs(bs);

    if (mcsMap.find("micro_parser") != mcsMap.end()) {
        // Adding intermediate calls to help CSAPacketSubstituter
        // addIntermediateExternCalls(bs);
    }

    auto p4ct = new IR::P4Control(IR::ID(cp->getName()), tc, controlLocals, bs);

    moveToTop->push_back(p4ct);
    return moveToTop;
}


const IR::Node* CPackageToControl::preorder(IR::Type_Name* tn) { 
    auto n = findContext<IR::P4ComposablePackage>();
    if (n == nullptr)
        return tn;
    auto iter = typeRenameMap.find(tn->path->name.name);
    if (iter != typeRenameMap.end()) {
        return new IR::Type_Name(new IR::Path(IR::ID(iter->second)));
    }
    return tn;
}

const IR::Node* CPackageToControl::preorder(IR::Parameter* p) { 
    IR::Parameter* np = p;
    if (auto td = p->type->to<IR::Type_Declaration>()) {
        IR::Expression* de = nullptr; 
        if (p->defaultValue)
            de = p->defaultValue->clone();
        auto tn = new IR::Type_Name(IR::ID(td->getName()));
        np = new IR::Parameter(p->srcInfo, IR::ID(p->name), p->annotations->clone(),
                               p->direction, tn, de);
    }
    return np;
}


const IR::Node* AddCSAByteHeader::preorder(IR::P4Program* p4Program) {

    LOG3("Adding struct type with field having bitwidth "<<maxOffset);

    auto byteType = IR::Type::Bits::get(8, false);
    auto dataField = new IR::StructField(fieldName, byteType);
    IR::IndexedVector<IR::StructField> fIV;
    fIV.push_back(dataField);
    auto csaByteHeaderType = new IR::Type_Header(headerTypeName, fIV);

    auto pktLengthFieldType = IR::Type::Bits::get(16, false);
    auto stackHeadFieldType = IR::Type::Bits::get(16, false);
    auto stackHeadField = new IR::StructField(
                                  NameConstants::csaPktStuCurrOffsetFName, 
                                  stackHeadFieldType);
    auto pktLengthField = new IR::StructField(
                                  NameConstants::csaPktStuLenFName, 
                                  pktLengthFieldType);

    IR::IndexedVector<IR::StructField> indicesFields;
    indicesFields.push_back(pktLengthField);
    indicesFields.push_back(stackHeadField);
    auto csaIndicesHeaderType = new IR::Type_Header(
                                      NameConstants::indicesHeaderTypeName, indicesFields);


    
    auto pktByteStack = new IR::Type_Stack(
                              new IR::Type_Name(csaByteHeaderType->getName()),
                              new IR::Constant((*maxOffset)/8));

    auto field = new IR::StructField(NameConstants::csaHeaderInstanceName, pktByteStack);
    auto fIndices = new IR::StructField(NameConstants::indicesHeaderInstanceName, 
                            new IR::Type_Name(csaIndicesHeaderType->getName()));

    IR::IndexedVector<IR::StructField> fiv;
    fiv.push_back(field);
    fiv.push_back(fIndices);

    auto ts = new IR::Type_Struct(ToControl::csaPacketStructTypeName, fiv);

    p4Program->objects.insert(p4Program->objects.begin(), ts);
    p4Program->objects.insert(p4Program->objects.begin(), csaIndicesHeaderType);
    p4Program->objects.insert(p4Program->objects.begin(), csaByteHeaderType);

    return p4Program;
}

const IR::Node* AddCSAByteHeader::preorder(IR::Type_Extern* te) {
  
    if (te->getName() == P4::P4CoreLibrary::instance.pkt.name) {
        auto rt = new IR::Type_Name(NameConstants::csaPacketStructTypeName);
        auto mt = new IR::Type_Method(new IR::TypeParameters(), rt,
                                      new IR::ParameterList());
        auto m = new IR::Method(IR::ID(NameConstants::csaPktGetPacketStruct), mt);
        te->methods.push_back(m);

        auto t = new IR::Type_Name(IR::ID(NameConstants::csaPacketStructTypeName));
        auto p = new IR::Parameter(IR::ID("obj"), IR::Direction::In, t);
        IR::IndexedVector<IR::Parameter> ps;
        ps.push_back(p);
        auto pl = new IR::ParameterList(ps);
        mt = new IR::Type_Method(new IR::TypeParameters(), 
                                      new IR::Type_Void(), pl);

        m = new IR::Method(IR::ID(NameConstants::csaPktSetPacketStruct), mt);
        te->methods.push_back(m);
    }
    return te;  
}


const IR::Node* Converter::preorder(IR::P4Program* p4Program) {
    auto mainDecls = p4Program->getDeclsByName(IR::P4Program::main)->toVector();

    if (mainDecls->size() != 1)
        return p4Program;

    auto main = mainDecls->at(0);
    auto mainDeclInst = main->to<IR::Declaration_Instance>();
    if (mainDeclInst == nullptr)
        return p4Program;

    auto type = typeMap->getType(mainDeclInst);
    BUG_CHECK(type!=nullptr && type->is<IR::P4ComposablePackage>(), 
        "could not find type of main package");

    offsetsStack.push_back(new std::vector<unsigned>({0}));
    auto p4cpType = type->to<IR::P4ComposablePackage>();

    // visit(p4cpType);
    // HS: Note on bug-default-instance-typemap
    /*  Ideally , above statement should do, but the node type or p4cpType
     *  returned by TypeMap does not have default instances of parser, control
     *  and deparser.
     *  The default Declaration_Instances were created by AnnotateTypes pass.
     *  They are not available in p4cpType node. but, but they exist in program IR.
     *  They are deleted in the node stored by TypeChecker.
     *  This needs to be investigated at some point.. 
     *  For now quick hack is to get the node from program IR
    for (auto& o : p4Program->objects) {
        auto cp = o->to<IR::P4ComposablePackage>();
        if (cp != nullptr) {
            std::cout<<cp->packageLocalDeclarations.size()<<"\n";
            for (auto& dl : cp->packageLocalDeclarations)
              std::cout<<"Convert ***** : "<<dl<<"\n";
        }
    }
    */

    // Hack for bug-default-instance-typemap
    for (auto& o : p4Program->objects) {
        auto cp = o->to<IR::P4ComposablePackage>();
        if (cp != nullptr && cp->getName() == p4cpType->getName()) {
          visit(o);
          break;
        }
    }

    for (auto updateNode : updateP4ProgramObjects) {
        for (auto& o : p4Program->objects) {
            auto p4cp = o->to<IR::P4ComposablePackage>();
            if (p4cp != nullptr && p4cp->getName() == updateNode->getName()) {
                o = updateNode;
            }
        }
    }


    p4Program->objects.insert(p4Program->objects.begin(), 
        addInP4ProgramObjects.begin(), addInP4ProgramObjects.end());
    prune();
    return p4Program;
}


const IR::Node* Converter::preorder(IR::P4ComposablePackage* cp) {
    
    std::cout<<"visiting P4ComposablePackage "<<cp->getName()<<"\n";
    LOG3("Converter preorder visit P4ComposablePackage: "<<cp->name);

    /*
     * Debug point for bug-default-instance-typemap
    std::cout<<cp->packageLocalDeclarations.size()<<"\n";
    for (auto& dl : cp->packageLocalDeclarations)
        std::cout<<"Convert ***** : "<<dl<<"\n";
    */

    auto packageLocals = cp->packageLocals->clone();
    const IR::Type_Declaration* convertedParser = nullptr;
    for (auto& p : *packageLocals) {
        if (p->is<IR::P4Parser>()) {
            visit(p);
            convertedParser = p;
            break;
        }
    }

    // Any callee in control blocks will use above offsets( offsetsStack.back())
    // Visiting controls
    for (auto& typeDecl : *(packageLocals)) {
        auto control = typeDecl->to<IR::P4Control>();
        if (control != nullptr && convertedParser != typeDecl) {
            if (!isDeparser(control))
                visit(typeDecl);
        }
    }

    // Visiting Deparser
    for (auto& typeDecl : *(packageLocals)) {
        auto control = typeDecl->to<IR::P4Control>();
        if (control != nullptr && convertedParser != typeDecl) {
            if (isDeparser(control)) {
                visit(typeDecl);
                break;
            }
        }
    }

    visit(cp->packageLocalDeclarations);
    cp->packageLocals = packageLocals;
    prune();
    updateP4ProgramObjects.push_back(cp);
    std::cout<<"Finish visiting "<<cp->getName()<<"\n";
    return cp;
}

const IR::Node* Converter::preorder(IR::P4Parser* parser) {
    std::cout<<"visiting "<<parser->getName()<<"\n";
    cstring parser_fqn = parser->getName();
    auto cp = findContext<IR::P4ComposablePackage>();
    if (cp != nullptr)
        parser_fqn = cp->getName() +"_"+ parser->getName();
    // std::cout<<parser_fqn<<"\n";
    auto iter = parserStructures->find(parser_fqn);
    BUG_CHECK(iter != parserStructures->end(), 
        "Parser %1% of %2% is not evaluated", parser->name, cp->getName());
    auto parserStructure = iter->second;
    
    auto flagType = IR::Type::Bits::get(1, false);
    auto flagField = new IR::StructField(
                         NameConstants::csaParserRejectStatus, flagType);
    IR::IndexedVector<IR::StructField> fIV;
    fIV.push_back(flagField);
    auto ts = new IR::Type_Struct(IR::ID(parser_fqn+"_meta_t"), fIV);
    addInP4ProgramObjects.push_back(ts);

    ParserConverter pc(refMap, typeMap, controlToReconInfoMap, parserStructure, 
                       offsetsStack.back(), parser_fqn+"_meta_t");
    auto convertedParser = ((IR::Node*)parser)->apply(pc);

    // new start offsets are computed and pushed on offsetsStack.
    auto currentParserOffsets = parserStructure->result->getAcceptedPktOffsets();
    auto acceptedPktOffset = new std::vector<unsigned>();
    for (const auto& currentOffset : *(offsetsStack.back())) {
        for (auto o : currentParserOffsets) {
            acceptedPktOffset->push_back(currentOffset + o);
            // std::cout<<currentOffset + o<<"  ";
        }
        // std::cout<<"\n";
    }
    offsetsStack.push_back(acceptedPktOffset);


    prune();
    return convertedParser;
}

const IR::Node* Converter::preorder(IR::P4Control* p4Control) {

    if (!isDeparser(p4Control)) {
    // std::cout<<"visiting ccccc "<<p4Control->getName()<<"\n";
        visit(p4Control->body);
        prune();
        return p4Control;
    } 

    // std::cout<<"visiting ----- "<<p4Control->getName()<<"\n";
    offsetsStack.pop_back();
    auto& initialOffsets = *(offsetsStack.back());
    DeparserConverter dc(refMap, typeMap, initialOffsets);

    auto dep = p4Control->apply(dc);
    prune();
    return dep;
}

const IR::Node* Converter::preorder(IR::MethodCallStatement* mcs) {
    auto expression = mcs->methodCall;
    P4::MethodInstance* mi = P4::MethodInstance::resolve(expression, refMap, typeMap);
    auto applyMethod = mi->to<P4::ApplyMethod>();
    if (applyMethod != nullptr) {
        if (applyMethod->applyObject->is<IR::P4ComposablePackage>()) {
            auto cp = applyMethod->applyObject->to<IR::P4ComposablePackage>();
            // Hack for bug-default-instance-typemap
            auto p4Program = findContext<IR::P4Program>();
            for (auto& o : p4Program->objects) {
                auto ocp = o->to<IR::P4ComposablePackage>();
                if (ocp != nullptr && ocp->getName() == cp->getName()) {
                    visit(ocp);
                    break;
                }
            }
        }
    }
    prune();
    return mcs;
}

bool Converter::isDeparser(const IR::P4Control* p4Control) {

    auto params = p4Control->getApplyParameters();
    for (auto param : params->parameters) {
        auto type = typeMap->getType(param, false);
        CHECK_NULL(type);
        if (type->is<IR::Type_Extern>()) {
            auto te = type->to<IR::Type_Extern>();
            if (te->name.name == P4::P4CoreLibrary::instance.emitter.name) {
                // std::cout<<te<<"\n";
                return true;
            }
        }
    }
    return false;
}



}// namespace CSA
