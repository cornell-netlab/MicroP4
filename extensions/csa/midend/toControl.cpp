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
        if (auto td = p->type->to<IR::Type_Declaration>())
            typeName = td->getName();
        if (typeName != "") {
            // std::cout<<typeName<<"\n";
            typeToArgsMap[typeName] = pe;
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
        if (auto tn = p->type->to<IR::Type_Name>()) {
            cstring typeName = tn->path->name.name;
            auto iter = typeToArgsMap.find(typeName);
            if (iter != typeToArgsMap.end()) {
                args->push_back(new IR::Argument(iter->second->clone()));
            } else {
                cstring instName = typeName+"_var";
                auto di = new IR::Declaration_Variable(IR::ID(instName), 
                              tn->clone());
                newDeclInsts.push_back(di);
                auto pe = new IR::PathExpression(IR::ID(instName));
                typeToArgsMap[typeName] = pe;
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


/*
void CPackageToControl::addIntermediateExternCalls(IR::BlockStatement* bs) {

    auto args = new IR::Vector<IR::Argument>();
    auto arg = new IR::Argument(typeToArgsMap[ToControl::csaPacketStructTypeName]->clone());
    args->push_back(arg);
    auto member = new IR::Member(typeToArgsMap["csa_packet_out"]->clone(), 
                                 IR::ID("set_packet_struct"));
    auto mce = new IR::MethodCallExpression(member, new IR::Vector<IR::Type>(), 
                                            args);
    auto mcs = new IR::MethodCallStatement(mce);
    bs->components.push_back(mcs);

    auto m = new IR::Member(typeToArgsMap["csa_packet_in"]->clone(), 
                            IR::ID("get_packet_struct"));
    auto me = new IR::MethodCallExpression(m, new IR::Vector<IR::Type>(), 
                                           new IR::Vector<IR::Argument>());
    auto as = new IR::AssignmentStatement(
                  typeToArgsMap[ToControl::csaPacketStructTypeName]->clone(), me);
    bs->components.insert(bs->components.begin(), as);
}
*/

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
    // std::cout<<"visiting "<<cp->getName()<<"\n";;
    resetMCSRelatedObjects();

    // Identify default instances and store them in ctrlInstanceName
    for (auto tdl : *(cp->type->typeLocalDeclarations)) {
        auto name = tdl->getName();
        for (auto dl : cp->packageLocalDeclarations) {
            if (auto di = dl->to<IR::Declaration_Instance>()) {
                if (auto tn = di->type->to<IR::Type_Name>()) {
                    if (tn->path->name.name == name) {
                        ctrlInstanceName[name] = di->name;
                        // std::cout<<di->name<<"\n";
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

    // check for orchestration block
    if (mcsMap.find("micro_parser") != mcsMap.end()) {
        // don't need this in MSA
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
                                  AddCSAByteHeader::csaPktStuCurrOffsetFName, 
                                  stackHeadFieldType);
    auto pktLengthField = new IR::StructField(
                                  AddCSAByteHeader::csaPktStuLenFName, 
                                  pktLengthFieldType);

    IR::IndexedVector<IR::StructField> indicesFields;
    indicesFields.push_back(pktLengthField);
    indicesFields.push_back(stackHeadField);
    auto csaIndicesHeaderType = new IR::Type_Header(
                                      ToControl::indicesHeaderTypeName, indicesFields);


    
    auto pktByteStack = new IR::Type_Stack(
                              new IR::Type_Name(csaByteHeaderType->getName()),
                              new IR::Constant((*maxOffset)/8));

    auto field = new IR::StructField(ToControl::csaHeaderInstanceName, pktByteStack);
    auto fIndices = new IR::StructField(ToControl::indicesHeaderInstanceName, 
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

/*
const IR::Node* AddCSAByteHeader::preorder(IR::Type_Extern* te) {
  
    if (te->getName() == "csa_packet_in") {
        auto rt = new IR::Type_Name(ToControl::csaPacketStructTypeName);
        auto mt = new IR::Type_Method(new IR::TypeParameters(), rt,
                                      new IR::ParameterList());
        auto m = new IR::Method(IR::ID("get_packet_struct"), mt);
        te->methods.push_back(m);
    }

    if (te->getName() == "csa_packet_out") {
        auto t = new IR::Type_Name(IR::ID(ToControl::csaPacketStructTypeName));
        auto p = new IR::Parameter(IR::ID("obj"), IR::Direction::In, t);
        IR::IndexedVector<IR::Parameter> ps;
        ps.push_back(p);
        auto pl = new IR::ParameterList(ps);
        auto mt = new IR::Type_Method(new IR::TypeParameters(), 
                                      new IR::Type_Void(), pl);

        auto m = new IR::Method(IR::ID("set_packet_struct"), mt);
        te->methods.push_back(m);
    }
    return te;  
}
*/


}// namespace CSA
