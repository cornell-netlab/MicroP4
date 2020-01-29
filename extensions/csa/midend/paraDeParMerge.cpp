/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "paraDeParMerge.h"

namespace CSA {

/* FindExtractedHeader */
bool FindExtractedHeader::preorder(const IR::MethodCallExpression* call) {
    P4::MethodInstance* method_instance = P4::MethodInstance::resolve(call, refMap, typeMap);
    if (!method_instance->is<P4::ExternMethod>()) {
        ::error("Expected an extract call but got a different statement %1", call);
    }

    auto externMethod = method_instance->to<P4::ExternMethod>();
    if (externMethod->originalExternType->name.name !=
            P4::P4CoreLibrary::instance.extractor.name
        || externMethod->method->name.name !=
            P4::P4CoreLibrary::instance.extractor.extract.name) {
        ::error("Call %1 is not an extract call", call);
    }

    auto arg = call->arguments->at(1);
    if (!arg->is<IR::PathExpression>()) {
        ::error("argument %1 is not a path", arg);
    }
    extractedHeader = arg->to<IR::PathExpression>()->path;
    auto typ = typeMap->getType(arg);
    if (!typ->is<IR::Type_Header>()) {
        ::error("Type %1 of extract argument %2 is not a header", typ, arg);
    }
    extractedType = typ->to<IR::Type_Header>()->clone();
    return true;
}

bool FindExtractedHeader::preorder(const IR::StatOrDecl* statementOrDecl) {
    if (!statementOrDecl->is<IR::MethodCallStatement>()) {
        /* fail: there's a statement that isn't an extract call */
        ::error("Expected a method call but found %1", statementOrDecl);
    }
    auto statement = statementOrDecl->to<IR::MethodCallStatement>();
    visit(statement);
    return true;
}

/* ParaParserMerge */
const IR::Node* ParaParserMerge::preorder(IR::P4Parser* p4parser) {
    auto start_state1 = p4parser->states.getDeclaration<IR::ParserState>(IR::ParserState::start);
    auto start_state2 = p2->states.getDeclaration<IR::ParserState>(IR::ParserState::start);
    if (start_state1 != nullptr && start_state2 != nullptr) {
        currP2State = start_state2;
        visit(start_state1);
    } else {
        ::error("Could not find start state for parser 1 (%1) or parser 2 (%2)",
                start_state1, start_state2);
    }
    return p4parser;
}

void ParaParserMerge::visitByNames(cstring s1, cstring s2) {
    auto state1 = states1.getDeclaration<IR::ParserState>(s1);
    currP2State = states2.getDeclaration<IR::ParserState>(s2);
    visit(state1);
}

const IR::Node* ParaParserMerge::postorder(IR::P4Parser* p4parser) {
    return p4parser;
}

void ParaParserMerge::mapStates(cstring s1, cstring s2, cstring merged) {
    std::pair<cstring, cstring> s1s2(s1, s2);
    std::pair<cstring, std::pair<cstring, cstring>> entry(merged, s1s2);
    stateMap.insert(entry);
}

std::vector<std::pair<IR::SelectCase*, IR::SelectCase*>>
ParaParserMerge::matchCases(IR::Vector<IR::SelectCase> cases1,
			    IR::Vector<IR::SelectCase> cases2) {
  ::error("matchCases(%1, %2) unimplemented", cases1, cases2);
  std::vector<std::pair<IR::SelectCase*, IR::SelectCase*>> ret({});
  return ret;
}

const IR::Node* ParaParserMerge::preorder(IR::ParserState* state) {
    /* State
     * - state                the state in p1 we're looking at
     * - currP2State          the state in p2 we're looking at
     * - hdr_map1, hdr_map2   where we've put header types
     * - stateMap            where states in the merged parser came from
     */

    /*
     * States s1, s2 each extract one header h1, h2.
     *
     * Check that h1 is equivalent to h2 (same size, or same # of fields and
     * types of fields, or whatever).
     *
     * Look at the transitions taken by s1, s2.
     *
     * If they are both doing an unconditional transition to new states t1, t2,
     * then visit (t1, t2).
     *
     * If they are selecting on different things, ??
     *
     * If they are selecting on the same thing h.f, match up the cases.
     *
     * For each case COND => s1', s2' that matches, visit (s1, s2).
     *
     * For any cases with no match, copy the states and all their descendants
     * into the merged parser.
     */

    if (state->name == IR::ParserState::accept) {
        ::error("unimplemented");
    } else if (state->name == IR::ParserState::reject) {
        ::error("unimplemented");
    } else {
        FindExtractedHeader hd1 = FindExtractedHeader(refMap1, typeMap1);
        FindExtractedHeader hd2 = FindExtractedHeader(refMap2, typeMap2);
        state->apply(hd1);
        currP2State->apply(hd2);

        mergeHeaders(hd1.extractedHeader, hd1.extractedType,
                     hd2.extractedHeader, hd2.extractedType);
        mapStates(state->name, currP2State->name, state->name);

        auto sel1 = state->selectExpression;
        auto sel2 = currP2State->selectExpression;
        if (sel1 == nullptr) {
            ::error("Parser state %1 has no transition statement", state);
        }
        if (sel2 == nullptr) {
            ::error("Parser state %1 has no transition statement", currP2State);
        }

        if (sel1->is<IR::PathExpression>()) {
            auto next_path1 = sel1->to<IR::PathExpression>();
            next_path1->validate();
            if (next_path1->path->name.name == IR::ParserState::accept) {
                /* replace transition with the transition statement of p2
                 * and copy all following states in p2 */
                ::error("unimplemented");
            }
            if (!sel2->is<IR::PathExpression>()) {
                ::error("unconditional transition %1 incompatible with %2",
                        sel1, sel2);
            }
            auto next_path2 = sel2->to<IR::PathExpression>();
            next_path2->validate();
            visitByNames(next_path1->path->name.name,
                         next_path2->path->name.name);
        } else if (sel1->is<IR::SelectExpression>()) {
            auto sel1expr = sel1->to<IR::SelectExpression>();
            auto cases1 = sel1expr->selectCases;
            if (sel2->is<IR::PathExpression>()) {
                auto next_path2 = sel2->to<IR::PathExpression>();
                next_path2->validate();
                if (next_path2->path->name.name != IR::ParserState::accept) {
                    ::error("unconditional transition %1 incompatible with %2",
                            sel2, sel1);
                }
                /* keep current transition and all following states */
            } if (sel2->is<IR::SelectExpression>()) {
                auto sel2expr = sel2->to<IR::SelectExpression>();
                auto cases2 = sel2expr->selectCases;
		auto casePairs = matchCases(cases1, cases2);
		for (auto &casePair : casePairs) {
		    auto c1 = casePair.first;
		    auto c2 = casePair.second;
		    /* add to select of output state */
		    /* recur on states pointed to here */
		    if (c1 == nullptr) {
			::error("unimplemented");
		    } else if (c2 == nullptr) {
			::error("unimplemented");
		    } else {
			cstring name1 = c1->state->path->name.name;
			cstring name2 = c1->state->path->name.name;
			visitByNames(name1, name2);
		    }
		}
            }
        } else {
            ::error("don't know how to handle this select expression: %1", sel1);
        }
    }
    return state;
}

const IR::Node* ParaParserMerge::postorder(IR::ParserState* state) {
    return state;
}

IR::Path* ParaParserMerge::mergeHeaders(const IR::Path *h1,
        IR::Type_Header *type1, const IR::Path *h2, IR::Type_Header *type2) {
    ::error("mergeHeaders unimplemented %1 %2 %3 %4",
            h1, type1, h2, type2);
    return nullptr;
}

const IR::Node* ParaDeParMerge::preorder(IR::P4Control* p4control) {
    return p4control;
}

const IR::Node* ParaDeParMerge::postorder(IR::P4Control* p4control) {
    return p4control;
}

const IR::Node* ParaDeParMerge::preorder(IR::P4Parser* p4parser) {
    return p4parser;
}

const IR::Node* ParaDeParMerge::postorder(IR::P4Parser* p4parser) {
    return p4parser;
}

const IR::Node* ParaDeParMerge::preorder(IR::P4ComposablePackage* p4cp) {
    return p4cp;
}

const IR::Node* ParaDeParMerge::postorder(IR::P4ComposablePackage* p4cp) {
    return p4cp;
}


}// namespace CSA
