/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include <math.h>

#include "slicePipeControl.h"
#include "toControl.h"
#include "frontends/p4/methodInstance.h"

namespace CSA {


bool GetUsedDeclarations::preorder(const IR::PathExpression* pathExpression) {

    // std::cout<<"Checking for path "<<pathExpression->path->name<<"\n";
    auto idecl = p4Control->getDeclByName(pathExpression->path->name);
    //auto applyParams = p4Control->getApplyParameters();
    if (idecl != nullptr) {
        auto decl = idecl->to<IR::Declaration>();
        auto existingDecl = usedDecls->getDeclaration(decl->getName());
        if (existingDecl == nullptr) {
            // std::cout<<"pushing Declaration : "<<decl->getName()<<"\n";
            visit(decl);
            // This creates effect of tail-recursion and puts decls in
            // appropriate order of usage
            usedDecls->push_back(decl);
        }
    }
    return true;
}


const IR::Node* RereferenceDeclPathsToArg::postorder(IR::PathExpression* pe) {
    
    cstring n = pe->path->name.name;
    auto idecl = movedToStructArgDecls->getDeclaration(n);
    if (idecl == nullptr)
        return new IR::PathExpression(pe->path->name.name);
    // std::cout<<"PathExpression  :   "<<pe<<"\n";
    auto m = new IR::Member(new IR::PathExpression(argName), 
                            IR::ID(pe->path->name.name));
    // std::cout<<"member  :   "<<m<<"\n";
    return m;
}


const IR::Node* AddInstancesInApplyParameterList::preorder(IR::P4Control* p4c) {
    visit(p4c->type);
    prune();
    return p4c;
}


const IR::Node* AddInstancesInApplyParameterList::preorder(IR::Type_Control* tc) {
    visit(tc->applyParams);
    prune();
    return tc;
}

const IR::Node* AddInstancesInApplyParameterList::preorder(IR::ParameterList* pl) {
    auto newPl = new IR::ParameterList();
    for (auto p : pl->parameters) {
        auto np = new IR::Parameter(p->getName(), p->direction, p->type->getP4Type());
        newPl->push_back(np);
    }
    for (auto si : sharedLocalDeclInsts) {
        auto p = new IR::Parameter(si->getName(), IR::Direction::None, si->type->getP4Type());
        newPl->push_back(p);
        paramToInstanceName->emplace(si->getName(), si->getName());
    }
    prune();
    return newPl;
}


const IR::Node* SlicePipeControl::preorder(IR::Type_Control* type) {

    auto apl = type->getApplyParameters();
    auto newAPL = apl->clone();
    /*
    cstring pktStr = NameConstants::csaPacketStructTypeName;
    auto p0 = new IR::Parameter(IR::ID(pktStr+"_var"), 
        IR::Direction::InOut,  new IR::Type_Name(IR::ID(pktStr)));
    newAPL->parameters.replace(newAPL->parameters.begin(), p0);
    */
    auto p = new IR::Parameter(sharedStructInstArgName, IR::Direction::InOut, 
                               new IR::Type_Name(sharedStructTypeName));
    newAPL->push_back(p);

    auto p4ControlPart1Name = getUniqueControlName(type->name);
    auto rt = new IR::Type_Control(type->srcInfo, p4ControlPart1Name, newAPL);
    return rt;
}

const IR::Node* SlicePipeControl::preorder(IR::Declaration_Variable* dv) {
    
    // isConvertedCPackage helps to identify deparser/parser and synthesize code
    // accordingly.
    cstring var_name = NameConstants::csaPacketStructTypeName+"_var";
    if (dv->getName() == var_name ) {
        intermediateCSAPacketHeaderInst = var_name;
        isConvertedCPackage = true;
    }
    return dv;
    
} 

const IR::Node* SlicePipeControl::preorder(IR::P4Control* p4control) {

    msaPktParamName="";
    //std::cout<<"SlicePipeControl Visiting P4Control "<<p4control->getName()<<"\n";
    // Skipping the parser/deparser control
    auto param = p4control->getApplyParameters()->getParameter(0);
    auto type = typeMap->getTypeType(param->type, true);
    if (type->is<IR::Type_StructLike>()) {
        auto typeStruct = type->to<IR::Type_StructLike>();
        // std::cout<<"Type : "<<type<<"\n";
        if (typeStruct->name == NameConstants::csaPacketStructTypeName) {
            // std::cout<<"skipping "<<p4control->name.name<<"\n";
            prune();
            return p4control;
        }
    }
    if (auto te = type->to<IR::Type_Extern>() ){
        if (te->getName() ==  P4::P4CoreLibrary::instance.pkt.name)
            msaPktParamName = param->getName();
    }


    track = true;
    slice = false;
    isConvertedCPackage = false;
    splitApplyMCE = nullptr; 

    visit(p4control->controlLocals);
    visit(p4control->body);

    if (slice) {
        std::set<cstring> replicateDecls;
        auto part1Body = const_cast<IR::BlockStatement*>
                          (slicedHalf->to<IR::BlockStatement>());
        cstring p4ControlOrigName = p4control->getName();

        for (auto dv : sharedVariableDecls)
            p4control->controlLocals.push_back(dv);
        for (auto nci : newControlInsts) 
            p4control->controlLocals.push_back(nci);

        // std::cout<<"First part of control body\n";
        // std::cout<<part1Body<<"\n\n";
        // std::cout<<p4control->body<<"\n\n";
        
        auto part2Body = new IR::BlockStatement();
        for (auto s : newStmtVec) {
            part2Body->components.push_back(s);
        }
        // std::cout<<"Second part of control body\n";
        // std::cout<<part2Body<<"\n\n";

        IR::Type_Declaration* deparser = nullptr;
        IR::Type_Declaration* parser = nullptr;

        if (isConvertedCPackage) {
            // Now, we are at the place where we need to do all sorts of state
            // reconstruction between ingress and egress
            auto iter = controlToReconInfoMap->find(p4control->getName());
            if (iter != controlToReconInfoMap->end()) {
                cstring parsedHeaderTypeName = iter->second->headerTypeName;
                // std::cout<<iter->first<<" - "<<iter->second<<"\n";
                deparser = createIntermediateDeparser(
                    NameConstants::csaPacketStructTypeName, iter->second);
                    //ToControl::csaPacketStructTypeName, iter->second);
                parser = createIntermediateParser(
                    NameConstants::csaPacketStructTypeName, iter->second);

                cstring varName = "";
                // get parsed header instance name from the apply call.
                for (auto arg : *(splitApplyMCE->arguments)) {
                    auto type = typeMap->getType(arg->expression, true);
                    if (auto ts = type->to<IR::Type_Struct>()) {
                        // std::cout<<"type : "<<ts->getName()<<"\n";
                        if (parsedHeaderTypeName == ts->getName()) {
                            auto pe = arg->expression->to<IR::PathExpression>();
                            BUG_CHECK(pe!=nullptr, "unexpected situation");
                            varName = pe->path->name.name;
                            break;
                        }
                    }
                }
                
                replicateDecls.emplace(varName);
                replicateDecls.emplace(intermediateCSAPacketHeaderInst);

                // declaring header validity map
                cstring hdrValidBitMapVarName = iter->second->headerTypeName + "_valid";
                auto hdrValidBitMapVar = new IR::Declaration_Variable(hdrValidBitMapVarName, 
                                         iter->second->sharedVariableType);
                p4control->controlLocals.push_back(hdrValidBitMapVar);

                // instantiating deparser and parser controls
                auto intermediateDeparserInst = new IR::Declaration_Instance(
                    IR::ID(deparser->getName()+"_inst"), 
                    new IR::Type_Name(deparser->getName()),
                    new IR::Vector<IR::Argument>());
                auto intermediateParserInst = new IR::Declaration_Instance(
                    IR::ID(parser->getName()+"_inst"), 
                    new IR::Type_Name(parser->getName()),
                    new IR::Vector<IR::Argument>());
                p4control->controlLocals.push_back(intermediateDeparserInst);
                p4control->controlLocals.push_back(intermediateParserInst);

                // deparser and parser apply calls
                auto dpArgs = new IR::Vector<IR::Argument>();
                dpArgs->push_back(new IR::Argument(
                      new IR::PathExpression(intermediateCSAPacketHeaderInst)));
                dpArgs->push_back(new IR::Argument(
                      new IR::PathExpression(varName)));
                dpArgs->push_back(new IR::Argument(
                      new IR::PathExpression(hdrValidBitMapVarName)));
                auto dpe = new IR::PathExpression(intermediateDeparserInst->getName());
                auto memdp = new IR::Member(dpe, "apply");
                auto dpMCE = new IR::MethodCallExpression(memdp, dpArgs);

                auto pe = new IR::PathExpression(intermediateParserInst->getName());
                auto memp = new IR::Member(pe, "apply");
                auto pMCE = new IR::MethodCallExpression(memp, dpArgs->clone());

                auto dMCS = new IR::MethodCallStatement(dpMCE);
                auto pMCS = new IR::MethodCallStatement(pMCE);

                auto& p2Stmts = part2Body->components;
                auto& p1Stmts = part1Body->components;

                p1Stmts.push_back(dMCS);
                p2Stmts.insert(p2Stmts.begin(), pMCS);
                /*
                auto lastBS = p2Stmts.back()->to<IR::BlockStatement>();
                BUG_CHECK(lastBS != nullptr, "expected Blockstatement here");
                p1Stmts.push_back(lastBS->components.back()->clone());

                auto getPktCall = p1Stmts.front();
                p2Stmts.insert(p2Stmts.begin(), getPktCall->clone());
                */
                /*
                std::cout<<"part1body ------------\n";
                std::cout<<part1Body<<"\n";
                std::cout<<"part2body ------------\n";
                std::cout<<part2Body<<"\n";
                */
            }              
        }

        p4control->body = part1Body;

        visit(p4control->type);
        // std::cout<<"First part name : --"<<p4control->type->name<<"\n";
        auto p4ControlPart2 = createPartitionedP4Control(p4control, part2Body);
        //std::cout<<"IInd part name : --"<<p4ControlPart2->type->name<<"\n";
        p4control->name = p4control->type->name;
        auto sharedStruct = createSharedStructType(&p4control, &p4ControlPart2,
            replicateDecls);
        
        /*
        std::cout<<"First Control ................ \n";
        std::cout<<p4control<<"\n";
        std::cout<<"Second Control ................ \n";
        std::cout<<p4ControlPart2<<"\n";
        */

        partitionsMap.emplace(std::piecewise_construct,
            //std::forward_as_tuple(p4ControlOrigName),
            std::forward_as_tuple(p4control->getName()),
            std::forward_as_tuple(p4ControlOrigName, sharedStruct, 
              sharedLocalDeclInsts, param2InstPart1, param2InstPart2,
              p4control, p4ControlPart2, deparser, parser));
    }
    prune();
    return p4control;
}


IR::Type_Struct* 
SlicePipeControl::createSharedStructType(IR::P4Control** c1, IR::P4Control** c2, 
                                         std::set<cstring> replicateDecls) {

    auto p4C1 = *c1;
    auto p4C2 = *c2;
    IR::IndexedVector<IR::Declaration> usedDecls;

    GetUsedDeclarations part1GetUsed(p4C2, &usedDecls);
    p4C1->body->apply(part1GetUsed);
    p4C1->controlLocals.clear();
    p4C1->controlLocals = usedDecls;
    usedDecls.clear();

    GetUsedDeclarations part2GetUsed(p4C2, &usedDecls);
    p4C2->body->apply(part2GetUsed);
    p4C2->controlLocals.clear();
    p4C2->controlLocals = usedDecls;
    usedDecls.clear();


    IR::IndexedVector<IR::StructField> fields;
    for (auto fns : newFieldsInfo) {
        auto bitType = IR::Type::Bits::get(fns.second, false);
        auto f = new IR::StructField(IR::ID(fns.first), bitType);
        fields.push_back(f);
    }

    // usedDecls is used to identify shared declarations
    for (auto idecl1 : p4C1->controlLocals) {
        auto idecl2 = p4C2->controlLocals.getDeclaration(
                          idecl1->getName());
        if (idecl2 != nullptr &&
            replicateDecls.find(idecl1->getName()) == replicateDecls.end()) {
            usedDecls.push_back(idecl1);
        }
    }

    for (auto idecl : usedDecls) {
        if (idecl->is<IR::Declaration_Constant>()) 
            continue;
        p4C2->controlLocals.removeByName(idecl->getName());
        p4C1->controlLocals.removeByName(idecl->getName());
        if (auto dv = idecl->to<IR::Declaration_Variable>()) {
            // std::cout<<"---------------------"<<dv<<"\n";
            auto dvType = dv->type->clone();
            BUG_CHECK(dvType->is<IR::Type_Name>() ||
                      dvType->is<IR::Type_Base>(), 
                      "currently supporting only Type_Name in Declaration Variable inside control");
            auto f = new IR::StructField(IR::ID(dv->getName()), dvType);
            fields.push_back(f);
        }
        if (auto di = idecl->to<IR::Declaration_Instance>()) {
            auto inst = P4::Instantiation::resolve(di, refMap, typeMap);
            BUG_CHECK(inst->is<P4::ExternInstantiation>(), 
                "as of now only extern instances can be handled while spliting");

            //std::cout<<"Declaration : "<<di->getName()<<"\n";
            sharedLocalDeclInsts.push_back(di);
        }
    }

    for (auto di : sharedLocalDeclInsts) {
        usedDecls.removeByName(di->getName());
    }

    RereferenceDeclPathsToArg rf(&usedDecls, sharedStructInstArgName);
    auto pc1 = p4C1->apply(rf);
    auto pc2 = p4C2->apply(rf);

    AddInstancesInApplyParameterList aipl1(sharedLocalDeclInsts, &param2InstPart1);
    AddInstancesInApplyParameterList aipl2(sharedLocalDeclInsts, &param2InstPart2);
    *c1 = pc1->apply(aipl1)->clone();
    *c2 = pc2->apply(aipl2)->clone();

    auto ts = new IR::Type_Struct(sharedStructTypeName, fields);
    return ts;
}


const IR::Node* SlicePipeControl::preorder(IR::BlockStatement* blockStatement) {
    if (!track)
        return blockStatement;
    // std::cout<<"------- bs starts------------\n";
    // std::cout<<blockStatement<<"\n";
    // std::cout<<"------- bs ends  ------------\n";
    auto size = newStmtVec.size();
    auto returnStmt = new IR::BlockStatement();
    auto it = blockStatement->components.begin();
    slice = false;
    slicedHalf = nullptr;
    for ( ; it != blockStatement->components.end() ;it++) {
        visit(*it);
        if (slice) {
            if (slicedHalf) {
                it++;
                returnStmt->components.push_back(slicedHalf);
                slicedHalf = nullptr;
            }
            break;
        }
        returnStmt->components.push_back(*it);
    }
    if (slice) {
        prune();
        // std::cout<<"BS sliced at -> "<<(*it) <<"\n ";
        // std::cout<<"----------------------------------\n";
        // std::cout<<"slicing block  \n ";
        auto newStmt = new IR::BlockStatement();
        while (newStmtVec.size() != size) {
            auto s = newStmtVec.back();
            // std::cout<<s<<"\n";
            newStmt->components.push_back(s);
            newStmtVec.pop_back();
        }
        // std::cout<<"sliced [\n";
        for (;it != blockStatement->components.end(); it++) {
            // std::cout<<*it<<"\n";
            newStmt->components.push_back(*it);
        }
        // std::cout<<"] \n";
        newStmtVec.push_back(newStmt);
        // std::cout<<"----------------------------------\n";

        slicedHalf = returnStmt;
        return nullptr;
    }
    return returnStmt;
}

/*
const IR::Node* SlicePipeControl::postorder(IR::BlockStatement* blockStatement) {
    return blockStatement;
}

const IR::Node* SlicePipeControl::postorder(IR::Statement* stmt) {
    if (!track)
        return stmt;
    if (slice)
        newStmtVec.push_back(stmt);
    return stmt;
}
*/


const IR::Node* SlicePipeControl::preorder(IR::IfStatement* ifStmt) {
    if (!track)
        return ifStmt;
    // std::cout<<"------- if starts------------\n";
    // std::cout<<ifStmt<<"\n";
    // std::cout<<"------- if ends  ------------\n";
    cstring fieldName = "";
    IR::Statement* ifAsStmt = nullptr;
    IR::Statement* elseAsStmt = nullptr;

    slice = false;
    visit(ifStmt->condition);
    if (slice) {
        prune();
        slicedHalf = nullptr;
        return ifStmt;
    }

    IR::Statement* ifStmtSlice = nullptr;
    IR::Statement* elseStmtSlice = nullptr;
    size_t size = newStmtVec.size();
    bool trueSlice = false;
    slice = false;
    visit(ifStmt->ifTrue);
    if (slice) {
        // std::cout<<"----------------------------------\n";
        // std::cout<<"slicing true brabch \n ";
        fieldName = getFieldNameForSlice();
        ifAsStmt = createAssignmentStatement(fieldName, 1);
        
        auto bs = new IR::BlockStatement();
        while (newStmtVec.size() != size) {
            auto stmt = newStmtVec.back();
            // std::cout<<stmt<<"\n";
            bs->components.push_back(stmt);
            newStmtVec.pop_back();
        }
        ifStmtSlice = createIfStatement(fieldName, 1, bs);
        newStmtVec.push_back(ifStmtSlice);
        // std::cout<<ifStmtSlice<<"\n";
        // std::cout<<"----------------------------------\n";
    }
    trueSlice = slice;
    slice = false;
    size = newStmtVec.size();
    visit(ifStmt->ifFalse);
    if (slice) {
        if (fieldName == "")
            fieldName = getFieldNameForSlice();
        elseAsStmt = createAssignmentStatement(fieldName, 2);

        auto bs = new IR::BlockStatement();
        while (newStmtVec.size() != size) {
            auto stmt = newStmtVec.back();
            bs->components.push_back(stmt);
            newStmtVec.pop_back();
        }
        elseStmtSlice = createIfStatement(fieldName, 2, bs);
        newStmtVec.push_back(elseStmtSlice);

    }
    slice =  slice || trueSlice;
    // std::cout<<"slice "<<slice<<"\n";
    if (slice) {
        prune();
        IR::Statement *ifStmtIfTrue = nullptr, *ifStmtIfFalse = nullptr;
        if (ifStmt->ifTrue != nullptr)
            ifStmtIfTrue = appendStatement(ifStmt->ifTrue->clone(), ifAsStmt);
        if (ifStmt->ifFalse != nullptr)
            ifStmtIfFalse = appendStatement(ifStmt->ifFalse->clone(), elseAsStmt);
        auto newIfStmt = new IR::IfStatement(ifStmt->condition->clone(), 
                                             ifStmtIfTrue, ifStmtIfFalse);
        slicedHalf = newIfStmt;
        return nullptr;
    }
    return ifStmt;
}

/*
const IR::Node* SlicePipeControl::postorder(IR::IfStatement* ifStmt) {
    return ifStmt;
}
*/

const IR::Node* SlicePipeControl::preorder(IR::MethodCallExpression* mce) {

    auto ancestorP4Control = findContext<IR::P4Control>();
    if (ancestorP4Control == nullptr) {
        prune();
        return mce;
    }

    auto mi = P4::MethodInstance::resolve(mce, refMap, typeMap);
    if (mi->isApply()) {
        auto a = mi->to<P4::ApplyMethod>();
        if (a->isTableApply()) {
            auto p4Table = a->object->to<IR::P4Table>();
            // std::cout<<"P4Table : "<<p4Table<<"\n";
            for (auto decl : ancestorP4Control->controlLocals) {
                if (decl->getName() == p4Table->name.name) {
                    // std::cout<<"decl : "<<decl->getName()<<"\n";
                    track = false;
                    visit(decl);
                    track = true;
                    break;
                }
            }
        }

        const IR::P4Control* p4Control = nullptr;
        if (auto di = a->object->to<IR::Declaration_Instance>()) {
            auto inst = P4::Instantiation::resolve(di, refMap, typeMap);
            if (auto ci = inst->to<P4::ControlInstantiation>()) 
                p4Control = ci->control;
        }
        if (p4Control != nullptr) {
            cstring p4ControlName = p4Control->getName();
            // cstring structTypeName = "struct_"+p4Control->getName()+"_t";
            cstring structTypeName = getSharedStructTypeName(p4Control->getName()); 
            SlicePipeControl slicePipeControl(refMap, typeMap, 
                structTypeName, partitionState, controlToReconInfoMap);
            
            // std::cout<<mce<<"\n";
            auto p4ControlPart1 = p4Control->apply(slicePipeControl);

            auto partMap = slicePipeControl.getPartitionInfo();
            if (partMap.empty())
                return mce;
            // auto iter = partMap.find(p4ControlName);
            auto iter = partMap.find(p4ControlPart1->getName());
            BUG_CHECK(iter != partMap.end(), 
                "partition info for %1% does not exist", p4ControlName);

            auto p4C1Name = iter->second.partition1->getName();
            auto p4C2Name = iter->second.partition2->getName();
            cstring varName = structTypeName+"_var";
            auto dv = new IR::Declaration_Variable(varName, 
                                            new IR::Type_Name(structTypeName));

            sharedVariableDecls.push_back(dv);
            
            cstring ci1Name = p4C1Name+"_inst";
            cstring ci2Name = p4C2Name+"_inst";
            auto ci1 = new IR::Declaration_Instance(ci1Name, 
                new IR::Type_Name(p4C1Name), new IR::Vector<IR::Argument>());
            newControlInsts.push_back(ci1);
            auto ci2 = new IR::Declaration_Instance(ci2Name, 
                new IR::Type_Name(p4C2Name), new IR::Vector<IR::Argument>());
            newControlInsts.push_back(ci2);

            auto mem1 = new IR::Member(new IR::PathExpression(IR::ID(ci1Name)), 
                                       IR::ID("apply"));
            auto newArgs = mce->arguments->clone();
            auto newArg = new IR::Argument(new IR::PathExpression(varName));
            newArgs->push_back(newArg);

            for (auto di : slicePipeControl.getSharedDeclarationInstances()) {
                sharedLocalDeclInsts.push_back(di);
                auto newArg = new IR::Argument(new IR::PathExpression(di->getName()));
                newArgs->push_back(newArg);
            }

            auto mce1 = new IR::MethodCallExpression(mem1, newArgs);
            auto mcs1 = new IR::MethodCallStatement(mce1);

            auto mem2 = new IR::Member(new IR::PathExpression(IR::ID(ci2Name)), 
                                       IR::ID("apply"));
            auto mce2 = new IR::MethodCallExpression(mem2, newArgs->clone());
            auto mcs2 = new IR::MethodCallStatement(mce2);

            for (auto part : partMap)
                partitionsMap.emplace(part.first, part.second);

            /*
            std::cout<<"Spliting \n"<<mce<<"\n";
            std::cout<<"into \n"<<"(1) "<<mce1<<"\n";
            std::cout<<"(2) "<<mce2<<"\n";
            */
            splitApplyMCE = mce;
            slice = true;
            prune();
            slicedHalf = mcs1;
            newStmtVec.push_back(mcs2);
            return mce1;
        }
    }
    if (mi->is<P4::ActionCall>()) {
        auto action = mi->to<P4::ActionCall>()->action;
        for (auto decl : ancestorP4Control->controlLocals) {
            if (decl->getName() == action->name.name) { 
                track = false;
                // std::cout<<"Action : "<<decl->getName()<<"\n";
                visit(decl);
                track = true;
                break;
            }
        }
    }
    if (mi->is<P4::ExternMethod>()) {
        // std::cout<<"ExternMethod : "<<mce<<"\n";
        processExternMethodCall(mi->to<P4::ExternMethod>());
    }
    prune();
    return mce;
}

/*
const IR::Node* SlicePipeControl::postorder(IR::AssignmentStatement* asStmt) {
    if (isConvertedCPackage) {
        auto lhs = asStmt->left->to<IR::PathExpression>();
        BUG_CHECK(lhs!=nullptr, 
            "lhs in intermediate stmt should be pathexpression");
        intermediateCSAPacketHeaderInst = lhs->path->name.name;
        // std::cout<<intermediateCSAPacketHeaderInst<<"\n";
    }
    return asStmt;
}
*/


void SlicePipeControl::processExternMethodCall(const P4::ExternMethod* em) {
    if (em->originalExternType->name.name == "im_t") {
        // Currently in ingress state.
        if (partitionState == ControlConstraintStates::ES_RW_IM_R) {
            // If any of the following condition satisfies slicing should happen.
            // The program statements that are allowed only in egress.
            // (i.e. things that are not allowed in ingress)
            if (em->method->name.name == "get_value") {
                // std::cout<<"ingress slice  ------------\n";
                slice = true;
            }
        }
        // Currently in egress state
        if (partitionState == ControlConstraintStates::ES_R_EM_R) {
            // things that are not allowed in egress
            if (em->method->name.name == "set_out_port") {
                // std::cout<<"egress slice  ------------\n";
                slice = true;
            }
        }

    }

    /*
    if (em->originalExternType->name.name == "csa_packet_in") {
        if (em->method->name.name == "get_packet_struct") {
            isConvertedCPackage = true;
        }
    }
    if (em->originalExternType->name.name == "csa_packet_out") {
        if (em->method->name.name == "set_packet_struct") {
            isConvertedCPackage = true;
        }
    }
    */  



}


cstring SlicePipeControl::getFieldNameForSlice(bool ifSwitch, unsigned valRange) {
    static unsigned ifVarIndex = 0;
    static unsigned swVarIndex = 0;

    std::string name;
    if (ifSwitch) 
        name = "if_" + std::to_string(ifVarIndex++);
    else 
        name = "sw_" + std::to_string(swVarIndex++);

    unsigned width = ceil(log2 (valRange));
    newFieldsInfo.emplace_back(name, width);
    return name;
}


IR::Statement* SlicePipeControl::createAssignmentStatement(cstring fieldName, 
                                                           unsigned value) {
    auto lside = new IR::Member(new IR::PathExpression(sharedStructInstArgName), 
                                IR::ID(fieldName));
    auto rside = new IR::Constant(value);
    return new IR::AssignmentStatement(lside, rside);
}


IR::Statement* SlicePipeControl::createIfStatement(cstring lname, unsigned rv, 
                                                   IR::Statement* ifTrue) {
    auto lside = new IR::Member(new IR::PathExpression(sharedStructInstArgName), 
                                IR::ID(lname));
    auto rside = new IR::Constant(rv);
    auto cond = new IR::Equ(lside, rside);
    return new IR::IfStatement(cond, ifTrue, nullptr);
}


IR::Statement* SlicePipeControl::appendStatement(IR::Statement* currStmt, 
                                                 IR::Statement* inStmt) {
    if (inStmt == nullptr)
        return currStmt;
    
    auto bs = new IR::BlockStatement();
    if (currStmt->is<IR::BlockStatement>()) {
        bs->components.append(currStmt->to<IR::BlockStatement>()->components);
        bs->components.push_back(inStmt);
    } else {
        auto bs = new IR::BlockStatement();
        bs->components.push_back(currStmt);
        bs->components.push_back(inStmt);
    }
    return bs;
}

    /*
void SlicePipeControl::identifyUsedDecls(IR::Statement* stmt) {
    auto p4Control = findContext<IR::P4Control>();
    if (p4Control == nullptr)
        return;
    if (!slice  || (slice && stmt == slicedHalf))
        stmt->apply(*getUsedDeclarations);
}

    */

IR::P4Control* SlicePipeControl::createPartitionedP4Control(
                                    const IR::P4Control* orig, 
                                    const IR::BlockStatement* newBody) {

    auto newName = getUniqueControlName(orig->name);
    auto origType = orig->type;
    auto pl = new IR::ParameterList();
    for (auto p : *(origType->getApplyParameters())) {
        auto np = new IR::Parameter(p->name, p->direction, p->type->clone());
        pl->push_back(np);
    }
    /*
    auto p = new IR::Parameter(sharedStructInstArgName, IR::Direction::InOut, 
                                   new IR::Type_Name(sharedStructTypeName));
    pl->push_back(p);
    */
    auto type = new IR::Type_Control(newName, pl);
    auto newP4Control = new IR::P4Control(IR::ID(newName), type, 
        orig->constructorParams->clone(), *(orig->controlLocals.clone()), newBody);
    return newP4Control;
}


cstring SlicePipeControl::getUniqueControlName(cstring prefix) {
    return  prefix +"_"+ cstring::to_cstring(uniqueControlIDGen++);
}




IR::Type_Declaration* SlicePipeControl::createIntermediateDeparser(
    cstring packetOutTypeName, ControlStateReconInfo* info) {

    cstring packetOutPN = "po";
    cstring headerPN = "hdr";
    cstring validityBitMap = "validHdrs";
    auto pl = new IR::ParameterList();
    auto p1 = new IR::Parameter(packetOutPN, IR::Direction::InOut, 
                                new IR::Type_Name(packetOutTypeName));
    auto p2 = new IR::Parameter(headerPN, IR::Direction::In,
                                new IR::Type_Name(info->headerTypeName));
    auto p3 = new IR::Parameter(validityBitMap, IR::Direction::InOut, 
                                info->sharedVariableType);
    pl->push_back(p1); pl->push_back(p2); pl->push_back(p3);
    cstring dn = info->controlName+"_inter_dep";
    auto type = new IR::Type_Control(dn, pl);

    auto p4Control = new IR::P4Control(dn, type, new IR::BlockStatement());
    return p4Control;
}

IR::Type_Declaration* SlicePipeControl::createIntermediateParser(
    cstring packetInTypeName, ControlStateReconInfo* info) {
  
    cstring packetInPN = "pin";
    cstring headerPN = "hdr";
    cstring validityBitMap = "validHdrs";
    auto pl = new IR::ParameterList();
    auto p1 = new IR::Parameter(packetInPN, IR::Direction::InOut,
                                new IR::Type_Name(packetInTypeName));
    auto p2 = new IR::Parameter(headerPN, IR::Direction::Out,
                                new IR::Type_Name(info->headerTypeName));
    auto p3 = new IR::Parameter(validityBitMap, IR::Direction::In,
                                info->sharedVariableType);
    pl->push_back(p1); pl->push_back(p2); pl->push_back(p3);
    cstring pn = info->controlName+"_inter_parser";
    auto type = new IR::Type_Control(pn, pl);

    auto p4Control = new IR::P4Control(pn, type, new IR::BlockStatement());
    return p4Control;
   
}

cstring SlicePipeControl::getSharedStructTypeName(cstring controlTypeName) {
    return "struct_"+controlTypeName+"_t";
}

const IR::Node* PartitionP4Control::preorder(IR::P4Control* p4control) {

    if (*controlTypeName != p4control->getName()) {
        prune();
        return p4control;
    }
    partMap.clear();
    // std::cout<<"Partitioning P4Control "<<p4control->getName()<<"\n";
    cstring sharedStructTypeName = 
        SlicePipeControl::getSharedStructTypeName(p4control->getName());

    SlicePipeControl slicePipeControl(refMap, typeMap, sharedStructTypeName, 
                                      *constraintState, controlToReconInfoMap);
    auto orig = p4control->apply(slicePipeControl);
    partMap = slicePipeControl.getPartitionInfo();

    if (partMap.empty()) {
        //std::cout<<"Partitions empty for P4Control: " 
        //<<p4control->getName()<<"\n";
        partitions->push_back(p4control->getName());
        prune();
        return p4control;
    }

    /*
    // part 1 name
    std::cout<<"Orig "<<orig->getName()<<"\n";
    // original name
    */
    // std::cout<<"p4control "<<p4control->getName()<<"\n";
    auto iter = partMap.find(orig->getName());
    if (iter != partMap.end()) {
        /*
        std::cout<<"part-1 "<<iter->second.partition1->getName()<<"\n";
        std::cout<<"part-2 "<<iter->second.partition2->getName()<<"\n";
        */
        *controlTypeName = iter->second.partition2->getName();
        partitions->push_back(iter->second.partition1->getName());
        partitionsMap->emplace(iter->first, iter->second);
        setNextControlConstraintStates();
    }

    // sharedLocalDeclInsts = slicePipeControl.getSharedDeclarationInstances();
    return p4control;
}

const IR::Node* PartitionP4Control::postorder(IR::P4Program* p4program) {
    
    
    for (auto c : partMap) { 
        /*
        std::cout<<c.second.sharedStructType->getName()<<"\t"
          <<c.second.partition1->getName()<<"\t"
          <<c.second.partition2->getName()<<"\n";
        */
        IR::Vector<IR::Node> vec;
        vec.push_back(c.second.sharedStructType);
        if (c.second.deparser != nullptr)
            vec.push_back(c.second.deparser);
        if (c.second.parser != nullptr)
            vec.push_back(c.second.parser);
        vec.push_back(c.second.partition1);
        vec.push_back(c.second.partition2);
        
        /*
        if (c.first == *controlTypeName) {
            for (auto di : sharedLocalDeclInsts) {
                c.second.partition1->controlLocals.push_back(di->clone());
            }
        }
        */
        auto iter = p4program->objects.begin();
        for (; iter != p4program->objects.end(); iter++) {
            auto node = *iter;
            if (auto p4c = node->to<IR::P4Control>()) {
                if (p4c->getName() == c.second.origControlName) 
                    break;
            }
        }
        BUG_CHECK(iter != p4program->objects.end(), 
            "could not found partitioned control in P4Program");
        iter = p4program->objects.erase(iter);
        p4program->objects.insert(iter, vec.begin(), vec.end());
    }

    return p4program;
}

}// namespace CSA
