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
    
    // indicesHeaderInstanceName
    auto ke1 = new IR::Member(new IR::PathExpression(paketOutParamName), 
                              NameConstants::indicesHeaderInstanceName);
    auto ke2 = new IR::Member(ke1, NameConstants::csaPktStuCurrOffsetFName);
    auto keyEle = new IR::KeyElement(ke2, new IR::PathExpression("exact"));
    keyElementLists[mcs].emplace_back(ke2, true);

    for (auto os : initialOffsets) {
        IR::Vector<IR::Expression> exprList;
        IR::Vector<IR::Entry> entryList;
        // std::cout<<"initTableWithOffsetEntries an: "<<an<<"\n";
        exprList.push_back(new IR::Constant(os));
        auto keySetExpr = new IR::ListExpression(exprList);
        keyValueEmitOffsets[mcs].emplace_back(keySetExpr, os, nullptr);
    }
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
    // std::cout<<"Deparser Converter \n";

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
    keyValueEmitOffsets[mcs].emplace_back(kse0, offset, nullptr);

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
    keyValueEmitOffsets[mcs].emplace_back(kse1, offset, emitAct);

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
    auto exp = getArgHeaderExpression(mcs, width);

    std::vector<std::pair<const IR::Expression*, bool>> keyExp(keyElementLists[predecessor]);
    keyExp.emplace_back(exp, true);
    keyElementLists[mcs] = keyExp;

    for (unsigned i=0; i<2; i++) {
        for (auto ele : keyValueEmitOffsets[predecessor]) {
            auto currentEmitOffset = std::get<1>(ele);
            IR::ListExpression* ls = std::get<0>(ele)->clone();
            IR::Expression* e = (i==0)?	new IR::BoolLiteral(false):
                                        new IR::BoolLiteral(true);
            ls->components.push_back(e);
            auto action = std::get<2>(ele);
            if (i==1) {
                auto emitAct = createP4Action(mcs,currentEmitOffset, action);
                auto actionBinding = new IR::MethodCallExpression(
                              new IR::PathExpression(emitAct->name),
                              new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
                auto entry0 = new IR::Entry(ls, actionBinding);
                entries.push_back(entry0);
                keyValueEmitOffsets[mcs].emplace_back(ls, currentEmitOffset, emitAct);
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
                keyValueEmitOffsets[mcs].emplace_back(ls, currentEmitOffset, action);
            }
        }
    }
    refdActs.append(actionDecls[mcs]);
    for (const auto& aIdecl : refdActs) {
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


IR::P4Action* DeparserConverter::createP4Action(const IR::MethodCallStatement* mcs,
                                      unsigned& currentEmitOffset, 
                                      const IR::P4Action* ancestorAction) {

    auto p4Action = createP4Action(mcs, currentEmitOffset);
    auto body = const_cast<IR::BlockStatement*>(p4Action->body);
    auto a = actionDecls[mcs].getDeclaration(p4Action->getName());
    if (a == nullptr)
        actionDecls[mcs].push_back(p4Action);
    if (ancestorAction != nullptr) {
        auto mce = new IR::MethodCallExpression(
            new IR::PathExpression(ancestorAction->name), 
            new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
        auto mcs= new IR::MethodCallStatement(mce);
        body->push_back(mcs);
    }
    return p4Action;
}


IR::P4Action* DeparserConverter::createP4Action(const IR::MethodCallStatement* mcs, 
                                          unsigned& currentEmitOffset) {
    
    unsigned width = 0;
    unsigned emitOffset = 0;
    auto e = getArgHeaderExpression(mcs, width);
    IR::IndexedVector<IR::StatOrDecl> actionBlockStatements;

    auto exp = new IR::Member(new IR::PathExpression(paketOutParamName), 
                                 IR::ID(NameConstants::csaHeaderInstanceName));
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
                                          unsigned& width) const{
    auto expression = mcs->methodCall;
    auto arg0 = expression->arguments->at(1);
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
