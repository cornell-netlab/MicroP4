/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */
#include <algorithm>
#include <cmath>
#include <list>
#include <vector>
#include <unordered_set>
#include "deparserConverter.h"
#include "frontends/p4/coreLibrary.h"
#include "frontends/p4/parserCallGraph.h"
#include "frontends/p4/methodInstance.h"


namespace CSA {

bool isEmitCall(const IR::MethodCallStatement* mcs, P4::ReferenceMap* refMap, 
                P4::TypeMap* typeMap) {
    auto expression = mcs->methodCall;
    P4::MethodInstance* mi = P4::MethodInstance::resolve(expression, refMap, typeMap);
    if (!mi->is<P4::ExternMethod>()) 
        return false;
    auto em = mi->to<P4::ExternMethod>();

    if (em->originalExternType->name.name != P4::P4CoreLibrary::instance.emitter.name 
        || em->method->name.name != P4::P4CoreLibrary::instance.emitter.emit.name)
        return false;

    return true;
}

bool CreateEmitSchedule::preorder(const IR::P4Control* deparser) {
    if (addDummyInit) {
        
        auto mce = new IR::MethodCallExpression(new IR::PathExpression("dmCall"));
        auto mcs = new IR::MethodCallStatement(mce);
        emitCallGraph->add(mcs);
        frontierStack.emplace_back(1, mcs);
    }
    return true;

}

bool CreateEmitSchedule::preorder(const IR::MethodCallStatement* mcs) {
    
    if (!isEmitCall(mcs, refMap, typeMap))
        return false;

    auto orig = getOriginal()->to<IR::MethodCallStatement>();
    emitCallGraph->add(orig);
    if (frontierStack.empty()) 
        frontierStack.emplace_back();
    auto frontier = frontierStack.back();

    if (frontier.empty()) {
        // std::cout<<mcs<<"\n";
        // emitCallGraph->calls(nullptr, orig);
    }

    for (auto e : frontier) {
        // std::cout<<e<<" --> "<<mcs<<"\n";
        emitCallGraph->calls(e, orig);
    }
    frontierStack.emplace_back(1, orig);
    return false;
}

bool CreateEmitSchedule::preorder(const IR::IfStatement* ifStmt) {
    LOG3("preorder ifstatement");
    size_t size = frontierStack.size();

    visit(ifStmt->ifTrue);
    auto trueFront = frontierStack.back();
    while(frontierStack.size() != size)
        frontierStack.pop_back();

    visit(ifStmt->ifFalse);
    auto falseFront = frontierStack.back();
    while(frontierStack.size() != size)
        frontierStack.pop_back();

    trueFront.insert(trueFront.end(), falseFront.begin(), falseFront.end());
    frontierStack.push_back(trueFront);
    return false;
}

bool CreateEmitSchedule::preorder(const IR::SwitchStatement* swStmt) {
	LOG3("preorder switch statement");
    size_t size = frontierStack.size();
    std::vector<const IR::MethodCallStatement*> pushBackStack;

    for (auto sc : swStmt->cases) {
        visit(sc->statement);
        auto caseFront = frontierStack.back();
        pushBackStack.insert(pushBackStack.end(), caseFront.begin(), caseFront.end());
        while(frontierStack.size() != size)
            frontierStack.pop_back();
    }
    frontierStack.push_back(pushBackStack);
    return false;
}



bool DeparserConverter::isDeparser(const IR::P4Control* p4control) {

    auto params = p4control->getApplyParameters();
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

void DeparserConverter::initTableWithOffsetEntries(const IR::MethodCallStatement* mcs) {
    
    auto offsetName = NameConstants::csaPktStuCurrOffsetFName;
    // indicesHeaderInstanceName
    auto ke1 = new IR::Member(new IR::PathExpression(paketOutParamName), 
                              NameConstants::indicesHeaderInstanceName);
    auto ke2 = new IR::Member(ke1, offsetName);
    // auto keyEle = new IR::KeyElement(ke2, new IR::PathExpression("exact"));
    keyElementLists[mcs].emplace_back(ke2, true);

    keyNamesWidths.emplace_back(offsetName, 0);

    std::vector<char> kv;
    kv.push_back('o');
    for (auto os : initialOffsets) {
        IR::Vector<IR::Expression> exprList;
        IR::Vector<IR::Entry> entryList;
        // std::cout<<"initTableWithOffsetEntries an: "<<an<<"\n";
        exprList.push_back(new IR::Constant(os));
        auto keySetExpr = new IR::ListExpression(exprList);
        keyValueEmitOffsets[mcs].emplace_back(keySetExpr, os, nullptr, os);
        headerKeyValues.push_back(kv);
    }
    lastMcsEmitted = mcs;
}


Visitor::profile_t DeparserConverter::init_apply(const IR::Node* node) { 

    auto c = node->to<IR::P4Control>();
    BUG_CHECK(c != nullptr, 
        "DeparserConverter should be applied on P4Control type nodes only");
    if (hdrVOPType == nullptr)
        BUG_CHECK(xoredValidityOps == nullptr, 
            "for not null xoredValidityOps, hdrVOPType can not be null");
    return Transform::init_apply(node);
}


const IR::Node* DeparserConverter::preorder(IR::P4Control* deparser) {
    LOG3("preorder p4control"<< deparser->name.name);
    if (!isDeparser(deparser)) {
        prune();
        return deparser;
    }
    auto param = deparser->getApplyParameters()->getParameter(1);
    paketOutParamName = param->name.name;

    emitCallGraph = new EmitCallGraph(deparser->name.name);

    bool init = false;
    if (!(initialOffsets.size() == 1 && initialOffsets[0] == 0))
        init = true;
    CreateEmitSchedule createEmitSchedule(refMap, typeMap, emitCallGraph, init);
    deparser->apply(createEmitSchedule);

    std::vector<const IR::MethodCallStatement*> sorted;
    emitCallGraph->sort(sorted);
    std::reverse(std::begin(sorted), std::end(sorted));

    if (init) {
        initTableWithOffsetEntries(sorted[0]);
        sorted.erase(sorted.begin());
    }

    for (auto emit : sorted)
        createID(emit);


    return deparser;
}


const IR::Node* DeparserConverter::postorder(IR::Parameter* param) {
    
    auto deparser = findContext<IR::Type_Control>();
    if (deparser == nullptr)
        return param;
    
    auto type = typeMap->getTypeType(param->type, false);

    if (type->is<IR::Type_Struct>()) {
        
        auto iv = new IR::IndexedVector<IR::Parameter>();
        iv->push_back(param);
        if (parserMSAMetaStrTypeName != "") {
            auto npp = new IR::Parameter(
                IR::ID(NameConstants::parserMetaStrParamName), 
                IR::Direction::In, new IR::Type_Name(parserMSAMetaStrTypeName));
            iv->push_back(npp);
        }

        if (hdrVOPType != nullptr) {
            auto np = new IR::Parameter(
                IR::ID(NameConstants::headerValidityOpStrParamName), 
                IR::Direction::In, new IR::Type_Name(hdrVOPType->name));
            iv->push_back(np);
        }
        return iv;
    }


    if (!type->is<IR::Type_Extern>()) {
        return param;
    }
    
    auto te = type->to<IR::Type_Extern>();
    if (te->name.name == P4::P4CoreLibrary::instance.emitter.name)
        return nullptr;

    if (te->name.name == P4::P4CoreLibrary::instance.pkt.name) {
        auto np = new IR::Parameter(param->srcInfo, IR::ID(param->name.name), 
            IR::Direction::InOut, new IR::Type_Name(
                                        NameConstants::csaPacketStructTypeName));
        return np;
    }

    return param;
}


const IR::Node* DeparserConverter::postorder(IR::P4Control* deparser) {
    /*
    if (hdrVOPType != nullptr)
        std::cout<<"postorder Deparser Converter"<< hdrVOPType->name << "\n";
    */


    auto& controlLocals = deparser->controlLocals;
    controlLocals.append(varDecls);

    std::vector<const IR::MethodCallStatement*> sorted;
    emitCallGraph->sort(sorted);
    std::reverse(std::begin(sorted), std::end(sorted));
    
    auto iter = actionDecls.find(sorted[0]);
    if (iter != actionDecls.end()) 
        controlLocals.append(actionDecls[sorted[0]]);
    // std::cout<<"sorted size "<<sorted.size()<<"\n";
    for (unsigned i = 1; i<sorted.size(); i++) {
        for (auto a : actionDecls[sorted[i]]) {
            if (controlLocals.getDeclaration(a->name) == nullptr)
                controlLocals.push_back(a);
        }
    }

    controlLocals.append(tableDecls);
    

    varDecls.clear();
    tableDecls.clear();
    keyElementLists.clear();
    actionDecls.clear();
    emitIds.clear();
    controlVar.clear();
    keyElementLists.clear();
    keyValueEmitOffsets.clear();
    LOG3("return deparser");
    return deparser;
}

const IR::Node* DeparserConverter::preorder(IR::MethodCallStatement* methodCallStmt) {
	  LOG3("preorder method call statement" <<methodCallStmt);
    auto mcs = getOriginal()->to<IR::MethodCallStatement>();

    if (!isEmitCall(methodCallStmt, refMap, typeMap))
        return methodCallStmt;

    // std::cout<<"preorder MethodCallStatement: "<<mcs<<"\n";
    /*
    for (auto& callee : (*emitCallGraph->getCallees(mcs))) {
        auto callers = emitCallGraph->getCallers(callee);
        if (callers->size() > 1) {
            cstring varName = emitIds[mcs]+"_cg_var";
            auto boolType = IR::Type_Boolean::get();
            auto declVar = new IR::Declaration_Variable(varName, boolType,
                                                    new IR::BoolLiteral(false)); 
            varDecls.push_back(declVar);
            auto cva = new IR::AssignmentStatement(new IR::PathExpression(varName), 
                                                   new IR::BoolLiteral(true));
            IR::IndexedVector<IR::StatOrDecl> actionBlockStatements;
            actionBlockStatements.push_back(cva);
            auto actionBlock = new IR::BlockStatement(actionBlockStatements);
            cstring actionName = varName+"_set";
            auto action = new IR::P4Action(actionName, 
                                           new IR::ParameterList(), actionBlock);
            actionDecls[mcs].push_back(action);
            controlVar.emplace(mcs, std::make_pair(varName, actionName));
            break;
        }
    }
    */
    IR::P4Table* p4Table = nullptr;

    // The first emit statement. It has no callers. No one calls it.
    if (!emitCallGraph->isCallee(mcs)) {
        // std::cout<<"Converting --> "<<methodCallStmt<<" to table\n";
        p4Table = createEmitTable(mcs);

    } else { // The emit mcs called by exactly one caller
        auto callers = emitCallGraph->getCallers(mcs);
        if (callers->size() == 1){
            p4Table = extendEmitTable(mcs, (*callers)[0]);
            LOG3("extendEmit table "<< emitIds[mcs]<< " with "<< emitIds[(*callers)[0]]);
         //} else if ( callers->size() > 1){
          //  p4Table = mergeAndExtendEmitTables(tableDecls[0]->to<IR::P4Table>(), mcs, callers);
          //  LOG3("merge and extendEmit table "<< emitIds[mcs]);
        } else {
            // size can not be 0;
        }
    }
    if (p4Table) {
        return nullptr;
    }
    LOG3("returning methodcall stmt ");
    return methodCallStmt;
}

const IR::Node* DeparserConverter::postorder(IR::BlockStatement* bs) {

    if (xoredValidityOps != nullptr) {
        auto mced = new IR::MethodCallExpression(
            new IR::PathExpression("hdrValidityOPDummyCall"));
        auto mcsd = new IR::MethodCallStatement(mced);
        // printHeaderKeyValues();
        createHdrValidityOpsKeysNames(mcsd);
        if (hdrOpKeyNames.size() > 0) {
            createHdrValidityOpsKeysValues();
            auto p4table = multiplyHdrValidityOpsTable(mcsd);
        }
    }

    if (tableDecls.size() != 1)
        return bs;
    auto p4Table = tableDecls[0];
    auto method = new IR::Member(new IR::PathExpression(p4Table->name.name), IR::ID("apply"));
    auto mce = new IR::MethodCallExpression(method, new IR::Vector<IR::Argument>());
    auto tblApplyMCS = new IR::MethodCallStatement(mce);
    bs->push_back(tblApplyMCS);
    return bs;
}


IR::P4Table* DeparserConverter::createEmitTable(const IR::MethodCallStatement* mcs) {
    unsigned width;
    unsigned offset = 0;
    IR::Vector<IR::KeyElement> keyElementList;
    IR::IndexedVector<IR::ActionListElement> actionListElements;
    IR::Vector<IR::Entry> entries;

    cstring hdrInstName;
    // std::cout<<__func__<<": creating key\n";
    auto exp = getArgHeaderExpression(mcs, width, hdrInstName);
    /*
    if (auto hn = exp->to<IR::Member>()){
        hdrInstName = hn->member.name;
        keyNamesWidths.emplace_back(hn->member.name, width);
    } else if (auto hn = exp->to<IR::PathExpression>()) {
        hdrInstName = hn->path->name;
        keyNamesWidths.emplace_back(hn->path->name, width);
    }
    */
    
    keyNamesWidths.emplace_back(hdrInstName, width);

    hdrMCSMap[hdrInstName] = mcs;

    lastMcsEmitted = mcs;
    auto hdrKVVecSizeInit = headerKeyValues.size();
    auto hdrKVVecSize = ((hdrKVVecSizeInit == 0)? 1: hdrKVVecSizeInit); 
    size_t hdrKVVecIndex = 0;
    resizeReplicateKeyValueVec(2);

    cstring hdrValidFlagName = hdrInstName + NameConstants::hdrValidFlagSuffix;
    auto newMember = new IR::Member(
              new IR::PathExpression(NameConstants::parserMetaStrParamName), 
              IR::ID(hdrValidFlagName));

    // auto newMember = new IR::Member(exp->clone(), IR::Type_Header::isValid);
    // auto mce = new IR::MethodCallExpression(newMember);

    auto hdrEmitKey = new IR::KeyElement(newMember, new IR::PathExpression("exact"));
    keyElementList.push_back(hdrEmitKey);
    keyElementLists[mcs].emplace_back(exp, true);

    // std::cout<<__func__<<": creating entry with 0\n";

    IR::Vector<IR::Expression> simpleExpressionList;
    //IR::Expression* e0 = new IR::Constant(0, 2);
    IR::Expression* e0 = new IR::BoolLiteral(false);
    simpleExpressionList.insert(simpleExpressionList.begin(), e0);
    auto kse0 = new IR::ListExpression(simpleExpressionList);
    keyValueEmitOffsets[mcs].emplace_back(kse0, offset, nullptr, offset);
    insertValueKeyValueVec('f', hdrKVVecIndex, hdrKVVecIndex+hdrKVVecSize);
    hdrKVVecIndex += hdrKVVecSize;

    auto iter = controlVar.find(mcs);
    if (iter != controlVar.end()) {
        auto notEmittedName = iter->second.second;
        auto actionBinding0 = new IR::MethodCallExpression(
                                      new IR::PathExpression(notEmittedName), 
                                      new IR::Vector<IR::Type>(), 
                                      new IR::Vector<IR::Argument>());
        auto entry0 = new IR::Entry(kse0, actionBinding0);  
        auto actionRef0 = new IR::ActionListElement(actionBinding0->clone());
        actionListElements.push_back(actionRef0);
        entries.push_back(entry0);
    }

    // std::cout<<__func__<<": creating entry with 1\n";
    simpleExpressionList.clear();
    //IR::Expression* e1 = new IR::Constant(1, 2);
    IR::Expression* e1 = new IR::BoolLiteral(true);
    simpleExpressionList.insert(simpleExpressionList.begin(), e1);
    auto kse1 = new IR::ListExpression(simpleExpressionList);
    auto emitAct = createP4Action(mcs, offset);
    actionDecls[mcs].push_back(emitAct);
    
    auto actionBinding1 = new IR::MethodCallExpression(
        new IR::PathExpression(emitAct->getName()), 
        new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
    auto entry1 = new IR::Entry(kse1, actionBinding1);
    keyValueEmitOffsets[mcs].emplace_back(kse1, offset, emitAct, offset);
    insertValueKeyValueVec('t', hdrKVVecIndex, hdrKVVecIndex+hdrKVVecSize);
    hdrKVVecIndex += hdrKVVecSize;

    auto actionRef1 = new IR::ActionListElement(actionBinding1->clone());
    actionListElements.push_back(actionRef1);
    auto noActMCE = new IR::MethodCallExpression(
                          new IR::PathExpression(noActionName), 
                          new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
    auto noActionRef = new IR::ActionListElement(noActMCE);
    actionListElements.push_back(noActionRef);


    entries.push_back(entry1);

    auto key = new IR::Key(keyElementList);
    auto actionList = new IR::ActionList(actionListElements);
    auto entriesList = new IR::EntriesList(entries);

    // std::cout<<__func__<<": creating IR::P4Table\n";
    auto p4Table = createP4Table(emitIds[mcs], key, actionList, entriesList);
    return p4Table;
}


IR::P4Table* DeparserConverter::extendEmitTable(const IR::MethodCallStatement* mcs,
                                                const IR::MethodCallStatement* 
                                                    predecessor) {
    unsigned width;
    IR::IndexedVector<IR::ActionListElement> actionListElements;
    IR::IndexedVector<IR::Declaration> refdActs;
    IR::Vector<IR::Entry> entries;
    cstring hdrInstName;
    auto exp = getArgHeaderExpression(mcs, width, hdrInstName);

    /*
    if (auto hn = exp->to<IR::Member>()){
        hdrInstName = hn->member.name;
        keyNamesWidths.emplace_back(hn->member.name, width);
    } else if (auto hn = exp->to<IR::PathExpression>()) {
        hdrInstName = hn->path->name;
        keyNamesWidths.emplace_back(hn->path->name, width);
    }
    */
    keyNamesWidths.emplace_back(hdrInstName, width);
    hdrMCSMap[hdrInstName] = mcs;

    std::vector<std::pair<const IR::Expression*, bool>> keyExp(keyElementLists[predecessor]);
    keyExp.emplace_back(exp, true);
    keyElementLists[mcs] = keyExp;

    auto nameStrVec = keyExpToNameStrVec(keyExp);

    lastMcsEmitted = mcs;
    auto hdrKVVecSize = headerKeyValues.size();
    BUG_CHECK(hdrKVVecSize == keyValueEmitOffsets[predecessor].size(), 
        "headerKeyValues size = %1% != keyValueEmitOffsets size = %2%, in %3%",
        hdrKVVecSize, keyValueEmitOffsets[predecessor].size(), mcs);

    /*
    std::cout<<"init  extendEmitTable\n   ";
    printHeaderKeyValues();
    */
    resizeReplicateKeyValueVec(2);

    /*
    std::cout<<mcs<<"\n";
    std::cout<<hdrInstName<<"\n";
    */
    for (unsigned i=0; i<2; i++) {
        size_t en = 0;
        for (auto ele : keyValueEmitOffsets[predecessor]) {
            auto hdrKVVecIndex = hdrKVVecSize * i + en;
            en++;

            IR::ListExpression* ls = std::get<0>(ele)->clone();
            auto currentEmitOffset = std::get<1>(ele);
            auto action = std::get<2>(ele);
            auto initOffset = std::get<3>(ele);

            IR::Expression* e = (i==0)?	new IR::BoolLiteral(false):
                                        new IR::BoolLiteral(true);
            ls->components.push_back(e);

            if (i==1) {
                if (emitsXORedHdrs(nameStrVec, ls)) {
                    headerKeyValues[hdrKVVecIndex].clear();
                    continue;
                }
                if (!isParsableHeader(hdrInstName)) {
                    // std::cout<<"skipping "<<hdrInstName<<" 1 \n";
                    // std::cout<<hdrKVVecIndex<<"\n";
                    headerKeyValues[hdrKVVecIndex].clear();
                    continue;
                }
                auto emitAct = createP4Action(mcs,currentEmitOffset, action);
                // if (actionDecls[mcs].getDeclaration(emitAct->getName()) == nullptr)
                actionDecls[mcs].push_back(emitAct);
                auto actionBinding = new IR::MethodCallExpression(
                              new IR::PathExpression(emitAct->name),
                              new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
                auto entry0 = new IR::Entry(ls, actionBinding);
                entries.push_back(entry0);
                keyValueEmitOffsets[mcs].emplace_back(ls, currentEmitOffset, emitAct, initOffset);
                headerKeyValues[hdrKVVecIndex].push_back('t');

            } else {
                if (action != nullptr) {
                    auto actionBinding = new IR::MethodCallExpression(
                              new IR::PathExpression(action->name),
                              new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
                    auto entry0 = new IR::Entry(ls, actionBinding);
                    entries.push_back(entry0);
                    auto a = refdActs.getDeclaration(action->getName());
                    if (a == nullptr)
                        refdActs.push_back(action);
                }
                keyValueEmitOffsets[mcs].emplace_back(ls, currentEmitOffset, action, initOffset);
                headerKeyValues[hdrKVVecIndex].push_back('f');
            }
        }
    }

    // printHeaderKeyValues();
    removeEmptyElementsKeyValueVec();
    // printHeaderKeyValues();

    // refdActs.append(actionDecls[mcs]);
    for (auto ad : actionDecls[mcs]) {
        if (refdActs.getDeclaration(ad->getName()) == nullptr)
              refdActs.push_back(ad);
    }

    for (const auto& aIdecl : refdActs) {
        auto amce = new IR::MethodCallExpression(
                            new IR::PathExpression(aIdecl->name.name), 
                            new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
        auto actionRef = new IR::ActionListElement(amce);
        // std::cout<<"Action Name: "<<aIdecl->name.name<<"\n";
        actionListElements.push_back(actionRef);
    }


    auto amce = new IR::MethodCallExpression(new IR::PathExpression(noActionName), 
                                             new IR::Vector<IR::Type>(), 
                                             new IR::Vector<IR::Argument>());
    auto actionRef = new IR::ActionListElement(amce);
    actionListElements.push_back(actionRef);


    auto key = createKey(mcs);
    auto actionList = new IR::ActionList(actionListElements);
    auto entriesList = new IR::EntriesList(entries);
    auto p4Table = createP4Table(emitIds[mcs], key, actionList, entriesList);
    return p4Table;
}

std::vector<cstring> DeparserConverter::keyExpToNameStrVec(
                      std::vector<std::pair<const IR::Expression*, bool>>& ke) {

    std::vector<cstring> vec;
    unsigned i = 0;
    for (const auto& ele : ke) {
        auto mem = ele.first->to<IR::Member>();
        if (mem != nullptr)  {
            auto type = typeMap->getType(mem, false);
            if (type != nullptr && type->is<IR::Type_Header>()) {
                // std::cout<<mem->member.name<<"\n";
                vec.push_back(mem->member.name);
            } else {
                vec.push_back(cstring::to_cstring(i++));
            }
        } else {
            vec.push_back(cstring::to_cstring(i++));
        }
    }

    return vec;
}

bool DeparserConverter::emitsXORedHdrs(const std::vector<cstring>& vec, 
                                       const IR::ListExpression* ls) {

    BUG_CHECK(vec.size() == ls->components.size(), 
        "list expression size does not match key size %1% != %2%", 
        vec.size(), ls->components.size());
    size_t in = 0;
    std::vector<cstring> validHdr;
    for (const auto exp : ls->components) {
        auto bl = exp->to<IR::BoolLiteral>();
        if (bl != nullptr) {
            if (bl->value) {
                validHdr.push_back(vec[in]);
            }
        }
        in++;
    }

    for (const auto& xoredHeaderSet : (*xoredHeaderSets)) {
        unsigned numValidHdr = 0;
        for (const auto& hdr : validHdr) {
            if (xoredHeaderSet.count(hdr) > 0)
                numValidHdr++;
        }
        if (numValidHdr > 1)
            return true;
    }
    return false;
}

bool DeparserConverter::isParsableHeader(cstring hdr) {
    
    
    if (parsedHeaders == nullptr)
        return true;
    /*
    std::cout<<"parsedHeaders ---"<<"\n";
    for (auto s : *parsedHeaders)
        std::cout<<s<<"\n";
    std::cout<<"\n-----------------\n";
    */

    if (parsedHeaders->find(hdr) == parsedHeaders->end())
        return false;
    else
        return true;
    
}

IR::Key* DeparserConverter::createKey(const IR::MethodCallStatement* mcs) {
    
    IR::Vector<IR::KeyElement> keyElementList;
    auto vec = keyElementLists[mcs];
    for (auto ele : vec) {
        bool mt = ele.second;
        auto type = typeMap->getType(ele.first);
        auto exp = ele.first->clone();
        IR::Expression* keyExp = nullptr;
        if (type != nullptr && type->is<IR::Type_Header>()){
            
            cstring hdrInstName = "";
            if (auto hnm = exp->to<IR::Member>())
                hdrInstName = hnm->member.name;
            if (auto hnpe = exp->to<IR::PathExpression>())
                hdrInstName = hnpe->path->name;

            cstring hdrValidFlagName = hdrInstName + NameConstants::hdrValidFlagSuffix;
            keyExp = new IR::Member(
                new IR::PathExpression(NameConstants::parserMetaStrParamName), 
                IR::ID(hdrValidFlagName));
            // auto member = new IR::Member(exp, IR::Type_Header::isValid);
            // keyExp = new IR::MethodCallExpression(member);

        } else {
            keyExp = exp;
        }
        auto hdrEmitKey = new IR::KeyElement(keyExp, new IR::PathExpression(
                                                      mt?"exact":"ternary"));
        keyElementList.push_back(hdrEmitKey);
    }
    return new IR::Key(keyElementList);
}


IR::P4Action* DeparserConverter::createP4Action(const IR::MethodCallStatement* mcs,
                                      unsigned& currentEmitOffset, 
                                      const IR::P4Action* ancestorAction) {

    auto p4Action = createP4Action(mcs, currentEmitOffset);
    if (ancestorAction == nullptr) 
        return p4Action;

    if (actionDecls[mcs].getDeclaration(p4Action->name.name) == nullptr)
        actionDecls[mcs].push_back(p4Action);

    IR::IndexedVector<IR::StatOrDecl> actionBlockStatements;
    cstring actName = ancestorAction->name.name+"_"+p4Action->name.name;

    auto mce = new IR::MethodCallExpression(
          new IR::PathExpression(p4Action->name), 
          new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
    auto ms = new IR::MethodCallStatement(mce);
    actionBlockStatements.push_back(ms);

    mce = new IR::MethodCallExpression(
        new IR::PathExpression(ancestorAction->name), 
        new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
    ms= new IR::MethodCallStatement(mce);
    actionBlockStatements.push_back(ms);

    auto actionBlock = new IR::BlockStatement(actionBlockStatements);
    p4Action = new IR::P4Action(actName, new IR::ParameterList(), actionBlock);
    return p4Action;
}


IR::P4Action* DeparserConverter::createP4Action(const IR::MethodCallStatement* mcs, 
                                          unsigned& currentEmitOffset) {
    
    unsigned width = 0;
    unsigned emitOffset = 0;
    cstring hdrInstName;
    auto e = getArgHeaderExpression(mcs, width, hdrInstName);
    IR::IndexedVector<IR::StatOrDecl> actionBlockStatements;

    auto exp = new IR::Member(new IR::PathExpression(paketOutParamName), 
                                 IR::ID(NameConstants::csaHeaderInstanceName));
    // auto member = new IR::Member(exp, IR::ID("data"));
    cstring name;
    if (e->is<IR::Member>()) 
        name = e->to<IR::Member>()->member;
    else 
        name = e->toString();

    emitOffset = currentEmitOffset + width;
    name += "_"+cstring::to_cstring(currentEmitOffset/8) + 
            "_"+ cstring::to_cstring(emitOffset/8);

    auto mcsActions = actionDecls[mcs];

    const IR::IDeclaration* actionDecl = mcsActions.getDeclaration(name);
    if (actionDecl != nullptr) {
        return const_cast<IR::P4Action*>(actionDecl->to<IR::P4Action>());
    }

    
    auto type = typeMap->getType(e);
    BUG_CHECK(type->is<IR::Type_Header>(), "expected header type ");
    auto th = type->to<IR::Type_Header>();

    unsigned start = currentEmitOffset;
    for (auto f : th->fields) {
        auto w = symbolicValueFactory->getWidth(f->type);
        unsigned startByteIndex = start/8;
        // unsigned startByteBitIndex = start % 8;
        unsigned startByteBitIndex = 8-(start % 8);
        
        start += w;
        unsigned fwCounter = 0; // field width counter
        // if (startByteBitIndex != 0) {
        if (8-startByteBitIndex != 0) {
            auto bl = new IR::ArrayIndex(exp->clone(), 
                                         new IR::Constant(startByteIndex));
            auto member = new IR::Member(bl, IR::ID("data"));

            const IR::Expression* initSlice = nullptr;
            const IR::Expression* rh = nullptr;
            // if ((8-startByteBitIndex) <= w) {
            if (startByteBitIndex <= w) {
                // initSlice = IR::Slice::make(member, startByteBitIndex, 7);
                initSlice = IR::Slice::make(member, 0, startByteBitIndex-1);
                // fwCounter += (8-startByteBitIndex);
                fwCounter += startByteBitIndex;
                auto rMem = new IR::Member(e->clone(), IR::ID(f->getName()));
                // rh = IR::Slice::make(rMem, w-(8-startByteBitIndex), w-1);
                rh = IR::Slice::make(rMem, w-startByteBitIndex, w-1);
                // w = w-(8-startByteBitIndex);
                w = w-startByteBitIndex;
            } else {
                // initSlice = IR::Slice::make(member, startByteBitIndex, 
                //                            startByteBitIndex+w-1);
                initSlice = IR::Slice::make(member, startByteBitIndex-w, 
                                            startByteBitIndex-1);
                rh = new IR::Member(e->clone(), IR::ID(f->getName()));
                w = 0;
            }
            startByteIndex++;
            auto as = new IR::AssignmentStatement(initSlice, rh);
            actionBlockStatements.push_back(as);
        }
        while (w >= 8) {
            auto pe = new IR::ArrayIndex(exp->clone(), 
                                         new IR::Constant(startByteIndex++));
            auto lh = new IR::Member(pe, IR::ID("data"));
            auto rMem = new IR::Member(e->clone(), IR::ID(f->getName()));
            auto rh = IR::Slice::make(rMem, w-8, w-1);
            auto as = new IR::AssignmentStatement(lh, rh);
            actionBlockStatements.push_back(as);
            w -=8;
        }
        if (w != 0) {
            auto bl = new IR::ArrayIndex(exp->clone(), 
                                         new IR::Constant(startByteIndex));
            auto lh = new IR::Member(bl, IR::ID("data"));
            // auto endSlice = IR::Slice::make(lh, 0, w-1);
            auto endSlice = IR::Slice::make(lh, 8-w, 7);
            auto rMem = new IR::Member(e->clone(), IR::ID(f->getName()));
            auto rh = IR::Slice::make(rMem, 0, w-1);
            auto as = new IR::AssignmentStatement(endSlice, rh);
            actionBlockStatements.push_back(as);
        }
    }

    
    currentEmitOffset = start;

    auto it = controlVar.find(mcs);
    if (it != controlVar.end()) {
        auto cva = new IR::AssignmentStatement(
                        new IR::PathExpression(it->second.first), 
                        // new IR::Constant(1, 2));
                        new IR::BoolLiteral(true));
        actionBlockStatements.push_back(cva);
    }
    auto actionBlock = new IR::BlockStatement(actionBlockStatements);
    auto action = new IR::P4Action(name, new IR::ParameterList(), actionBlock);
    return action;
}

IR::P4Table* DeparserConverter::createP4Table(cstring name, IR::Key* key, 
                                              IR::ActionList* al, 
                                              IR::EntriesList* el) {

    IR::IndexedVector<IR::Property> tablePropertyList;
    auto keyElementListProperty = new IR::Property(IR::ID("key"), key, false);
    tablePropertyList.push_back(keyElementListProperty);

    auto actionListProperty = new IR::Property(IR::ID("actions"), al, false);
    tablePropertyList.push_back(actionListProperty);

    auto entriesListProperty = new IR::Property(IR::ID("entries"), el, true);
    tablePropertyList.push_back(entriesListProperty);

    auto v = new IR::ExpressionValue(new IR::MethodCallExpression(
                                            new IR::PathExpression(noActionName), 
                                            new IR::Vector<IR::Argument>()));

    auto defaultActionProp = new IR::Property(IR::ID("default_action"), v, true);
    tablePropertyList.push_back(defaultActionProp);


    auto table = new IR::P4Table(IR::ID(tableName), new IR::TableProperties(tablePropertyList));
    if(tableDecls.size()){
    	LOG3("clearing table ");
    	tableDecls.clear();
    }
    tableDecls.push_back(table);
    return table;
}


const IR::Expression* 
DeparserConverter::getArgHeaderExpression(const IR::MethodCallStatement* mcs, 
                                          unsigned& width,
                                          cstring& hdrInstName) {
    auto expression = mcs->methodCall;
    auto arg0 = expression->arguments->at(1);
    auto argType = typeMap->getType(arg0, true);
    width = symbolicValueFactory->getWidth(argType);

    if (auto hn = arg0->expression->to<IR::Member>()){
        hdrInstName = hn->member.name;
        hdrSizeByInstName[hn->member.name] = width;
    } else if (auto hn = arg0->expression->to<IR::PathExpression>()) {
        hdrInstName = hn->path->name;
        hdrSizeByInstName[hn->path->name] = width;
    }

    return arg0->expression;
}

void DeparserConverter::createID(const IR::MethodCallStatement* emitStmt) {

    unsigned i = 0;
    cstring hdrInstName;
    auto exp = getArgHeaderExpression(emitStmt, i, hdrInstName);
    auto mem = exp->to<IR::Member>();
    i = 0;
    bool flag = true;
    std::string id;
    while (flag) {
        flag = false;
        id = "emit_"+hdrInstName+"_"+std::to_string(i);
        for (const auto& kv : emitIds) {
            if (kv.second == id) {
                i++; flag = true; break;
            }
        }
    }
    emitIds.emplace(emitStmt, cstring(id));
}


void DeparserConverter::resizeReplicateKeyValueVec(size_t nfold) {
    auto s = headerKeyValues.size();
    headerKeyValues.resize((s == 0? 1:s) * nfold);

    for (size_t i = 0; i<s; i++) {
        for (size_t n = 1; n<nfold; n++){
            headerKeyValues[i+(n*s)] = headerKeyValues[i];
        }
    }
}


void DeparserConverter::insertValueKeyValueVec(char v, size_t begin, size_t end) { 
    for (size_t i = begin; i<end; i++)
        headerKeyValues[i].push_back(v);
}


void DeparserConverter::removeEmptyElementsKeyValueVec() {
    headerKeyValues.erase(
        std::remove_if(headerKeyValues.begin(), headerKeyValues.end(),
          [](std::vector<char> x){return x.size() == 0;}),
        headerKeyValues.end());
}


void DeparserConverter::printHeaderKeyValues() {
    
    std::cout<<"Printing printHeaderKeyValues----";
    for (auto cv : headerKeyValues) {
    std::cout<<"\n";
        for (auto ch : cv) {
            std::cout<<ch<<" ";
        }
    }
    std::cout<<"\n---------------------------------\n";
}


void DeparserConverter::printEIMvOsHdr(const std::vector<
                                DeparserConverter::CurrOSMoveOSHdr>& v) {
    for (auto d : v) {
        auto ei = std::get<0>(d);
        auto mo = std::get<1>(d);
        auto hn = std::get<2>(d);
        std::cout<<"["<<ei/8<<" "<<mo/8<<" "<<hn<<"]";
    }
}

void DeparserConverter::createHdrValidityOpsKeysNames(
                                      const IR::MethodCallStatement* dummyMCS) {
    std::unordered_set<cstring> svOphdrs;
    std::unordered_set<cstring> sivOphdrs;



    for (const auto& e : *xoredValidityOps) {
        for (const auto& svset : e.first)
            svOphdrs.insert(svset);
        for (const auto& sivset : e.second)
            sivOphdrs.insert(sivset);
    }
    for (auto h : svOphdrs)
        hdrOpKeyNames.emplace_back(h, true);
    for (auto h : sivOphdrs)
        hdrOpKeyNames.emplace_back(h, false);

    if (hdrOpKeyNames.size() == 0)
        return;
    /*
    std::cout<<" All  ops on \n";
    for (auto h : hdrOpKeyNames)
        std::cout<<"["<<h.first<<","<<h.second<<"]"<<" ";
    std::cout<<"\n-------------\n";
    */

    std::vector<std::pair<const IR::Expression*, bool>> 
                  keyExp(keyElementLists[lastMcsEmitted]);
    auto pe = new IR::PathExpression(IR::ID(hdrVOPTypeParamName));
    for (auto n : hdrOpKeyNames) {
        cstring fn = n.first + (n.second ? 
            NameConstants::hdrSetValidOpFlagSuffix :
            NameConstants::hdrSetInvalidOpFlagSuffix);
        
        auto bitType = IR::Type_Boolean::get();
        auto f = new IR::StructField(IR::ID(fn), bitType);
        if (hdrVOPType->fields.getDeclaration(f->name) == nullptr)
            hdrVOPType->fields.push_back(f);
        
        auto exp = new IR::Member(pe->clone(), IR::ID(fn));
        keyExp.emplace_back(exp, true);

        cstring fnInverse = n.first + (n.second ? 
            NameConstants::hdrSetInvalidOpFlagSuffix 
            : NameConstants::hdrSetValidOpFlagSuffix);
        auto bitTypeInverse = IR::Type_Boolean::get();
        auto fInverse = new IR::StructField(IR::ID(fnInverse), bitTypeInverse);
        if (hdrVOPType->fields.getDeclaration(fInverse->name) == nullptr)
            hdrVOPType->fields.push_back(fInverse);


    }
    keyElementLists[dummyMCS] = keyExp;
}

void DeparserConverter::createHdrValidityOpsKeysValues() {

    for (const auto& e : *xoredValidityOps) {
        std::vector<char> kv;
        for (const auto& p : hdrOpKeyNames) {
            const std::unordered_set<cstring>* hdrOpSet = nullptr;
            if (p.second)
                hdrOpSet = &(e.first);
            else
                hdrOpSet = &(e.second);
            auto it = hdrOpSet->find(p.first);
            if (it != hdrOpSet->end())
                kv.push_back('t');
            else
                kv.push_back('f');
        }
        hdrValidityOpKeyValues.push_back(kv);
    }


}

IR::P4Table* DeparserConverter::multiplyHdrValidityOpsTable(
                                    const IR::MethodCallStatement* dummyMCS) {

    // BUG_CHECK(headerKeyValues[i].size() == keyNamesWidths.size(), 
    //     "value list size does not match with number of keys");


    emitCallGraph->calls(lastMcsEmitted, dummyMCS);

    IR::Vector<IR::Entry> entries;
    IR::IndexedVector<IR::ActionListElement> actionListElements;

    std::vector<EntryContext> finalKeyValueEmitOffsetsActions;
    auto kvEmitOffsets = keyValueEmitOffsets[lastMcsEmitted];

    std::vector<CurrOSMoveOSHdr> emitData;
    std::unordered_map<cstring, size_t> keyIndexMap;
    for (size_t i = 0; i < keyNamesWidths.size(); i++)
        keyIndexMap.emplace(keyNamesWidths[i].first, i);

    for (size_t m = 0; m < hdrValidityOpKeyValues.size(); m++) {
        for (size_t i=0; i<headerKeyValues.size(); i++) {
            int moveOffset = 0;
            auto currOffset = std::get<3>(kvEmitOffsets[i]);
            emitData.clear();
            for (size_t j = 0; j<keyNamesWidths.size(); j++) {
                char value = headerKeyValues[i][j];
                unsigned width = keyNamesWidths[j].second;
                
                // std::cout<<"--Name : "<<keyNamesWidths[j].first
                //   <<"-- width : "<<keyNamesWidths[j].second/8<<"\n";
                bool setValid = false;
                bool setInvalid = false;
                for (size_t n = 0; n < hdrOpKeyNames.size(); n++) { 
                    auto hn = hdrOpKeyNames[n].first;
                    bool op = hdrOpKeyNames[n].second;
                    auto opValue = hdrValidityOpKeyValues[m][n];
                    
                    if (hn != keyNamesWidths[j].first)
                        continue;
                    if (op && opValue == 't' && value == 'f' ) {
                        setValid = true;
                        break;
                    }
                    if (!op && opValue == 't' && value == 't') {
                        moveOffset -= width;
                        setInvalid = true;
                        break;
                    }
                }
                if (setValid) {
                    emitData.emplace_back(currOffset+moveOffset, 0, keyNamesWidths[j].first);
                    moveOffset += width;
                    continue;
                }
                if (value == 't') {
                    if (!setInvalid)
                        emitData.emplace_back(currOffset, moveOffset, keyNamesWidths[j].first);
                    currOffset += width;
                    continue;
                }
            }
  
            /*
            std::cout<<"\n ------ Entry information ------- \n";
            for (auto hk : keyNamesWidths)
                std::cout<<"|"<<hk.first<<"|";
            std::cout<<"----";
            for (auto opk : hdrOpKeyNames)
                std::cout<<"|"<<opk.first<<"("<<opk.second<<")"<<"|";
            std::cout<<"\n";
            for (auto k : headerKeyValues[i])
                std::cout<<"|"<<k<<"|";
            std::cout<<"----";
            for (auto opkv : hdrValidityOpKeyValues[m])
                std::cout<<"|"<<opkv<<"|";
            std::cout<<"\n ----------------------------------- \n";
            */
            auto ec = extendEntry(dummyMCS, kvEmitOffsets[i], 
                hdrValidityOpKeyValues[m], emitData, moveOffset, currOffset);
            auto ls = std::get<0>(ec);
            auto emitAct = std::get<2>(ec);
            auto actionBinding = new IR::MethodCallExpression(
                new IR::PathExpression(emitAct->name),
                new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
            auto entry0 = new IR::Entry(ls, actionBinding);
            entries.push_back(entry0);

        }
    }

    for (const auto& aIdecl : actionDecls[dummyMCS]) {
        auto amce = new IR::MethodCallExpression(
            new IR::PathExpression(aIdecl->name.name), 
            new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
        auto actionRef = new IR::ActionListElement(amce);
        // std::cout<<"Action Name: "<<aIdecl->name.name<<"\n";
        actionListElements.push_back(actionRef);
    }
    auto amce = new IR::MethodCallExpression(new IR::PathExpression(noActionName), 
                                             new IR::Vector<IR::Type>(), 
                                             new IR::Vector<IR::Argument>());
    auto actionRef = new IR::ActionListElement(amce);
    actionListElements.push_back(actionRef);

    auto key = createKey(dummyMCS);
    auto actionList = new IR::ActionList(actionListElements);
    auto entriesList = new IR::EntriesList(entries);
    auto p4Table = createP4Table(tableName, key, actionList, entriesList);
    return p4Table;
}


DeparserConverter::EntryContext 
DeparserConverter::extendEntry(const IR::MethodCallStatement* mcs,
                    const EntryContext& entry,  const std::vector<char>& newKVs, 
                    const std::vector<CurrOSMoveOSHdr>& emitData,
                    int totalMoveOffset, unsigned currOffset) {
  
    /*
    std::cout<<"\n-------- ----emitData--------\n";
    printEIMvOsHdr(emitData);
    std::cout<<"cumulative moveOffset "<<totalMoveOffset/8<<"\n";
    std::cout<<"currOffset "<<currOffset/8<<"\n";
    std::cout<<"----------------------------\n";
    */

    IR::IndexedVector<IR::Declaration> entryActions;
    IR::ListExpression* ls = std::get<0>(entry)->clone();
    auto initOffset = std::get<3>(entry);
    for (auto value : newKVs) {
        IR::Expression* e = (value=='t')?	new IR::BoolLiteral(true): 
                                          new IR::BoolLiteral(false);
        ls->components.push_back(e);
    }


    std::vector<CurrOSMoveOSHdr> emitOrder;
    int moveOffset = 0;
    for (short s = emitData.size()-1 ; s >= 0 ;) {
        moveOffset = std::get<1>(emitData[s]);
        // std::cout<<"moveOffset : "<<moveOffset/8<<"\n";
        if (moveOffset < 0) {
            auto begin = s;
            while (moveOffset < 0 && s >= 0) {
                s--;
                moveOffset = std::get<1>(emitData[s]);
            }
            auto end = s;
            for (short i = end; i<begin; i++) 
                emitOrder.emplace_back(emitData[i]);
                
        } else {
            auto hn = std::get<2>(emitData[s]);
            // std::cout<<"Adding in emitOrder "<<hn<<"\n";
            emitOrder.emplace_back(emitData[s]);
            s--;
        }
    }

    /*
    std::cout<<"\n-------- emit order-----\n";
    printEIMvOsHdr(emitOrder);
    std::cout<<"\n-------------------\n";
    */

    cstring actName = "";
    for (auto d : emitData) {
        auto ei = std::get<0>(d);
        auto hn = std::get<2>(d);
        auto width = hdrSizeByInstName[hn];
        actName += hn+"_"+cstring::to_cstring(ei/8)+
                      "_"+cstring::to_cstring((ei+width)/8)+"_";
    }
    cstring moStr = cstring::to_cstring(std::abs(totalMoveOffset/8));
    moStr = totalMoveOffset>0 ? moStr : "mi"+moStr;
    actName+= "MO_Emit_"+moStr;

    std::vector<IR::P4Action*> actionCallOrder;
    for (auto d : emitOrder) {
        auto co = std::get<0>(d);
        auto mo = std::get<1>(d);
        auto hn = std::get<2>(d);
        auto width = hdrSizeByInstName[hn];
        if (mo != 0) {
            unsigned moveBlockSize = width;
            if (((co + mo) <= *byteStackSize) && 
                ((co + mo + width) > *byteStackSize))
              moveBlockSize = *byteStackSize - (co + mo);
            if (moveBlockSize != 0) {
                auto moveAct = createByteMoveP4Action(co, mo, moveBlockSize);
                actionCallOrder.push_back(moveAct);
            }
        }
        auto hdrAct =  createP4Action(hn, co+mo);
        actionCallOrder.push_back(hdrAct);
    }

    IR::P4Action* resMoveAct = nullptr;
    unsigned resiBlockSize = *byteStackSize - currOffset;
    /*
    std::cout<<"--------------1-------------\n";
    std::cout<<"currOffset : "<<currOffset/8<<" totalMoveOffset : "
      <<totalMoveOffset/8<<" resiBlockSize : "<<resiBlockSize/8<<"\n";
    */
    unsigned lhsMin =  (currOffset + totalMoveOffset);
    unsigned lhsMax =  lhsMin + resiBlockSize ;
    if (lhsMin <= *byteStackSize && lhsMax > *byteStackSize)
        resiBlockSize = *byteStackSize - lhsMin;
    if (lhsMin > *byteStackSize)
        resiBlockSize = 0;
    if (totalMoveOffset != 0 && resiBlockSize !=0 )
        resMoveAct = createByteMoveP4Action(currOffset, totalMoveOffset, 
                                            resiBlockSize);
    /*
    std::cout<<"--------------2-------------\n";
    std::cout<<"currOffset : "<<currOffset/8<<" totalMoveOffset : "
      <<totalMoveOffset/8<<" resiBlockSize : "<<resiBlockSize/8<<"\n";
    */
    
    if (resMoveAct != nullptr) {
        if (totalMoveOffset < 0)
            actionCallOrder.push_back(resMoveAct);
        if (totalMoveOffset > 0)
            actionCallOrder.insert(actionCallOrder.begin(), resMoveAct);
    }

    IR::P4Action* action = nullptr;

    IR::IndexedVector<IR::StatOrDecl> actionBlockStatements;
    for (auto a : actionCallOrder) {
        auto mce = new IR::MethodCallExpression(
            new IR::PathExpression(a->name), new IR::Vector<IR::Type>(), new 
            IR::Vector<IR::Argument>());
        auto ms = new IR::MethodCallStatement(mce);
        actionBlockStatements.push_back(ms);
        entryActions.insert(entryActions.begin(), a);

    }
    auto actionBlock = new IR::BlockStatement(actionBlockStatements);
    action = new IR::P4Action(actName, new IR::ParameterList(), actionBlock);
    entryActions.push_back(action);
    
    for (auto a : entryActions) {
        if (actionDecls[mcs].getDeclaration(a->name) == nullptr)
            actionDecls[mcs].push_back(a);
    }

    return EntryContext{ls, currOffset, action, initOffset};
}


IR::P4Action* DeparserConverter::createP4Action(const cstring hdrInstName, 
                                                unsigned currentEmitOffset) {

    auto it = hdrMCSMap.find(hdrInstName);
    BUG_CHECK(it!= hdrMCSMap.end(), "emit statement for %1% not found", 
        hdrInstName);
    return createP4Action(it->second, currentEmitOffset);

}


// Copies moveInitIdx to moveInitIdx+moveOffset
// LHS index moveInitIdx+moveOffset -- RHS index moveInitIdx
// ...
//   moveInitIdx + moveOffset+ moveBlockSize -- moveInitIdx + moveBlockSize
IR::P4Action* DeparserConverter::createByteMoveP4Action(unsigned moveInitIdx, 
                                      int moveOffset, unsigned moveBlockSize) {

    IR::IndexedVector<IR::StatOrDecl> actionBlockStatements;
    std::vector<IR::StatOrDecl*> asms;

    cstring moStr = cstring::to_cstring(std::abs(moveOffset/8));
    moStr = moveOffset>0 ? moStr : "mi"+moStr;

    cstring actName = "move_" + cstring::to_cstring(moveInitIdx/8) + "_" +
      moStr +"_"+ cstring::to_cstring(moveBlockSize/8);

    auto exp = new IR::Member(new IR::PathExpression(paketOutParamName), 
                                 IR::ID(NameConstants::csaHeaderInstanceName));

    unsigned lhsIdx = (moveInitIdx + moveOffset)/8;
    unsigned rhsIdx = moveInitIdx/8;

    for (unsigned i = 0 ; i < (moveBlockSize/8) ; i++) {
        // lhsIdx+i   rhsIdx+i
        auto le = new IR::ArrayIndex(exp->clone(), new IR::Constant(lhsIdx+i));
        auto lhsm = new IR::Member(le, IR::ID("data"));
        auto re = new IR::ArrayIndex(exp->clone(), new IR::Constant(rhsIdx+i));
        auto rhsm = new IR::Member(re, IR::ID("data"));
        auto as = new IR::AssignmentStatement(lhsm, rhsm);
        asms.push_back(as);
    }

    if (moveOffset > 0)
        std::reverse(std::begin(asms), std::end(asms));
    for (auto as : asms)
        actionBlockStatements.push_back(as);

    auto actionBlock = new IR::BlockStatement(actionBlockStatements);
    auto p4Action = new IR::P4Action(actName, new IR::ParameterList(), actionBlock);
    return p4Action;
}



/*
 *
 * HS: Code is commented, the function is not needed for now.
 * If we ever allow conditional statement in Deparser, this code may need to be
 * resurrected. As of Nov-25-2019, it is outdated.
 *
 *
//TODO extend this part of the code to take into consideration the previous predecessors all keys, actions+ entries
//TODO similar to extend but with iterations over the predecessors
//TODO make sure when append to respect the order in the entry/key list when appending with false for non matched elements
//TODO check if diagram will remain the same in all cases
IR::P4Table* DeparserConverter::mergeAndExtendEmitTables(const IR::P4Table* old_table,
                                    const IR::MethodCallStatement* mcs,
                                    std::vector<const IR::MethodCallStatement*>*
                                        predecessors ) {

    IR::Vector<IR::Entry> entries;
    IR::IndexedVector<IR::ActionListElement> actionListElements;

    // <keyValues, actionBinding, offset>
    typedef std::tuple<IR::ListExpression*, IR::MethodCallExpression*, unsigned> TableEntryInfo;
    std::map<const IR::MethodCallStatement*, std::vector<TableEntryInfo> > 
          tableEntryInfoMap;
    std::map<const IR::MethodCallStatement*, 
             std::vector<std::pair<const IR::Expression*, bool>>>  tempKELS;

    unsigned width = 0;
    auto exp = getArgHeaderExpression(mcs, width);
    for (auto p : (*predecessors)) {
    	//LOG3("merging table "<< emitIds[mcs]<< " with "<< emitIds[p]);
        std::vector<std::pair<const IR::Expression*, bool>>  tempKL(keyElementLists[p]);    
        auto keyExp = new IR::PathExpression(controlVar[p].first);
        tempKL.emplace_back(keyExp, true);
        tempKL.emplace_back(exp, true);

        tempKELS[p] = tempKL;
        cstring emittedActionName;
            auto existingEntries=old_table->getEntries()->entries;
            for (unsigned i=0; i<2; i++) {
            	IR::Expression* e = (i==0)?
        							new IR::BoolLiteral(false):
        							new IR::BoolLiteral(true);
                unsigned size=1;
        		for (auto entry: existingEntries){
        			IR::ListExpression*  ls=const_cast<IR::ListExpression* >(entry->getKeys()->clone());
        			ls->components.push_back(e);
        			auto action = entry->getAction();
        			if(i==1){
        				IR::ListExpression* keys_pointer = const_cast<IR::ListExpression* >(entry->getKeys());
        				unsigned int currentEmitOffset=0;
        				for (auto ele: keyValueEmitOffsets[p]){
        					if (ele.first==keys_pointer)
        						currentEmitOffset=ele.second;
        				}
        				emittedActionName = createAppendedP4Action(mcs,currentEmitOffset,actionDecls[p]);
        				auto actionBinding = new IR::MethodCallExpression(
        					new IR::PathExpression(emittedActionName),
        					new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
        				auto entry0 = new IR::Entry(ls, actionBinding);
        				entries.push_back(entry0);
        			}else{
        				auto entry0 = new IR::Entry(ls,action);
        				entries.push_back(entry0);
        			}
        			size=ls->components.size();
        		}
        		if(i==1){
        			IR::Vector<IR::Expression> components;

        			for (unsigned s=1;s<size;s++){
        				IR::Expression* e = new IR::BoolLiteral(false);
        				components.push_back(e);
        			}
        			IR::Expression* e = new IR::BoolLiteral(true);
        			components.push_back(e);
        			IR::ListExpression* ls = new IR::ListExpression(components);
        			unsigned int currentEmitOffset = 0;
        			for(auto ele : keyValueEmitOffsets[p]){
        				if( currentEmitOffset<ele.second)
        					currentEmitOffset=ele.second;
        			}
        			emittedActionName = createP4Action(mcs, currentEmitOffset);
        			auto actionBinding = new IR::MethodCallExpression(
        				new IR::PathExpression(emittedActionName),
        				new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
        			auto entry = new IR::Entry(ls, actionBinding);
        			//LOG3("entry1 "<< entry);
        			entries.push_back(entry);
        		}

            }

    }

    // Creating uniion of keys
    std::vector<std::pair<const IR::Expression*, bool>> 
        mergedKeyExpression(tempKELS.begin()->second);
    std::vector<std::pair<const IR::Expression*, bool>> tempMerge;
    for(const auto& ele : tempKELS) {
        
        auto keyIt = ele.second.begin();
        auto mergedKeyIt = mergedKeyExpression.begin();
        auto currentIterMergedKey = mergedKeyExpression.begin();
        tempMerge.clear();
        
        bool saveIter = true;
        for (; keyIt != ele.second.end() 
            || currentIterMergedKey != mergedKeyExpression.end();) {

            if (keyIt == ele.second.end() && 
                currentIterMergedKey != mergedKeyExpression.end()) {
                tempMerge.push_back(*currentIterMergedKey);
                currentIterMergedKey++;
                continue;
            }
            if (keyIt != ele.second.end() && 
                currentIterMergedKey == mergedKeyExpression.end()) {
                tempMerge.push_back(*keyIt);
                keyIt++;
                continue;
            }

            if (keyIt->first == mergedKeyIt->first) {
                for (; currentIterMergedKey != mergedKeyIt; currentIterMergedKey++)
                    tempMerge.push_back(*currentIterMergedKey);
                tempMerge.push_back(*keyIt);
                keyIt++; mergedKeyIt++;
                currentIterMergedKey++;
                saveIter = true;
            } else {
                if (saveIter) {
                    currentIterMergedKey = mergedKeyIt;
                    saveIter = false;
                }
                if (mergedKeyIt != mergedKeyExpression.end()) {
                    mergedKeyIt++;
                } else {
                    tempMerge.push_back(*keyIt);
                    keyIt++;
                    mergedKeyIt = currentIterMergedKey;

                }
            }
        }
        mergedKeyExpression = tempMerge;
    }

    // insert dontcare values 
    for (auto& ele : tableEntryInfoMap) {
        auto& tableEntries = ele.second;
        auto tableKeyOrder = tempKELS[ele.first];
        auto iter = tableKeyOrder.begin();
        unsigned i = 0;
        for (auto& keyMatchType : mergedKeyExpression) {
            if (iter->first != keyMatchType.first) {
                keyMatchType.second = false;
                for (auto& entry : tableEntries) {
                    auto e = new IR::DefaultExpression();
                    auto ls = std::get<0>(entry);
                    auto column = ls->components.begin()+i;
                    ls->components.insert(column, e);
                }
            } else {
                iter++;
            }
            i++;
        }
    }

    // create entries
    for (const auto& ele : tableEntryInfoMap) {
        for (const auto& entryInfo : ele.second) { 
            auto actionBinding = std::get<1>(entryInfo);
            if (actionBinding == nullptr)
                continue;
            auto entry = new IR::Entry(std::get<0>(entryInfo)->clone(), 
                                       std::get<1>(entryInfo));
            entries.push_back(entry);
        }
    }

    for (const auto& aIdecl : actionDecls[mcs]) {
        auto amce = new IR::MethodCallExpression(
                            new IR::PathExpression(aIdecl->name.name), 
                            new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
        auto actionRef = new IR::ActionListElement(amce);
        actionListElements.push_back(actionRef);
    }
    auto amce = new IR::MethodCallExpression(new IR::PathExpression(noActionName), 
                                             new IR::Vector<IR::Type>(), 
                                             new IR::Vector<IR::Argument>());
    auto actionRef = new IR::ActionListElement(amce);
    actionListElements.push_back(actionRef);

    keyElementLists[mcs] = mergedKeyExpression;
    auto key = createKey(mcs);
    auto actionList = new IR::ActionList(actionListElements);
    auto entriesList = new IR::EntriesList(entries);
    auto p4Table = createP4Table(emitIds[mcs], key, actionList, entriesList);
    return p4Table;
}
*/



}// namespace CSA
