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


const IR::Node* ParserConverter::preorder(IR::P4Parser* parser) {
    LOG3("ParserConverter preorder visit - "<<parser->name);

    // refreshing varibales
    parserEval = new P4::ParserStructure();
    statOrDeclsOfControlBody.clear();
    varDecls.clear();  
    actionDecls.clear(); 
    tableDecls.clear();
    stateIDMap.clear();      

    P4::ParserRewriter rewriter(refMap, typeMap, true, parserEval);
    parser->apply(rewriter);

    unsigned offset = parserEval->result->getPacketInMaxOffset();
    if (*bitMaxOffset < offset) {
        // std::cout<<"maxoffset "<<offset<<"\n";
        *bitMaxOffset = offset;
    }

    

    auto param = parser->getApplyParameters()->getParameter(0);
    // TODO: check param is of packet_in type
    paketInParamName = param->name.name;

    auto callGraph = parserEval->callGraph;
    // std::cout<<"size : "<<callGraph->size()<<"\n";

    // Visit states in topological order
    std::vector<const IR::ParserState*> sorted;

    bool hasLoop = callGraph->sccSort(parserEval->start, sorted);
    BUG_CHECK(!hasLoop, "Parser %1% still has loops, unexpected situation.", 
                         parser->name.name);

    std::reverse(std::begin(sorted), std::end(sorted));

    for(auto s : sorted) {
        cstring stateVisitVariable = getStateVisitVarName(s);
        auto bitType = IR::Type::Bits::get(1, false);
        auto declVar = new IR::Declaration_Variable(stateVisitVariable, bitType,
                                                    new IR::Constant(0, 2)); 
        varDecls.push_back(declVar);
    }

    auto headerInvalidActionName = createHeaderInvalidAction(parser);
    auto pe = new IR::PathExpression(headerInvalidActionName);
    auto mce = new IR::MethodCallExpression(pe, new IR::Vector<IR::Type>(), 
                                           new IR::Vector<IR::Argument>());
    auto mcs = new IR::MethodCallStatement(mce);
    statOrDeclsOfControlBody.push_back(mcs);

    for(auto s : sorted)
        visit(s);
    return parser;
}

cstring ParserConverter::createHeaderInvalidAction(IR::P4Parser* parser) {

    cstring headerInvalidActionName = "csa_"+parser->name.name+"_"+"invalid_headers";
    auto statOrDeclList = new IR::IndexedVector<IR::StatOrDecl>();
    auto param =  parser->getApplyParameters()->parameters.at(1);
    auto type = typeMap->getType(param, true);
    BUG_CHECK(type->is<IR::Type_Struct>(), "%1% should be Struct type, but that error should be notified by now ", param->getName());
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

void ParserConverter::createP4Actions(IR::ParserState* state) {
    auto evaluatedInstances = parserEval->result->get(state->name);
    for (auto stateInfo : *evaluatedInstances) {
        auto decl = actionDecls.getDeclaration(stateInfo->name);
        if (decl != nullptr)
            continue;
        auto statOrDecl = state->components.clone();
        ExtractSubstitutor extract(refMap, typeMap, stateInfo, paketInParamName,
                                   fieldName);
        auto components = statOrDecl->apply(extract);
        auto nextTableVisitAssignment = new IR::AssignmentStatement(
            new IR::PathExpression(getStateVisitVarName(state)), 
            new IR::Constant(1, 2));
        auto actionBlockStatements = *components;
        actionBlockStatements.push_back(nextTableVisitAssignment);
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
    }
}

IR::Vector<IR::KeyElement>* ParserConverter::createKeyElementList(IR::ParserState* state) {
    // std::cout<<"ParserConverter::createKeyElementList "<<state->name.name<<"\n";
    auto evaluatedInstances = parserEval->result->get(state->name);
    // synthesising KeyElementList
    auto keyElementList = new IR::Vector<IR::KeyElement>();
    // synthesising keyelement from select expression
    // synthesising keyelement to capture previous transition history
    std::list<std::unordered_set<cstring>> buckets;

    std::list<cstring> order;
    for (auto stateInfo : *evaluatedInstances) {
        auto current = stateInfo->predecessor;
        order.clear();
        while(current != nullptr) {
            auto p4ParserState = current->state;
            cstring visitVarName = getStateVisitVarName(p4ParserState);
            // std::cout<<visitVarName<<" ";
            order.push_front(visitVarName);
            current = current->predecessor;
        }

        auto bucketIt = buckets.begin();

        for (auto ele : order) {
            if (bucketIt == buckets.end()) {
              std::unordered_set<cstring> s;
              s.insert(ele);
              buckets.push_back(s);
              bucketIt++; 
            } else {
              /*
                std::cout<<"\n -----bucket inter----- \n";
                for (auto b : *bucketIt)
                    std::cout<<b<<" ";
                std::cout<<"\n -----bucket inter----- \n";
              */  
                auto srch = (*bucketIt).find(ele);
                if (srch == (*bucketIt).end())
                    (*bucketIt).insert(ele);
            }
            bucketIt++; 
        }
    }

    // std::cout<<"\n[";
    for (auto l : buckets) {
        for (auto el : l) {
            auto stateVisitKey = new IR::KeyElement(
                new IR::PathExpression(el), new IR::PathExpression("exact"));
            keyElementList->push_back(stateVisitKey);
            // std::cout<<el<<",";
            keyElementOrder.push_back(el);
        }
    }
    // std::cout<<"]\n";
    // Adding guard key
    cstring selfVisitKey = getStateVisitVarName(state);
    auto nextTableKey = new IR::KeyElement(new IR::PathExpression(selfVisitKey),
                                           new IR::PathExpression("exact"));
    keyElementList->insert(keyElementList->begin(), nextTableKey);

    if (hasSelectExpression(state)) {
        auto se = state->selectExpression->to<IR::SelectExpression>();
        IR::PathExpression* matchType = nullptr;
        if (hasDefaultSelectCase(state))
            matchType = new IR::PathExpression("ternary");
        else
            matchType = new IR::PathExpression("exact");
        for (auto e : se->select->components) {
            auto selectKey = new IR::KeyElement(e->clone(), matchType);
            keyElementList->push_back(selectKey);
        }
    }
    return keyElementList;
}


IR::IndexedVector<IR::ActionListElement>* 
ParserConverter::createActionList(IR::ParserState* state) {
    auto evaluatedInstances = parserEval->result->get(state->name);
    // synthesising ActionList.
    // We need only action names, actions will be synthesised later
    auto actionList = new IR::IndexedVector<IR::ActionListElement>();
    std::set<cstring> actions;
    for (auto stateInfo : *evaluatedInstances) {
        for (auto kseNSI : stateInfo->nextParserStateInfo) {
            auto nextStateInfo = kseNSI.second;
            cstring actionName = nextStateInfo->name;
            auto itBool = actions.insert(actionName);
            if (!itBool.second)
                continue;
            auto mce = new IR::MethodCallExpression(
                new IR::PathExpression(actionName), new IR::Vector<IR::Type>(),
                new IR::Vector<IR::Argument>());
            auto actionRef = new IR::ActionListElement(mce);
            actionList->push_back(actionRef);
        }
    }

    auto mce = new IR::MethodCallExpression(
        new IR::PathExpression(noActionName), new IR::Vector<IR::Type>(),
        new IR::Vector<IR::Argument>());
    auto actionRef = new IR::ActionListElement(mce);
    actionList->push_back(actionRef);

    return actionList;
}

IR::Vector<IR::Entry>* ParserConverter::createEntryList(IR::ParserState* state) {
    // std::cout<<"createEntryList "<<state->name.name<<"\n";
    auto evaluatedInstances = parserEval->result->get(state->name);
    auto entryList = new IR::Vector<IR::Entry>();
    IR::Vector<IR::Expression> simpleExpressionList;
    for (auto stateInfo : *evaluatedInstances) {
        for (auto kseNSI : stateInfo->nextParserStateInfo) {
            auto caseKeysetExp = kseNSI.first;
            auto nextStateInfo = kseNSI.second;
            simpleExpressionList.clear();
            auto current = stateInfo->predecessor;
            // std::cout<<"size : "<<keyElementOrder.size()<<"\n";
            // for (auto e : keyElementOrder)
            //    std::cout<<e<<"  ";
            // std::cout<<"\n";
            auto it = keyElementOrder.end();
            // auto simpleExpressionList = new IR::Vector<IR::Expression>();
            while(it != keyElementOrder.begin()) {
                it--;
                IR::Expression* e = nullptr;
                cstring predStateVisitVar = "";
                if (current) {
                    predStateVisitVar = getStateVisitVarName(current->state);
                }
                if (*it == predStateVisitVar) {
                    e = new IR::Constant(1, 2);
                    current = current->predecessor;
                } else {
                    e = new IR::Constant(0, 2);
                }
                simpleExpressionList.insert(simpleExpressionList.begin(), e);
            }
            // for guard key match
            simpleExpressionList.insert(simpleExpressionList.begin(), 
                                        new IR::Constant(1, 2));
            if (hasSelectExpression(state)) 
                simpleExpressionList.push_back(caseKeysetExp);

            auto keySetExpression = new IR::ListExpression(simpleExpressionList);
            auto actionBinding = new IR::MethodCallExpression(
                new IR::PathExpression(nextStateInfo->name), 
                new IR::Vector<IR::Type>(), new IR::Vector<IR::Argument>());
            auto entry = new IR::Entry(keySetExpression, actionBinding);
            entryList->push_back(entry);
            // std::cout<<"\n";
        }
    }
    return entryList;
}

const IR::Node* ParserConverter::preorder(IR::ParserState* state) {
    LOG3("ParserConverter preorder visit - "<<state->name);
    
    keyElementOrder.clear();

    createP4Actions(state);

    if (state->name.name == IR::ParserState::accept 
        || state->name.name == IR::ParserState::reject)
        return state;

    LOG3("ParserConverter creating MAT - ");
    IR::IndexedVector<IR::Property> tablePropertyList;

    auto keyElementList = createKeyElementList(state);
    auto keyElementListProperty = new IR::Property(state->srcInfo, IR::ID("key"), 
                                        new IR::Key(*keyElementList), false);
    tablePropertyList.push_back(keyElementListProperty);

    auto actionList = createActionList(state);
    auto actionListProperty = new IR::Property(state->srcInfo, IR::ID("actions"), 
                                        new IR::ActionList(*actionList), false);
    tablePropertyList.push_back(actionListProperty);

    // And now, synthesising table entries
    auto entryList = createEntryList(state);
    auto entriesListProperty = new IR::Property(state->srcInfo, IR::ID("entries"), 
                                                new IR::EntriesList(*entryList), true);
    tablePropertyList.push_back(entriesListProperty);

    auto v = new IR::ExpressionValue(
                    new IR::MethodCallExpression(
                        new IR::PathExpression(noActionName), 
                    new IR::Vector<IR::Argument>()));
    auto defaultActionProp = new IR::Property(IR::ID("default_action"), v, true);
    tablePropertyList.push_back(defaultActionProp);

    cstring tableName = "csa_"+state->name.name+"_tbl";
    auto table = new IR::P4Table(IR::ID(tableName), new IR::TableProperties(tablePropertyList));
    tableDecls.push_back(table);

    auto method = new IR::Member(new IR::PathExpression(IR::ID(tableName)), 
                                 IR::ID("apply"));
    auto mce = new IR::MethodCallExpression(method, new IR::Vector<IR::Argument>());
    auto mcs = new IR::MethodCallStatement(mce);

    statOrDeclsOfControlBody.push_back(mcs);

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

    auto packetInParam = newApplyParams->getParameter(0);
    auto param = new IR::Parameter(packetInParam->srcInfo, 
                                   IR::ID(packetInParam->name.name), 
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
    
    return control;
}


// replace packet_in extract with assignments statements;
const IR::Node* ExtractSubstitutor::preorder(IR::MethodCallStatement* mcs) {
    auto expression = mcs->methodCall;
    P4::MethodInstance* mi = P4::MethodInstance::resolve(expression, refMap, typeMap);
    if (!mi->is<P4::ExternMethod>()) 
        return mcs;
    auto em = mi->to<P4::ExternMethod>();
    if (em->originalExternType->name.name != P4::P4CoreLibrary::instance.packetIn.name 
        || em->method->name.name != P4::P4CoreLibrary::instance.packetIn.extract.name)
        return mcs;
    
    // IR::AssignmentStatement* assignment = nullptr;
    auto arg0 = expression->arguments->at(0);
    auto valueMap = parserStateInfo->after;
    auto sv = valueMap->get(arg0->expression);
    auto shv = sv->to<P4::SymbolicHeader>();
    unsigned start, end;
    shv->getCoordinatesFromBitStream(start, end);
    // std::cout<<" = x.y["<<start<<", "<<end<<"]"<<"\n";
    
    /*
    auto member = new IR::Member(new IR::PathExpression(paketInParamName), 
                                 IR::ID(fieldName));
    auto slice = IR::Slice::make(member, ((start==0) ? start: start-1), end-1);
    assignment = new IR::AssignmentStatement(arg0->expression->clone(), slice);
    */
    //assignment->dbprint(std::cout);

    auto asmtSmts = createPerFieldAssignmentStmts(arg0->expression, start);

    auto newMember = new IR::Member(arg0->expression->clone(), 
                                    IR::Type_Header::setValid);
    auto mce = new IR::MethodCallExpression(newMember);
    auto setValidMCS =  new IR::MethodCallStatement(mce);

    auto retVec = new IR::IndexedVector<IR::StatOrDecl>();
    // retVec->push_back(assignment);
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


    auto exp = new IR::Member(new IR::PathExpression(paketInParamName), 
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
