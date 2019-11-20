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
    visit(type);
    prune();
    return p4Program;
}

const IR::Node* ParserConverter::preorder(IR::P4ComposablePackage* cp) {
    
    LOG3("ParserConverter preorder visit P4ComposablePackage: "<<cp->name);

    for (auto typeDecl : *(cp->packageLocals)) {
        if (typeDecl->is<IR::P4Parser>()) {
            visit(typeDecl);
            break;
        }
    }

    // new start offsets are computed and pushed on offsetsStack.
    auto currentParserOffsets = parserEval->result->getAcceptedPktOffsets();
    if (offsetsStack.empty()) { 
        offsetsStack.push_back(new std::vector<unsigned>(currentParserOffsets));
    } else {
        auto acceptedPktOffset = new std::vector<unsigned>();
        for (auto currentOffset : *(offsetsStack.back())) {
            for (auto o : currentParserOffsets) {
                acceptedPktOffset->push_back(currentOffset + o);
            }
        }
        offsetsStack.push_back(acceptedPktOffset);
    }

    // Any callee in control blocks will use above offsets( offsetsStack.back())
    for (auto typeDecl : *(cp->packageLocals)) {
        if (typeDecl->is<IR::P4Control>())
            visit(typeDecl);
    }

    // pop the offsets pushed by the parser of this composable package
    offsetsStack.pop_back();

    prune();
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
    varDecls.clear();  
    actionDecls.clear(); 
    tableDecls.clear();
    keyElementList.clear();
    actionList.clear();
    entryList.clear();
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


    /*
    for (auto o : *acceptedPktOffsets)
        std::cout<<o<<" ";
    */

    unsigned offset = parserEval->result->getPktMaxOffset();
    if (*bitMaxOffset < offset) {
        // std::cout<<"maxoffset "<<offset<<"\n";
        *bitMaxOffset = offset;
    }

    // moved pktParamName initialization to `preorder(IR::Parameter* param)`
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

    for(auto s : sorted)
        visit(s);

    auto method = new IR::Member(new IR::PathExpression(IR::ID(tableName)),
   			                                 IR::ID("apply"));
    auto mcea = new IR::MethodCallExpression(method, new IR::Vector<IR::Argument>());
    auto mcsa = new IR::MethodCallStatement(mcea);

    statOrDeclsOfControlBody.push_back(mcsa);
    LOG3("finished parser");
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


bool ParserConverter::stateIterator(IR::ParserState* state){
    //LOG3("ParserConverter::stateIterator "<<state->name.name<<"\n");
	  auto evaluatedInstances = parserEval->result->get(state->name);
		// prepapring KeyElementList
		std::list<std::unordered_set<cstring>> buckets;
		std::list<cstring> order;
		//preparing action list
    std::set<cstring> actions;
		//preparing entry list
		IR::Vector<IR::Expression> simpleExpressionList;

	  for (auto stateInfo : *evaluatedInstances) {
        auto oldKeysSize = keyElementList.size();
        // create actions + get keys bit placement
	      auto decl = actionDecls.getDeclaration(stateInfo->name);
	      if (decl != nullptr)
            continue;
        auto statOrDecl = state->components.clone();
	      ExtractSubstitutor extractSubstitutor(refMap, typeMap, stateInfo, 
                                              pktParamName, fieldName);
	      auto components = statOrDecl->apply(extractSubstitutor);
		    auto actionBlockStatements = *components;
        LOG3("evaluated instance "<< stateInfo->name);
	      if (toAppendStats.find(stateInfo->name)!= toAppendStats.end()) {
            auto toAppend = toAppendStats.find(stateInfo->name)->second;
	      	  actionBlockStatements.append(toAppend);
	      	  LOG3("appending to instance "<< stateInfo->name);
	      }
	      for (auto p: stateInfo->nextParserStateInfo) {
            toAppendStats.insert(std::pair<cstring, 
                                      IR::IndexedVector<IR::StatOrDecl>>
                                      (p.second->name, actionBlockStatements));
	      	  LOG3("adding info about what to append "<< p.second->name);
	      }

	      auto actionBlock = new IR::BlockStatement(actionBlockStatements);
	      auto action = new IR::P4Action(state->srcInfo, stateInfo->name,
                              new IR::ParameterList(), actionBlock);
        actionDecls.push_back(action);

	      if (stateInfo->predecessor == nullptr) {
	          auto pe = new IR::PathExpression(action->name.name);
	          auto mce = new IR::MethodCallExpression(pe, new IR::Vector<IR::Type>(),
	                                                  new IR::Vector<IR::Argument>());
	          auto mcs = new IR::MethodCallStatement(mce);
	          statOrDeclsOfControlBody.push_back(mcs);
	      }
        if (hasSelectExpression(state)) {
            // creating key matching based on expression list
	          auto se = state->selectExpression->to<IR::SelectExpression>();
            IR::PathExpression* matchType = nullptr;
	       		if (hasDefaultSelectCase(state))
                matchType = new IR::PathExpression("ternary");
            else
                matchType = new IR::PathExpression("exact");

	       		for (auto e : se->select->components) { // TODO optimize
                for (auto c : *components) {
                    if (c->is<IR::AssignmentStatement>()) {
                        auto stmt = c->to<IR::AssignmentStatement>();
                        if (e->clone()->toString() == ((*stmt).left)->toString()) {
                            auto selectKey = new IR::KeyElement((*stmt).right,  
                                                    matchType);
                            bool exists = false;
                            //LOG3("key expression to be added "<<(*stmt).right);
        	       						for (auto el: keyElementList) {
                                if (el == selectKey) {
                                    exists=true;
            	       								break;
                                }
	       						        }
	       						        if (!exists) {
                                keyElementList.push_back(selectKey);
                            }
    	       					  }
	           				}
	         			}
	       	  }
	      }
        if (state->name.name == IR::ParserState::accept || 
            state->name.name == IR::ParserState::reject)
            return false;
	      // add actions + entries
	  	  IR::Vector<IR::Entry> entries;
	  	  //LOG3("evaluated instances "<<stateInfo->name);
	  	  auto current = stateInfo->predecessor;

	  	  auto oldEntries = entryList.clone();
	  	  if (oldEntries->size() && oldKeysSize != keyElementList.size() && 
            stateInfo->nextParserStateInfo.size())
            entryList.clear();
	  	  bool appendDefaultEntry = false;
	  	  size_t counter = 0;
        for (auto kseNSI : stateInfo->nextParserStateInfo) {
            if (counter==(stateInfo->nextParserStateInfo).size()-1)
                appendDefaultEntry = true;
            auto nextStateInfo = kseNSI.second;
			      cstring actionName = nextStateInfo->name;
			      //LOG3("actionName"<< actionName);
			      auto itBool = actions.insert(actionName);
			      if (!itBool.second)
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
            auto caseKeysetExp = kseNSI.first;
		        //LOG3("matching value"<< caseKeysetExp);
    		    simpleExpressionList.clear();
		        if (oldKeysSize != keyElementList.size()) {
                // revisit all previously created entries
                // LOG3("old entries size"<< oldEntries->size());
      			    if (oldEntries->size()) {
                    for (auto e: *oldEntries) {
                        //LOG3("old entry"<< e);
                        auto keySetExpression = e->getKeys();
                        auto actionBinding = e->getAction();
					              simpleExpressionList = 
                          (keySetExpression->to<IR::ListExpression>())->components;
            					  // LOG3("action "<<actionBinding->toString() << "stateInfo"<<stateInfo->name);
					              if (actionBinding->toString() == stateInfo->name) {
						                // LOG3("same action editing whole entry");
                            // if action is this one then add depending on select + modify action in entry
						                if (hasSelectExpression(state)){
                                simpleExpressionList.push_back(caseKeysetExp);
                                //  LOG3("caseKeysetExp" << caseKeysetExp);
						                }
						                keySetExpression = new IR::ListExpression(simpleExpressionList);
  	          					    actionBinding = new IR::MethodCallExpression(
							                                new IR::PathExpression(actionName),
                              							  new IR::Vector<IR::Type>(), 
                                              new IR::Vector<IR::Argument>());
            						    auto entry = new IR::Entry(keySetExpression, 
                                                actionBinding);
                            //LOG3("entry added "<<entry);
                            entryList.push_back(entry);
                            // LOG3("binded action path expression"<< actionName);
					              } else if (appendDefaultEntry) {
                            // else add default value
                            //LOG3("not action, appending default");
                            simpleExpressionList.push_back(
                                                    new IR::DefaultExpression());
                            keySetExpression = new IR::ListExpression(
                                                      simpleExpressionList);
                            auto entry = new IR::Entry(keySetExpression, actionBinding);
                            //LOG3("entry added"<<entry);
                            entryList.push_back(entry);
					              }
				            }
			          } else {
                    if (hasSelectExpression(state)) {
                        simpleExpressionList.push_back(caseKeysetExp);
					              //LOG3("caseKeysetExp" << caseKeysetExp);
                    }
				            auto keySetExpression = new IR::ListExpression(simpleExpressionList);
                    auto actionBinding = new IR::MethodCallExpression(
                    new IR::PathExpression(actionName),
                    new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
                    //LOG3("binded action path expression"<< actionName);
                    auto entry = new IR::Entry(keySetExpression, actionBinding);
                    entryList.push_back(entry);
                }
		        }
		        counter++;
        }
	  }

		if(!tableDecls.size()){
        //action elements
        LOG3("Adding noAction");
        auto mce = new IR::MethodCallExpression(
                          new IR::PathExpression(noActionName), new 
                          IR::Vector<IR::Type>(),	new IR::Vector<IR::Argument>());
        auto actionRef = new IR::ActionListElement(mce);
        actionList.push_back(actionRef);
		}
	  return true;
}

const IR::Node* ParserConverter::preorder(IR::ParserState* state) {
    LOG3("ParserConverter preorder visit parser state- "<<state->name);

    if(stateIterator(state)){
				if(tablePropertyList.size()){
						tableDecls.clear();
						tablePropertyList.clear();
				}
				auto keyElementListProperty = new IR::Property(IR::ID("key"),
													new IR::Key(keyElementList), false);
				tablePropertyList.push_back(keyElementListProperty);
  
				for (auto a: actionList){
			  		LOG3("action list elemtn: "<<a->getName());
				}
				auto actionListProperty = new IR::Property(IR::ID("actions"),
													new IR::ActionList(actionList), false);
				tablePropertyList.push_back(actionListProperty);
  
				auto entriesListProperty = new IR::Property(IR::ID("entries"),
															new IR::EntriesList(entryList), true);
				tablePropertyList.push_back(entriesListProperty);
  
				if(!tableDecls.size()) {
            auto v = new IR::ExpressionValue(
                            new IR::MethodCallExpression(
                                    new IR::PathExpression(noActionName),
                                    new IR::Vector<IR::Argument>()));
				    auto defaultActionProp = new IR::Property(IR::ID("default_action"), 
                                            v, true);
				 	  tablePropertyList.push_back(defaultActionProp);
           
				 	  auto table = new IR::P4Table(IR::ID(tableName), 
                                new IR::TableProperties(tablePropertyList));
				 	  tableDecls.push_back(table);
				}
    }
    return state;
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
   
    controlLocals->append(varDecls);
    controlLocals->append(actionDecls);
    controlLocals->append(tableDecls);

    auto controlBody =  new IR::BlockStatement(statOrDeclsOfControlBody);
    IR::P4Control* control = new IR::P4Control(parser->srcInfo, 
        IR::ID(parser->name.name), typeControl, parser->constructorParams->clone(),
        *controlLocals, controlBody);
    
    std::cout<<*control<<"\n";

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
    
    auto asmtSmts = createPerFieldAssignmentStmts(arg1->expression, start);
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

/*

bool EvaluateAllParsers::preorder(const IR::P4Parser* parser) {
    // LOG3("EvaluateAllParsers preorder visit - "<<parser->name);
    auto parserEval = new P4::ParserStructure();
    P4::ParserRewriter rewriter(refMap, typeMap, true, parserEval);
    parser->apply(rewriter);

    auto offset = parserEval->result->getPacketInMaxOffset();
    if (*maxOffset < offset) {
        *maxOffset = offset;
    }

    parserEvalMap->emplace(parser, parserEval);

    return false;
}
*/

}// namespace CSA
