/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "parserConverter.h"
#include "ir/ir.h"
#include "frontends/p4/coreLibrary.h"
#include "frontends/p4/parserCallGraph.h"
#include <algorithm>
#include <cmath>
#include <list>
#include <vector>
#include <unordered_set>

namespace CSA {

const IR::Node* ParserConverter::preorder(IR::P4Program* p4Program) {
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
    visit(p4cpType);

    for (auto updateNode : updateP4ProgramObjects) {
        for (auto& o : p4Program->objects) {
            auto p4cp = o->to<IR::P4ComposablePackage>();
            if (p4cp != nullptr && p4cp->getName() == updateNode->getName()) {
                o = updateNode;
            }
        }
    }
    prune();
    return p4Program;
}


const IR::Node* ParserConverter::preorder(IR::P4ComposablePackage* cp) {
    
    LOG3("ParserConverter preorder visit P4ComposablePackage: "<<cp->name);

    auto packageLocals = cp->packageLocals->clone();
    const IR::Type_Declaration* convertedParser = nullptr;
    for (auto& p : *packageLocals) {
        if (p->is<IR::P4Parser>()) {
            visit(p);
            convertedParser = p;
            break;
        }
    }
    // new start offsets are computed and pushed on offsetsStack.
    auto currentParserOffsets = parserEval->result->getAcceptedPktOffsets();
    auto acceptedPktOffset = new std::vector<unsigned>();
    for (auto currentOffset : *(offsetsStack.back())) {
        for (auto o : currentParserOffsets) {
            acceptedPktOffset->push_back(currentOffset + o);
        }
    }
    offsetsStack.push_back(acceptedPktOffset);

    // Any callee in control blocks will use above offsets( offsetsStack.back())
    for (auto& typeDecl : *(packageLocals)) {
        if (typeDecl->is<IR::P4Control>() && convertedParser!= typeDecl)
            visit(typeDecl);
    }

    // pop the offsets pushed by the parser of this composable package
    offsetsStack.pop_back();

    cp->packageLocals = packageLocals;
    prune();
    updateP4ProgramObjects.push_back(cp);
    return cp;
}

const IR::Node* ParserConverter::preorder(IR::P4Control* p4Control) {
    visit(p4Control->body);
    prune();
    return p4Control;
}

const IR::Node* ParserConverter::preorder(IR::MethodCallStatement* mcs) {
    auto expression = mcs->methodCall;
    P4::MethodInstance* mi = P4::MethodInstance::resolve(expression, refMap, typeMap);
    auto applyMethod = mi->to<P4::ApplyMethod>();
    if (applyMethod != nullptr) {
        if (applyMethod->applyObject->is<IR::P4ComposablePackage>()) {
            auto cp = applyMethod->applyObject->to<IR::P4ComposablePackage>();  
            visit(cp);
        }
    }
    prune();
    return mcs;
}

const IR::Node* ParserConverter::preorder(IR::P4Parser* parser) {
    LOG3("ParserConverter preorder visit  p4parser- "<<parser->name);

    // refreshing varibales
    // parserEval = new P4::ParserStructure();
    statOrDeclsOfControlBody.clear();
    actionDecls.clear(); 
    tableDecl = nullptr;
    keyElementList.clear();
    actionList.clear();
    entryListPerOffset.clear();
    toAppendStats.clear();
    // std::cout<<"parserStructures size: "<<parserStructures->size()<<"\n";
    cstring parser_fqn = parser->getName();
    auto cp = findContext<IR::P4ComposablePackage>();
    if (cp != nullptr)
        parser_fqn = cp->getName() +"_"+ parser->getName();
    std::cout<<parser_fqn<<"\n";
    auto iter = parserStructures->find(parser_fqn);
    BUG_CHECK(iter != parserStructures->end(), 
        "Parser %1% of %2% is not evaluated", parser->name, cp->getName());
    parserEval = iter->second;

    auto param = parser->getApplyParameters()->getParameter(1);
    pktParamName = param->name.name;
    
    auto callGraph = parserEval->callGraph;
    // std::cout<<"size : "<<callGraph->size()<<"\n";

    // Visit states in topological order
    std::vector<const IR::ParserState*> sorted;

    bool hasLoop = callGraph->sccSort(parserEval->start, sorted);
    BUG_CHECK(!hasLoop, "Parser %1% still has loops, unexpected situation.", 
                         parser->name.name);

    std::reverse(std::begin(sorted), std::end(sorted));

    auto headerInvalidActionName = createHeaderInvalidAction(parser);
    auto pe = new IR::PathExpression(headerInvalidActionName);
    auto mce = new IR::MethodCallExpression(pe, new IR::Vector<IR::Type>(), 
                                            new IR::Vector<IR::Argument>());
    auto mcs = new IR::MethodCallStatement(mce);
    statOrDeclsOfControlBody.push_back(mcs);

    if (!(offsetsStack.size() == 1 && offsetsStack.back()->size() == 1 && 
          (*(offsetsStack.back()))[0] == 0)) {
        initTableWithOffsetEntries(sorted[0]->getName());
    }

    for(auto s : sorted)
        visit(s);

    createP4Table();
    auto method = new IR::Member(new IR::PathExpression(IR::ID(tableName)),
   			                                 IR::ID("apply"));
    auto mcea = new IR::MethodCallExpression(method, new IR::Vector<IR::Argument>());
    auto mcsa = new IR::MethodCallStatement(mcea);

    statOrDeclsOfControlBody.push_back(mcsa);
    LOG3("finished parser");
    std::cout<<"finished : "<<parser_fqn<<"\n";
    return parser;
}


/*
const IR::Node* ParserConverter::preorder(IR::Parameter* param) {
    auto parser = findContext<IR::P4Parser>();
    if (parser != nullptr) {
        std::cout<<"parser not null \n";
        auto type = typeMap->getType(param, true);
        auto typeExtern = type->to<IR::Type_Extern>();
        if (typeExtern != nullptr) {
            std::cout<<"typeExtern not null \n";
            if (typeExtern->name == P4::P4CoreLibrary::instance.pkt.name) {
                std::cout<<"pkt matched \n";
                pktParamName = param->name.name;
            }
        }
    }
    return param;
}
*/


void ParserConverter::initTableWithOffsetEntries(const cstring startStateName) {
    
    // indicesHeaderInstanceName
    auto ke1 = new IR::Member(new IR::PathExpression(pktParamName), "inst");
    auto ke2 = new IR::Member(ke1, "f");
    auto keyEle = new IR::KeyElement(ke2, new IR::PathExpression("exact"));
    keyElementList.push_back(keyEle);

    for (auto os : *(offsetsStack.back())) {
        auto evaluatedInstances = parserEval->result->get(startStateName);
        IR::Vector<IR::Entry> entryList;
		    for (auto stateInfo : *evaluatedInstances) {
            auto an = getActionName(stateInfo->name, os);
            // std::cout<<"initTableWithOffsetEntries an: "<<an<<"\n";
            IR::Vector<IR::Expression> exprList;
            exprList.push_back(new IR::Constant(os));
            auto keySetExpr = new IR::ListExpression(exprList);
            auto ab = new IR::MethodCallExpression(new IR::PathExpression(an), 
                new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
            auto entry = new IR::Entry(keySetExpr, ab);
            entryList.push_back(entry);
        }
        entryListPerOffset.emplace(os, entryList);
    }
}


cstring ParserConverter::createHeaderInvalidAction(IR::P4Parser* parser) {

    cstring headerInvalidActionName = "csa_"+parser->name.name+"_"+"invalid_headers";
    auto statOrDeclList = new IR::IndexedVector<IR::StatOrDecl>();
    auto param =  parser->getApplyParameters()->parameters.at(3);
    auto type = typeMap->getType(param, true);
    BUG_CHECK(type->is<IR::Type_Struct>(), "%1% should be Struct type", 
                                            param->getName());
    auto hdrStruct = type->to<IR::Type_Struct>();
    for (auto f : hdrStruct->fields) {
        if (!f->type->is<IR::Type_Header>())
            ::error("%1% expected to be Header type", f->name);

        auto member = new IR::Member(new IR::PathExpression(param->name), f->name);
        auto newMember = new IR::Member(member, IR::Type_Header::setInvalid);
        auto mce = new IR::MethodCallExpression(newMember);
        auto mcs =  new IR::MethodCallStatement(mce);
        statOrDeclList->push_back(mcs);
    }

    auto actionBlock = new IR::BlockStatement(*statOrDeclList);
    auto action = new IR::P4Action(headerInvalidActionName, 
                                   new IR::ParameterList(), actionBlock);
    actionDecls.push_back(action);
    return headerInvalidActionName;
}


void ParserConverter::createP4Table() {
  
    IR::IndexedVector<IR::Property> tablePropertyList;
    auto keyElementListProperty = new IR::Property(IR::ID("key"),
                                          new IR::Key(keyElementList), false);
    tablePropertyList.push_back(keyElementListProperty);
    /*
    for (auto a: actionList){
        LOG3("action list elemtn: "<<a->getName());
    }
    */
    auto actionListProperty = new IR::Property(IR::ID("actions"),
                                      new IR::ActionList(actionList), false);
    tablePropertyList.push_back(actionListProperty);
    
    IR::Vector<IR::Entry> el;
    for (auto offset_el : entryListPerOffset) {
        el.append(offset_el.second);
    }
    auto entriesListProperty = new IR::Property(IR::ID("entries"), 
                                      new IR::EntriesList(el), true);
    tablePropertyList.push_back(entriesListProperty);
  
    auto v = new IR::ExpressionValue(
                     new IR::MethodCallExpression(
                             new IR::PathExpression(noActionName),
                             new IR::Vector<IR::Argument>()));

    auto defaultActProp = new IR::Property(IR::ID("default_action"), v, true);
    tablePropertyList.push_back(defaultActProp);
    
    tableDecl = new IR::P4Table(IR::ID(tableName), 
                                 new IR::TableProperties(tablePropertyList));
}

const IR::Node* ParserConverter::preorder(IR::ParserState* state) {
    LOG3("ParserConverter preorder visit parser state- "<<state->name);

    if (state->name.name != IR::ParserState::accept && 
        state->name.name != IR::ParserState::reject)
        stateIterator(state);
    return state;
}


bool ParserConverter::stateIterator(IR::ParserState* state){
    //LOG3("ParserConverter::stateIterator "<<state->name.name<<"\n");

    if (state->name.name == IR::ParserState::accept || 
        state->name.name == IR::ParserState::reject)
        return false;

	  auto evaluatedInstances = parserEval->result->get(state->name);
		// prepapring KeyElementList
		std::list<std::unordered_set<cstring>> buckets;
		std::list<cstring> order;
		//preparing action list
    std::set<cstring> actions;
		//preparing entry list
		IR::Vector<IR::Expression> exprList;


    // IF the state has select key which does not synthesizes into multiple keys
    // based on byte location, a single key is enough for all the evaluated
    // instances.
    IR::PathExpression* matchType = nullptr;
    if (evaluatedInstances->size() > 1 || hasDefaultSelectCase(state))
        matchType = new IR::PathExpression("ternary");
    else
        matchType = new IR::PathExpression("exact");

    auto initialOffsets = *(offsetsStack.back());
		for (auto stateInfo : *evaluatedInstances) {
        auto oldKeysSize = keyElementList.size();
        bool unsubstKeyAdded = false;
        IR::Vector<IR::KeyElement> newKeyEles;
        // Creating actions
        for (auto initOffset : initialOffsets) {
            auto newActionName = getActionName(stateInfo->name, initOffset);
		        auto decl = actionDecls.getDeclaration(newActionName);
		        if (decl != nullptr)
                continue;
            auto statOrDecl = state->components.clone();
		        ExtractSubstitutor extctSubr(refMap, typeMap, stateInfo, initOffset,
                                         pktParamName, fieldName);
		        auto components = statOrDecl->apply(extctSubr);
		 	 	    auto actionBlockStatements = *components;
            LOG3("evaluated instance "<< stateInfo->name);
            auto iter = toAppendStats.find(newActionName);
		        if (iter != toAppendStats.end()) {
                auto toAppend = iter->second;
		        	  actionBlockStatements.append(toAppend);
		        	  LOG3("appending to instance "<< newActionName);
		        }
		        for (auto p: stateInfo->nextParserStateInfo) {
                auto nextAppendName = getActionName(p.second->name, initOffset);
                toAppendStats.emplace(nextAppendName, actionBlockStatements);
		        	  LOG3("adding info about what to append "<< nextAppendName);
		        }
       
		        auto actionBlock = new IR::BlockStatement(actionBlockStatements);
		        auto action = new IR::P4Action(state->srcInfo, newActionName,
                                  new IR::ParameterList(), actionBlock);
            actionDecls.push_back(action);
  
            // Adding Key Elements
            if (hasSelectExpression(state) && !unsubstKeyAdded) {
                // creating key matching based on expression list
		            auto se = state->selectExpression->to<IR::SelectExpression>();
         
		         		for (auto e : se->select->components) { // TODO optimize
                    bool exists = false;
                    for (auto c : *components) {
                        if (c->is<IR::AssignmentStatement>()) {
                            auto stmt = c->to<IR::AssignmentStatement>();
                            if (e->clone()->toString() == ((*stmt).left)->toString()) {
                                auto selectKey = new IR::KeyElement((*stmt).right,  
                                                        matchType);
                                //LOG3("key expression to be added "<<(*stmt).right);
            	       						for (auto el: keyElementList) {
                                    if (el == selectKey) {
                                        exists = true;
                	       								break;
                                    }
		         						        }
		         						        if (!exists) {
                                    // keyElementList.push_back(selectKey);
                                    newKeyEles.push_back(selectKey);
                                    exists = true;
                                    break;
                                }
                 					  }
		             				}
		           			}
                    if (!exists) {
                        auto selectKey = new IR::KeyElement(e->clone(), 
                                                    matchType); 
                        // keyElementList.push_back(selectKey);
                        newKeyEles.push_back(selectKey);
                        unsubstKeyAdded = true;
                    }
		         	  }
		        }
        }

        /*
        std::cout<<"stateInfo->name: "<<stateInfo->name<<"\n";
        std::cout<<"unsubstKeyAdded: "<<unsubstKeyAdded<<"\n";
        std::cout<<"newKeyEles.size: "<<newKeyEles.size()<<"\n";
        std::cout<<"initialOffsets.size: "<<initialOffsets.size()<<"\n";
        */
        BUG_CHECK((unsubstKeyAdded && newKeyEles.size()==1) || 
            (newKeyEles.size()==initialOffsets.size()) || 
            (newKeyEles.size()==0 && !unsubstKeyAdded), 
            "error in synthesizing keys");

		    // add actions + entries
		    //LOG3("evaluated instances "<<stateInfo->name);
		    // auto current = stateInfo->predecessor;
  
        IR::Vector<IR::Expression> prefExprList;

        keyElementList.append(newKeyEles);
        for (unsigned in = 0; in<initialOffsets.size(); in++) {
            unsigned initOffset = initialOffsets[in];
            auto& entryList = entryListPerOffset[initOffset];
            auto oldEntries = entryList.clone();

            if (oldEntries->size() && newKeyEles.size() 
                && stateInfo->nextParserStateInfo.size())
            entryList.clear();

            prefExprList.clear();
            if (!unsubstKeyAdded) {
                for (unsigned c=0; c<in; c++)
                    prefExprList.push_back(new IR::DefaultExpression());
            }

				    if (newKeyEles.size()) {
          	if (oldEntries->size()) {
                // revisit all previously created entries
                for (auto e: *oldEntries) {
                    auto actionBinding = e->getAction();
                    auto an = getActionName(stateInfo->name, initOffset);
                    IR::Vector<IR::Expression> suffExprList;
							      if (actionBinding->toString() == an) {
                        for (auto kseNSI : stateInfo->nextParserStateInfo) {
                            exprList.clear(); suffExprList.clear();
                            auto keySetExpr = e->getKeys();
                            exprList = (keySetExpr->to<IR::ListExpression>())->components;
                            auto nextStateInfo = kseNSI.second;
					                  cstring actionName = getActionName(nextStateInfo->name, 
                                                               initOffset);
					                  //LOG3("actionName"<< actionName);
                            if (nextStateInfo->state->name == IR::ParserState::accept)
                                continue;
                    
                            auto mce = new IR::MethodCallExpression(
                                              new IR::PathExpression(actionName), 
                                              new IR::Vector<IR::Type>(),
                                              new IR::Vector<IR::Argument>());
                            auto actionRef = new IR::ActionListElement(mce);
                            // if actionlist contains action don't add
                            if (!actionList.getDeclaration(actionName))
						                    actionList.push_back(actionRef);
              					    //entry processing
                            auto caseKeysetExp = kseNSI.first->clone();
								            if (hasSelectExpression(state)){
                                suffExprList.push_back(caseKeysetExp);
                                if (!unsubstKeyAdded) {
                                    for (auto c=prefExprList.size()+1; c<initialOffsets.size(); c++)
                                        suffExprList.push_back(new IR::DefaultExpression());
                                }
                                exprList.append(prefExprList);
                                exprList.append(suffExprList);
                                //  LOG3("caseKeysetExp" << caseKeysetExp);
								            }
								            keySetExpr = new IR::ListExpression(exprList);
    		          					actionBinding = new IR::MethodCallExpression(
									                            new IR::PathExpression(actionName),
                              							  new IR::Vector<IR::Type>(), 
                                              new IR::Vector<IR::Argument>());
                            auto entry = new IR::Entry(keySetExpr, actionBinding);
                            entryList.push_back(entry);
                            // LOG3("entry added "<<entry);
                            // LOG3("binded action path expression"<< actionName);
							          }   
                    } else {
                        // else add default value
                        auto keySetExpr = e->getKeys();
                        exprList.clear();
                        exprList = (keySetExpr->to<IR::ListExpression>())->components;
                        //LOG3("not action, appending default");
                        exprList.push_back(new IR::DefaultExpression());

                        if (!unsubstKeyAdded) {
                            for (auto c=1; c<newKeyEles.size(); c++)
                                exprList.push_back(new IR::DefaultExpression());
                        }
                        keySetExpr = new IR::ListExpression(exprList);
                        auto entry = new IR::Entry(keySetExpr, actionBinding);
                        //LOG3("entry added"<<entry);
                        entryList.push_back(entry);
                        auto mce = new IR::MethodCallExpression(
                            new IR::PathExpression(actionBinding->toString()), 
                                          new IR::Vector<IR::Type>(),
                                          new IR::Vector<IR::Argument>());
                        auto actionRef = new IR::ActionListElement(mce);
                        if (!actionList.getDeclaration(actionBinding->toString()))
						                actionList.push_back(actionRef);
						        }
                } 
            } else {
                for (auto kseNSI : stateInfo->nextParserStateInfo) {
                    exprList.clear();
                    auto nextStateInfo = kseNSI.second;
					          cstring actionName = getActionName(nextStateInfo->name, 
                                                           initOffset);
                    if (hasSelectExpression(state)) {
                        auto caseKeysetExp = kseNSI.first->clone();
                        exprList.push_back(caseKeysetExp);
							          //LOG3("caseKeysetExp" << caseKeysetExp);
                    }
						        auto keySetExpr = new IR::ListExpression(exprList);
                    auto actionBinding = new IR::MethodCallExpression(
                    new IR::PathExpression(actionName),
                    new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
                    //LOG3("binded action path expression"<< actionName);
                    auto entry = new IR::Entry(keySetExpr, actionBinding);
                    entryList.push_back(entry);
                    /*
                    auto mce = new IR::MethodCallExpression(
                                      new IR::PathExpression(actionName), 
                                      new IR::Vector<IR::Type>(),
                                      new IR::Vector<IR::Argument>());
                    auto actionRef = new IR::ActionListElement(mce);
                    if (!actionList.getDeclaration(actionName))
						            actionList.push_back(actionRef);
                    */
                }
				    }
            }
		    }
    }
	  return true;
}



bool ParserConverter::hasSelectExpression(const IR::ParserState* state) const {
    if (state->selectExpression != nullptr
        && state->selectExpression->is<IR::SelectExpression>())
        return true;
    return false;
}


bool ParserConverter::hasDefaultSelectCase(const IR::ParserState* state) const {
    if (hasSelectExpression(state)) {
        auto se = state->selectExpression->to<IR::SelectExpression>();
        for (auto cs : se->selectCases) {
            if (cs->keyset->is<IR::DefaultExpression>())
                return true;
        }
        return false;
    }
    return false;
}


const IR::Node* ParserConverter::postorder(IR::P4Parser* parser) {
    LOG3("ParserConverter postorder visit - "<<parser->name);
    auto type = parser->type;
    auto newApplyParams = type->getApplyParameters()->clone();

    newApplyParams->parameters.erase(newApplyParams->parameters.begin());
    auto pktParam = newApplyParams->getParameter(0);
    auto param = new IR::Parameter(pktParam->srcInfo, 
                                   IR::ID(pktParam->name.name), 
                                   IR::Direction::InOut,
                                   new IR::Type_Name(structTypeName));

    newApplyParams->parameters.replace(newApplyParams->parameters.begin(), param);

    IR::Type_Control* typeControl = new IR::Type_Control(type->srcInfo, 
        IR::ID(type->name.name), IR::Annotations::empty, 
        type->typeParameters->clone(), newApplyParams);

    auto controlLocals = new IR::IndexedVector<IR::Declaration>();
    for (auto decl : parser->parserLocals)
        controlLocals->push_back(decl->clone());
   
    controlLocals->append(actionDecls);
    controlLocals->push_back(tableDecl);

    auto controlBody =  new IR::BlockStatement(statOrDeclsOfControlBody);
    IR::P4Control* control = new IR::P4Control(parser->srcInfo, 
        IR::ID(parser->name.name), typeControl, parser->constructorParams->clone(),
        *controlLocals, controlBody);

    // std::cout<<*control<<"\n\n";
    return control;
}


// replace extractor.extract with assignments statements;
const IR::Node* ExtractSubstitutor::preorder(IR::MethodCallStatement* mcs) {
    auto expression = mcs->methodCall;
    P4::MethodInstance* mi = P4::MethodInstance::resolve(expression, refMap, typeMap);
    if (!mi->is<P4::ExternMethod>()) 
        return mcs;
    auto em = mi->to<P4::ExternMethod>();
    if (em->originalExternType->name.name != 
            P4::P4CoreLibrary::instance.extractor.name 
        || em->method->name.name != 
            P4::P4CoreLibrary::instance.extractor.extract.name)
        return mcs;
    
    auto arg1 = expression->arguments->at(1);
    auto valueMap = parserStateInfo->after;
    auto sv = valueMap->get(arg1->expression);
    auto shv = sv->to<P4::SymbolicHeader>();
    unsigned start, end;
    shv->getCoordinatesFromBitStream(start, end);
    //LOG3("extract"<<" = x.y["<<start<<", "<<end<<"]"<<"\n");
    
    auto asmtSmts = createPerFieldAssignmentStmts(arg1->expression, 
                                                  start+initOffset);
    auto newMember = new IR::Member(arg1->expression->clone(), 
                                    IR::Type_Header::setValid);
    auto mce = new IR::MethodCallExpression(newMember);
    auto setValidMCS =  new IR::MethodCallStatement(mce);

    auto retVec = new IR::IndexedVector<IR::StatOrDecl>();
    retVec->push_back(setValidMCS);
    retVec->append(asmtSmts);
    prune();
    return retVec;
}

std::vector<const IR::AssignmentStatement*>  
ExtractSubstitutor::createPerFieldAssignmentStmts(const IR::Expression* hdrVar, 
                                                   unsigned startOffset) {

    std::vector<const IR::AssignmentStatement*> retVec;
    auto type = typeMap->getType(hdrVar, true);
    BUG_CHECK(type->is<IR::Type_Header>(), "expected header type ");
    auto th = type->to<IR::Type_Header>();


    auto exp = new IR::Member(new IR::PathExpression(pktParamName), 
                                 IR::ID(fieldName));
    // auto member = new IR::Member(exp, IR::ID("data"));

    // unsigned start = (startOffset==0)? 0 : startOffset-1;

    unsigned start = startOffset;
    for (auto f : th->fields) {
        auto w = svf.getWidth(f->type);

        unsigned startByteIndex = start/8;
        unsigned startByteBitIndex = start % 8;

        // std::cout<<"startByteBitIndex "<<startByteBitIndex<<"\n";
        // std::cout<<"startByteIndex "<<startByteIndex<<"\n";

        std::vector<const IR::Expression*> byteExps;
        unsigned fwCounter = 0; // field width counter
        if (startByteBitIndex != 0) {
            auto bl = new IR::ArrayIndex(exp->clone(), 
                                         new IR::Constant(startByteIndex));

            auto mem = new IR::Member(bl, IR::ID("data"));
            const IR::Expression* initSlice = nullptr;
            if (w >= (8-startByteBitIndex)) {
                initSlice = IR::Slice::make(mem, startByteBitIndex, 7);
                fwCounter += (8-startByteBitIndex);
            } else {
                initSlice = IR::Slice::make(mem, startByteBitIndex, 
                                            startByteBitIndex+w-1);
                fwCounter += w;
            }
            startByteIndex++;
            byteExps.push_back(initSlice);
        }
        while (fwCounter+8 <= w) {
            auto pe = new IR::ArrayIndex(exp->clone(), 
                                         new IR::Constant(startByteIndex++));
            auto mem = new IR::Member(pe, IR::ID("data"));
            byteExps.push_back(mem);
            fwCounter += 8;
        }
        if (fwCounter < w) {
            auto bl = new IR::ArrayIndex(exp->clone(), 
                                         new IR::Constant(startByteIndex));
            auto mem = new IR::Member(bl, IR::ID("data"));
            auto endSlice = IR::Slice::make(mem, 0, w-fwCounter-1);
            byteExps.push_back(endSlice);
        }

        BUG_CHECK(byteExps.size() != 0, 
                  "Bug in creating byte concatenation expression");
        const IR::Expression* rh = nullptr;
        if (byteExps.size() > 1) {
            auto last = byteExps.back();        byteExps.pop_back();
            auto seclast = byteExps.back();     byteExps.pop_back();
            IR::Concat* concat = new IR::Concat(seclast, last);
            std::reverse(std::begin(byteExps), std::end(byteExps));
            for (auto e : byteExps) {
                IR::Concat* temp = concat; 
                concat = new IR::Concat(e, temp);
            }
            rh = concat;
        } else {
            rh = byteExps[0];
        }

        // auto slice = IR::Slice::make(member->clone(), start, start+w-1);

        start += w;
        auto lm = new IR::Member(hdrVar->clone(), IR::ID(f->getName()));
        auto as = new IR::AssignmentStatement(lm, rh);
        retVec.push_back(as);
    }
    return retVec;
}


}// namespace CSA
