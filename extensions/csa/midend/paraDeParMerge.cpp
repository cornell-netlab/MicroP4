/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "paraDeParMerge.h"

namespace CSA {

/* CollectStates */
bool CollectStates::preorder(const IR::ParserState* state) {
    states.push_back(state);
    visit(state->selectExpression);
    return false;
}

bool CollectStates::preorder(const IR::PathExpression* pathExpression) {
    auto state = allStates.getDeclaration<IR::ParserState>(pathExpression->path->name.name);
    visit(state);
    return false;
}

bool CollectStates::preorder(const IR::SelectExpression* selectExpression) {
    std::vector<cstring> stateNames;
    auto selectCases = selectExpression->selectCases;
    for (auto &selectCase : selectCases) {
        stateNames.push_back(selectCase->state->path->name.name);
    }
    for (auto &stateName : stateNames) {
        auto state = allStates.getDeclaration<IR::ParserState>(stateName);
        visit(state);
    }
    return false;
}

/* FindExtractedHeader */
bool FindExtractedHeader::preorder(const IR::MethodCallExpression* call) {
    if (extractedHeader != nullptr) {
        ::error("Already found extracted header %1%, what is this node: %2% (%3%)", extractedHeader, call, call->arguments);
    }

    P4::MethodInstance* method_instance = P4::MethodInstance::resolve(call, refMap, typeMap);
    if (!method_instance->is<P4::ExternMethod>()) {
        ::error("Expected an extract call but got a different statement %1%", call);
    }

    auto externMethod = method_instance->to<P4::ExternMethod>();
    if (externMethod->originalExternType->name.name !=
            P4::P4CoreLibrary::instance.extractor.name
        || externMethod->method->name.name !=
            P4::P4CoreLibrary::instance.extractor.extract.name) {
        ::error("Call %1% is not an extract call", call);
    }

    if (call->arguments->size() > 2) {
        ::error("Extract call %1% has too many arguments", call);
    } else if (call->arguments->size() < 2) {
        ::error("Extract call %1% has too few arguments", call);
    }

    extractedHeader = call->arguments->at(1)->expression;
    auto typ = typeMap->getType(extractedHeader);

    if (!typ->is<IR::Type_Header>()) {
        ::error("Type %1% of extract argument %2% is not a header", typ, extractedHeader);
    }

    return true;
}

/* ParaParserMerge */
const IR::Node* ParaParserMerge::preorder(IR::P4Parser* p4parser) {
    LOG2("old parser 1: " << p4parser);
    LOG2("old parser 2: " << p2);

    states1 = p4parser->states;
    states2 = p2->states;

    visitByNames(IR::ParserState::start, IR::ParserState::start);

    auto newStates = p4parser->states.clone();
    for (auto &updatedState : *statesToChange)  {
        newStates->removeByName(updatedState->name);
        newStates->pushBackOrAppend(updatedState);
    }
    statesToChange->clear();
    newStates->pushBackOrAppend(statesToAdd);
    statesToAdd->clear();

    p4parser->states = *newStates;
    LOG2("new parser: " << p4parser);

    prune();
    return p4parser;
}

const IR::Node* ParaParserMerge::postorder(IR::P4Parser* p4parser) {
    return p4parser;
}

void ParaParserMerge::visitByNames(cstring s1, cstring s2) {
    BUG_CHECK(s1 != nullptr, "State 1 name is null");
    auto state1 = states1.getDeclaration<IR::ParserState>(s1);
    BUG_CHECK(state1 != nullptr, "state %1% not found", s1);

    BUG_CHECK(s2 != nullptr, "State 2 name is null");
    currP2State = states2.getDeclaration<IR::ParserState>(s2);
    BUG_CHECK(currP2State != nullptr, "state %1% not found", s2);

    visit(state1);
}

void ParaParserMerge::mapStates(cstring s1, cstring s2, cstring merged) {
    std::pair<cstring, cstring> s1s2(s1, s2);
    std::pair<cstring, std::pair<cstring, cstring>> entry(merged, s1s2);
    stateMap.insert(entry);
}

bool ParaParserMerge::keysetsEqual(const IR::Expression *e1, const IR::Expression *e2) {
    ::error("keysetsEqual(%1%, %2%) unimplemented", e1, e2);
    return false;
}

std::vector<std::pair<IR::SelectCase*, IR::SelectCase*>>
ParaParserMerge::matchCases(IR::Vector<IR::SelectCase> cases1,
                            IR::Vector<IR::SelectCase> cases2) {
    std::vector<std::pair<IR::SelectCase*, IR::SelectCase*>> ret;
    for (auto case1ref : cases1) {
        IR::SelectCase *case1 = case1ref->clone();
        auto *matched = new std::pair<IR::SelectCase*, IR::SelectCase*>(case1, nullptr);
        for (auto case2ref : cases2) {
            IR::SelectCase *case2 = case2ref->clone();
            if (keysetsEqual(case1->keyset, case2->keyset)) {
                matched->second = case2;
                break;
            }
        }
        ret.push_back(*matched);
    }
    return ret;
}

bool ParaParserMerge::statesMapped(const IR::ParserState *s1, const IR::ParserState *s2) {
    cstring s1n = s1 == nullptr ? nullptr : s1->name;
    cstring s2n = s2 == nullptr ? nullptr : s2->name;
    std::pair<cstring, cstring> val(s1n, s2n);
    for (auto &entry : stateMap) {
        if (entry.second == val) {
            return true;
        }
    }
    return false;
}

const IR::Node* ParaParserMerge::preorder(IR::ParserState* state) {
    if (statesMapped(state, currP2State)) {
        /* We've already merged these states, don't change anything */
        return state;
    }

    FindExtractedHeader hd1(refMap1, typeMap1);
    FindExtractedHeader hd2(refMap2, typeMap2);
    state->apply(hd1);
    currP2State->apply(hd2);

    mergeHeaders(hd1.extractedHeader, hd2.extractedHeader);
    mapStates(state->name, currP2State->name, state->name);

    visit(state->selectExpression);
    return state;
}

const IR::Node* ParaParserMerge::preorder(IR::PathExpression* pathExpression) {
    if (getContext() == nullptr || !getContext()->node->is<IR::ParserState>()) {
        return pathExpression;
    }
    auto state1 = getContext()->node->to<IR::ParserState>();
    auto sel1 = pathExpression;
    auto sel2 = currP2State->selectExpression;

    BUG_CHECK(sel1 != nullptr, "Parser state %1% has no transition statement", state1);
    BUG_CHECK(sel2 != nullptr, "Parser state %1% has no transition statement", currP2State);

    if (sel1->path->name.name == IR::ParserState::accept) {
        LOG4("sel1 goes to accept");
        /* transition 1 is `transition accept;`. */
        CollectStates collector(states2);
        LOG4("collecting states from " << sel2);
        sel2->apply(collector);
        for (auto &state : collector.states) {
            LOG4("collected state: " << state->name);
            FindExtractedHeader hd(refMap2, typeMap2);
            state->apply(hd);
            if (state->name == IR::ParserState::accept) {
                continue;
            }
            mergeHeaders(nullptr, hd.extractedHeader);
            mapStates(nullptr, state->name, state->name);
            LOG4("adding state " << state);
            statesToAdd->push_back(state);
        }
        auto newState = state1->clone();
        newState->selectExpression = currP2State->selectExpression;
        statesToChange->push_back(newState);
        return pathExpression;
    }

    if (sel1->path->name.name == IR::ParserState::reject) {
        P4C_UNIMPLEMENTED("handling reject transitions in parser merge");
    }

    /* transition 1 is `transition sel1`, where sel1
       is a real state name defined in parser 1. */
    if (!sel2->is<IR::PathExpression>()) {
        ::error("unconditional transition %1% incompatible with %2%",
                sel1, sel2);
    }
    auto next_path2 = sel2->to<IR::PathExpression>();
    next_path2->validate();
    LOG4("nextpath1 name: " << sel1->path->name.name);
    LOG4("nextpath2 name: " << next_path2->path->name.name);
    visitByNames(sel1->path->name.name,
                 next_path2->path->name.name);
    return pathExpression;
}

const IR::Node* ParaParserMerge::preorder(IR::SelectExpression* selectExpression) {
    if (getContext() == nullptr) {
        LOG5("No context: " << selectExpression);
        return selectExpression;
    }
    auto state1 = getContext()->node;
    auto state2 = currP2State;
    if (!state1->is<IR::ParserState>()) {
        LOG5("Context is not a ParserState: " << selectExpression);
        return selectExpression;
    }
    auto sel1 = selectExpression;
    auto sel2 = state2->selectExpression;
    if (sel1 == nullptr) {
        BUG("Parser state ", state1, " has no transition statement");
    }
    if (sel2 == nullptr) {
        BUG("Parser state ", state2, " has no transition statement");
    }

    auto sel1expr = sel1->to<IR::SelectExpression>();
    auto cases1 = sel1expr->selectCases;
    if (sel2->is<IR::PathExpression>()) {
        auto next_path2 = sel2->to<IR::PathExpression>();
        LOG4("found sel2 pathExpression" << next_path2);
        next_path2->validate();
        if (next_path2->path->name.name != IR::ParserState::accept) {
            ::error("unconditional transition %1% incompatible with %2%",
                    sel2, sel1);
        }
        CollectStates collector(states1);
        sel1->apply(collector);
        for (auto &state : collector.states) {
            FindExtractedHeader hd(refMap1, typeMap1);
            state->apply(hd);
            mergeHeaders(hd.extractedHeader, nullptr);
            mapStates(state->name, nullptr, state->name);
        }
        return selectExpression;
    } else if (sel2->is<IR::SelectExpression>()) {
        auto sel2expr = sel2->to<IR::SelectExpression>();
        auto cases2 = sel2expr->selectCases;
        auto casePairs = matchCases(cases1, cases2);
        for (auto &casePair : casePairs) {
            auto c1 = casePair.first;
            auto c2 = casePair.second;
            /* add to select of output state */
            /* recur on states pointed to here */
            if (c1 == nullptr) {
                if (c2 == nullptr) {
                    BUG("Bug in matchCases!");
                }
                auto st = states2.getDeclaration<IR::ParserState>(c2->state->path->name.name);
                CollectStates collector(states2);
                st->apply(collector);
                for (auto &state : collector.states) {
                    FindExtractedHeader hd(refMap2, typeMap2);
                    state->apply(hd);
                    mergeHeaders(nullptr, hd.extractedHeader);
                    mapStates(nullptr, state->name, state->name);
                    LOG4("adding state" << state);
                    statesToAdd->push_back(state);
                }
                selectExpression->selectCases.pushBackOrAppend(c2);
            } else {
                LOG4("setting p2case" << c2);
                currP2Case = c2;
                visit(c1);
            }
        }
        return selectExpression;
    } else {
        ::error("don't know how to handle this select expression: %1%", sel2);
        return sel2;
    }
}

const IR::Node* ParaParserMerge::preorder(IR::SelectCase* case1) {
    auto caseStateName = case1->state->path->name.name;
    auto st = states1.getDeclaration<IR::ParserState>(caseStateName);
    if (currP2Case == nullptr) {
        CollectStates collector(states1);
        st->apply(collector);
        for (auto &state : collector.states) {
            if (state->name != IR::ParserState::accept) {
                FindExtractedHeader hd(refMap1, typeMap1);
                state->apply(hd);
                mergeHeaders(hd.extractedHeader, nullptr);
                mapStates(state->name, nullptr, state->name);
            }
        }
    } else {
        auto caseStateName2 = currP2Case->state->path->name.name;
        LOG4("caseStateName: " << caseStateName);
        LOG4("caseStateName2: " << caseStateName2);
        visitByNames(caseStateName, caseStateName2);
    }
    LOG4("resetting p2case");
    currP2Case = nullptr;
    return case1;
}

IR::Expression* ParaParserMerge::mergeHeaders(const IR::Expression *h1, const IR::Expression *h2) {
    LOG4("mergeHeaders: \n  " << h1 << "\n  " << h2);
    if (h1 != nullptr) {
        return h1->clone();
    } else if (h2 != nullptr) {
        return h2->clone();
    } else {
        BUG("mergeHeaders(nullptr, nullptr)");
    }
}

void ParaParserMerge::end_apply(const IR::Node* n) {
}

const IR::Node* ParaDeParMerge::preorder(IR::P4Control* p4control) {
    return p4control;
}

const IR::Node* ParaDeParMerge::preorder(IR::P4Parser* p4parser) {
    return p4parser;
}

const IR::Node* ParaDeParMerge::preorder(IR::P4ComposablePackage* p4cp) {
    return p4cp;
}

const IR::Node* HardcodedMergeTest::preorder(IR::P4Parser* parser) {
    if (other_parser != nullptr) {
        ParaParserMerge merger(refMap, typeMap, refMap, typeMap, other_parser);
        prune();
        auto parser2 = parser->apply(merger);
        LOG2("newer parser: " << parser2);
        return parser2;
    } else {
        other_parser = parser;
    }
    return parser;
}


}// namespace CSA
