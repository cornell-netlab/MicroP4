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

    if (em->originalExternType->name.name != P4::P4CoreLibrary::instance.packetOut.name 
        || em->method->name.name != P4::P4CoreLibrary::instance.packetOut.emit.name)
        return false;

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
        auto type = typeMap->getType(param->type, false);
        if (type == nullptr)
            break;
        auto tt = typeMap->getTypeType(param->type, false);
        if (tt->is<IR::Type_Extern>()) {
            auto te = tt->to<IR::Type_Extern>();
            if (te->name.name == P4::P4CoreLibrary::instance.packetOut.name) {
                // std::cout<<tt<<"\n";
                return true;
            }
        }
    }
    return false;
}


const IR::Node* DeparserConverter::preorder(IR::P4Control* deparser) {
	LOG3("preorder p4control"<< deparser->name.name);
    if (!isDeparser(deparser)) {
        prune();
        return deparser;
    }
    auto param = deparser->getApplyParameters()->getParameter(0);
    paketOutParamName = param->name.name;

    emitCallGraph = new EmitCallGraph(deparser->name.name);

    CreateEmitSchedule createEmitSchedule(refMap, typeMap, emitCallGraph);
    deparser->apply(createEmitSchedule);

    std::vector<const IR::MethodCallStatement*> sorted;
    emitCallGraph->sort(sorted);
    std::reverse(std::begin(sorted), std::end(sorted));

    for (auto emit : sorted)
        createID(emit);

    return deparser;
}


const IR::Node* DeparserConverter::postorder(IR::Parameter* param) {
    
    auto deparser = findContext<IR::Type_Control>();
    if (deparser == nullptr)
        return param;
    
    auto type = typeMap->getTypeType(param->type, false);
    if (!type->is<IR::Type_Extern>()) {
      // std::cout<<__FUNCTION__<<"not Type_Extern"<<"\n";
        return param;
    }
    
    auto te = type->to<IR::Type_Extern>();
    if (te->name.name != P4::P4CoreLibrary::instance.packetOut.name) {
        return param;
    }

    auto np = new IR::Parameter(param->srcInfo, IR::ID(param->name.name), 
                                IR::Direction::InOut, new IR::Type_Name(structTypeName));
    return np;
}


const IR::Node* DeparserConverter::postorder(IR::P4Control* deparser) {

    auto& controlLocals = deparser->controlLocals;
    controlLocals.append(varDecls);
    for (const auto& e : actionDecls) 
        controlLocals.append(e.second);

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
	LOG3("preorder method call statement");
    auto mcs = getOriginal()->to<IR::MethodCallStatement>();

    if (!isEmitCall(methodCallStmt, refMap, typeMap))
        return methodCallStmt;

    // std::cout<<"preorder MethodCallStatement: "<<mcs<<"\n";
    for (auto& callee : (*emitCallGraph->getCallees(mcs))) {
        auto callers = emitCallGraph->getCallers(callee);
        if (callers->size() > 1) {
            cstring varName = emitIds[mcs]+"_cg_var";
            /*
            auto bitType = IR::Type::Bits::get(1, false);
            auto declVar = new IR::Declaration_Variable(varName, bitType,
                                                    new IR::Constant(0, 2)); 
            */
            auto boolType = IR::Type_Boolean::get();
            auto declVar = new IR::Declaration_Variable(varName, boolType,
                                                    new IR::BoolLiteral(false)); 
            varDecls.push_back(declVar);
            /*
            auto cva = new IR::AssignmentStatement(new IR::PathExpression(varName), 
                                                   new IR::Constant(1, 2));
            */
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
    IR::P4Table* p4Table = nullptr;

//TODO change this part, create emit table if not emit table iexists
    // If emit table exists then we need to extend the existing able
    if (!emitCallGraph->isCallee(mcs)) {
        // std::cout<<"Converting --> "<<methodCallStmt<<" to table\n";
        p4Table = createEmitTable(mcs);
        if (p4Table) {
        // std::cout<<__func__<<": creating apply method call\n";
             // std::cout<<"p4table name "<<p4Table->name.name<<"\n";
             auto method = new IR::Member(new IR::PathExpression(p4Table->name.name), IR::ID("apply"));
             auto mce = new IR::MethodCallExpression(method, new IR::Vector<IR::Argument>());
             auto tblApplyMCS = new IR::MethodCallStatement(mce);
             // std::cout<<__func__<<": apply method call created\n";
             return tblApplyMCS;
        }
        LOG3("createEmit table "<< emitIds[mcs]);

    } else {
        auto callers = emitCallGraph->getCallers(mcs);
        if (callers->size() == 1){
            p4Table = extendEmitTable(tableDecls[0]->to<IR::P4Table>(), mcs, (*callers)[0]);
        LOG3("extendEmit table "<< emitIds[mcs]<< " with "<< emitIds[(*callers)[0]]);
        }else if ( callers->size() > 1){
            p4Table = mergeAndExtendEmitTables(tableDecls[0]->to<IR::P4Table>(), mcs, callers);
            LOG3("merge and extendEmit table "<< emitIds[mcs]);
        }else {
            // size can not be 0;
        }
    }

    return methodCallStmt;
}

IR::P4Table* DeparserConverter::createEmitTable(const IR::MethodCallStatement* mcs) {
    unsigned width;
    unsigned offset = 0;
    IR::Vector<IR::KeyElement> keyElementList;
    IR::IndexedVector<IR::ActionListElement> actionListElements;
    IR::Vector<IR::Entry> entries;

    // std::cout<<__func__<<": creating key\n";
    auto exp = getArgHeaderExpression(mcs, width);
    auto newMember = new IR::Member(exp->clone(), IR::Type_Header::isValid);
    auto mce = new IR::MethodCallExpression(newMember);
    auto hdrEmitKey = new IR::KeyElement(mce, new IR::PathExpression("exact"));
    keyElementList.push_back(hdrEmitKey);
    keyElementLists[mcs].emplace_back(exp, true);

    // std::cout<<__func__<<": creating entry with 0\n";

    IR::Vector<IR::Expression> simpleExpressionList;
    //IR::Expression* e0 = new IR::Constant(0, 2);
    IR::Expression* e0 = new IR::BoolLiteral(false);
    simpleExpressionList.insert(simpleExpressionList.begin(), e0);
    auto kse0 = new IR::ListExpression(simpleExpressionList);
    keyValueEmitOffsets[mcs].emplace_back(kse0, offset);

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
    auto emittedName = createP4Action(mcs, offset);
    keyValueEmitOffsets[mcs].emplace_back(kse1, offset);
    
    auto actionBinding1 = new IR::MethodCallExpression(
        new IR::PathExpression(emittedName), 
        new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
    auto entry1 = new IR::Entry(kse1, actionBinding1);

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


IR::P4Table* DeparserConverter::extendEmitTable(const IR::P4Table* oldTable, const IR::MethodCallStatement* mcs,
                                                const IR::MethodCallStatement* 
                                                    predecessor) {
    unsigned width;
    IR::IndexedVector<IR::ActionListElement> actionListElements;
    IR::Vector<IR::Entry> entries;
    auto exp = getArgHeaderExpression(mcs, width);

    std::vector<std::pair<const IR::Expression*, bool>> keyExp(keyElementLists[predecessor]);
    keyExp.emplace_back(exp, true);
    keyElementLists[mcs] = keyExp;

    cstring emittedActionName;
    // TODO WHY 2 what is 1
    // TODO modify this part of the code to add previous match entries appended with their actions and the remaining added keys should be false
    // TODO in this part also in createP4Actions, we need to append the previous actoin action declaration statements in the newly created action when matching on previous match + current match action
    for (unsigned i=0; i<2; i++) { // WHY 2
        for (auto ele : keyValueEmitOffsets[predecessor]) {
            auto currentEmitOffset = ele.second;
            IR::ListExpression* ls = ele.first->clone();
            //IR::Expression* e = new IR::Constant(i, 2);
            IR::Expression* e = (i==0)? 
                                new IR::BoolLiteral(false): 
                                new IR::BoolLiteral(true);
            ls->components.push_back(e);
            if (i == 1) {
                emittedActionName = createP4Action(mcs, currentEmitOffset);
                auto actionBinding = new IR::MethodCallExpression(
                    new IR::PathExpression(emittedActionName), 
                    new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
                auto entry = new IR::Entry(ls, actionBinding);
                entries.push_back(entry);
            } else {
                auto iter = controlVar.find(mcs);
                if (iter != controlVar.end()) {
                    auto notEmittedName = iter->second.second;
                    auto actionBinding0 = new IR::MethodCallExpression(
                                                new IR::PathExpression(notEmittedName), 
                                      new IR::Vector<IR::Type>(), 
                                      new IR::Vector<IR::Argument>());
                    auto entry0 = new IR::Entry(ls, actionBinding0);  
                    entries.push_back(entry0);
                }

            }
            keyValueEmitOffsets[mcs].emplace_back(ls, currentEmitOffset);
        }
    }

    for (const auto& aIdecl : actionDecls[mcs]) {
        auto amce = new IR::MethodCallExpression(
                            new IR::PathExpression(aIdecl->name.name), 
                            new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
        auto actionRef = new IR::ActionListElement(amce);
        actionListElements.push_back(actionRef);
    }
    for (const auto& aIdecl : actionDecls[predecessor]) {
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


    auto key = createKey(mcs);
    auto actionList = new IR::ActionList(actionListElements);
    auto entriesList = new IR::EntriesList(entries);
    auto p4Table = createP4Table(emitIds[mcs], key, actionList, entriesList);
    return p4Table;
}

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
    	LOG3("merging table "<< emitIds[mcs]<< " with "<< emitIds[p]);
        std::vector<std::pair<const IR::Expression*, bool>>  tempKL(keyElementLists[p]);    
        auto keyExp = new IR::PathExpression(controlVar[p].first);
        tempKL.emplace_back(keyExp, true);
        tempKL.emplace_back(exp, true);

        tempKELS[p] = tempKL;
        for (unsigned i=0; i<2; i++) {
            for (auto ele : keyValueEmitOffsets[p]) { 
                auto currentEmitOffset = ele.second;
                IR::ListExpression* ls = ele.first->clone();
                // IR::Expression* e = new IR::Constant(i, 2);
                IR::Expression* e = (i==0)? 
                                new IR::BoolLiteral(false): 
                                new IR::BoolLiteral(true);
                // IR::Expression* cg = new IR::Constant(1, 2);
                IR::Expression* cg = new IR::BoolLiteral(true);
                ls->components.push_back(cg);
                ls->components.push_back(e);
                IR::MethodCallExpression* actionBinding = nullptr;
                if (i == 1) {
                    auto emittedActionName = createP4Action(mcs, currentEmitOffset);
                    actionBinding = new IR::MethodCallExpression(
                                        new IR::PathExpression(emittedActionName), 
                                        new IR::Vector<IR::Type>(), 
                                         new IR::Vector<IR::Argument>());
                } else {
                    auto iter = controlVar.find(mcs);
                    if (iter != controlVar.end()) {
                        auto notEmittedName = iter->second.second;
                        actionBinding = new IR::MethodCallExpression(
                                                    new IR::PathExpression(notEmittedName), 
                                          new IR::Vector<IR::Type>(), 
                                          new IR::Vector<IR::Argument>());
                    }
                }
                tableEntryInfoMap[p].emplace_back(ls, actionBinding, 
                                                    currentEmitOffset);
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

IR::Key* DeparserConverter::createKey(const IR::MethodCallStatement* mcs) {
    
    IR::Vector<IR::KeyElement> keyElementList;
    auto vec = keyElementLists[mcs];
    for (auto ele : vec) {
        bool mt = ele.second;
        auto type = typeMap->getType(ele.first);
        auto exp = ele.first->clone();
        IR::Expression* keyExp = nullptr;
        if (type->is<IR::Type_Header>()){
            auto member = new IR::Member(exp, IR::Type_Header::isValid);
            keyExp = new IR::MethodCallExpression(member);
        } else {
            keyExp = exp;
        }
        auto hdrEmitKey = new IR::KeyElement(keyExp, new IR::PathExpression(
                                                      mt?"exact":"ternary"));
        keyElementList.push_back(hdrEmitKey);
    }
    return new IR::Key(keyElementList);
}

cstring DeparserConverter::createP4Action(const IR::MethodCallStatement* mcs, 
                                          unsigned& currentEmitOffset) {
    
    unsigned width = 0;
    unsigned emitOffset = 0;
    auto e = getArgHeaderExpression(mcs, width);
    IR::IndexedVector<IR::StatOrDecl> actionBlockStatements;

    auto exp = new IR::Member(new IR::PathExpression(paketOutParamName), 
                                 IR::ID(fieldName));
    // auto member = new IR::Member(exp, IR::ID("data"));
    cstring name;
    if (e->is<IR::Member>()) 
        name = e->to<IR::Member>()->member;
    else 
        name = e->toString();

    name += "_valid";
    emitOffset = currentEmitOffset + width;
    name += "_"+cstring::to_cstring(currentEmitOffset) + 
            "_"+ cstring::to_cstring(emitOffset);

    auto mcsActions = actionDecls[mcs];

    const IR::IDeclaration* actionDecl = mcsActions.getDeclaration(name);
    if (actionDecl != nullptr)
        return name;

    
    auto type = typeMap->getType(e);
    BUG_CHECK(type->is<IR::Type_Header>(), "expected header type ");
    auto th = type->to<IR::Type_Header>();

    unsigned start = currentEmitOffset;
    for (auto f : th->fields) {
        auto w = symbolicValueFactory->getWidth(f->type);
        unsigned startByteIndex = start/8;
        unsigned startByteBitIndex = start % 8;
        
        start += w;
        unsigned fwCounter = 0; // field width counter
        if (startByteBitIndex != 0) {
            auto bl = new IR::ArrayIndex(exp->clone(), 
                                         new IR::Constant(startByteIndex));
            auto member = new IR::Member(bl, IR::ID("data"));

            const IR::Expression* initSlice = nullptr;
            const IR::Expression* rh = nullptr;
            if ((8-startByteBitIndex) <= w) {
                initSlice = IR::Slice::make(member, startByteBitIndex, 7);
                fwCounter += (8-startByteBitIndex);
                auto rMem = new IR::Member(e->clone(), IR::ID(f->getName()));
                // rh = IR::Slice::make(rMem, 0, 8-startByteBitIndex-1);
                rh = IR::Slice::make(rMem, w-(8-startByteBitIndex), w-1);
                w = w-(8-startByteBitIndex);
            } else {
                initSlice = IR::Slice::make(member, startByteBitIndex, 
                                            startByteBitIndex+w-1);
                // fwCounter += w;
                rh = new IR::Member(e->clone(), IR::ID(f->getName()));
                w = 0;
            }
            startByteIndex++;
            auto as = new IR::AssignmentStatement(initSlice, rh);
            actionBlockStatements.push_back(as);
        }
        // while (fwCounter+8 <= w) {
        while (w >= 8) {
            auto pe = new IR::ArrayIndex(exp->clone(), 
                                         new IR::Constant(startByteIndex++));
            auto lh = new IR::Member(pe, IR::ID("data"));
            auto rMem = new IR::Member(e->clone(), IR::ID(f->getName()));
            // auto rh = IR::Slice::make(rMem, fwCounter, fwCounter+7);
            auto rh = IR::Slice::make(rMem, w-8, w-1);
            auto as = new IR::AssignmentStatement(lh, rh);
            actionBlockStatements.push_back(as);
            // fwCounter += 8;
            w -=8;
        }
        // if (fwCounter < w) {
        if (w != 0) {
            auto bl = new IR::ArrayIndex(exp->clone(), 
                                         new IR::Constant(startByteIndex));
            auto lh = new IR::Member(bl, IR::ID("data"));
            // auto endSlice = IR::Slice::make(lh, 0, w-fwCounter-1);
            auto endSlice = IR::Slice::make(lh, 0, w-1);
            auto rMem = new IR::Member(e->clone(), IR::ID(f->getName()));
            // auto rh = IR::Slice::make(rMem, fwCounter, w-1);
            auto rh = IR::Slice::make(rMem, 0, w-1);
            auto as = new IR::AssignmentStatement(endSlice, rh);
            actionBlockStatements.push_back(as);
        }
        /*
        auto slice = IR::Slice::make(member->clone(), start, start+w-1);
        auto rm = new IR::Member(e->clone(), IR::ID(f->getName()));
        auto as = new IR::AssignmentStatement(slice, rm);
        actionBlockStatements.push_back(as);
        */
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
    actionDecls[mcs].push_back(action);
    return name;
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

    std::cout<<"Deparser table name --> "<<table->name<<" total"<<tableDecls.size()<<"\n";
    return table;
}

const IR::Expression* 
DeparserConverter::getArgHeaderExpression(const IR::MethodCallStatement* mcs, 
                                          unsigned& width) const{
    auto expression = mcs->methodCall;
    auto arg0 = expression->arguments->at(0);
    auto argType = typeMap->getType(arg0, true);
    width = symbolicValueFactory->getWidth(argType);
    return arg0->expression;
}

void DeparserConverter::createID(const IR::MethodCallStatement* emitStmt) {

    unsigned i = 0;
    auto exp = getArgHeaderExpression(emitStmt, i);
    auto mem = exp->to<IR::Member>();
    i = 0;
    bool flag = true;
    std::string id;
    while (flag) {
        flag = false;
        id = "emit_"+mem->member+"_"+std::to_string(i);
        for (const auto& kv : emitIds) {
            if (kv.second == id) {
                i++; flag = true; break;
            }
        }
    }
    emitIds.emplace(emitStmt, cstring(id));
}

}// namespace CSA
