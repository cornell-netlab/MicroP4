/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "paraDeParMerge.h"

namespace CSA {

bool FindExtractedHeader::preorder(IR::MethodCallExpression* call) {
    P4::MethodInstance* method_instance = P4::MethodInstance::resolve(call, refMap, typeMap);
    if (!method_instance->is<P4::ExternMethod>()) {
        ::error("Expected an extract call but got a different statement %1", call);
    }

    auto externMethod = method_instance->to<P4::ExternMethod>();
    if (externMethod->originalExternType->name.name != 
            P4::P4CoreLibrary::instance.extractor.name 
        || externMethod->method->name.name != 
            P4::P4CoreLibrary::instance.extractor.extract.name) {
        ::error("call is not an extract call");
    }

    auto arg = call->arguments->at(1);
    if (!arg->is<IR::PathExpression>()) {
        ::error("argument %1 is not a path", arg);
    }
    extractedHeader = arg->to<IR::PathExpression>()->path;
    return true;
}
}
bool FindExtractedHeader::preorder(IR::StatOrDecl* statementOrDecl) { 
    if (!statementOrDecl->is<IR::MethodCallStatement>()) {
        /* fail: there's a statement that isn't an extract call */
        ::error("Expected an extract call but got %1", statementOrDecl);
    }
    auto statement = statementOrDecl->to<IR::MethodCallStatement>();
    visit(statement);
    return true;
}

const IR::Node* ParaParserMerge::preorder(IR::P4Parser* p4parser) {
    auto start_state1 = p4parser->states.getDeclaration<IR::ParserState>("start");
    auto start_state2 = p2->states.getDeclaration<IR::ParserState>("start");
    if (start_state1 != nullptr && start_state2 != nullptr) {
        currP2State = start_state2;
        visit(start_state1);
    } else {
        /* fail */
    }
    return p4parser;
}

const IR::Node* ParaParserMerge::postorder(IR::P4Parser* p4parser) {
    return p4parser;
}

const IR::Node* ParaParserMerge::preorder(IR::ParserState* state) {
    /* State
     * - state                the state in p1 we're looking at
     * - currp2state          the state in p2 we're looking at
     * - hdr_map1, hdr_map2   where we've put header types
     * - new_parser           the merged parser
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
    }
    if (state->name == IR::ParserState::reject) {
    }

    if (state->name == IR::ParserState::start) {
        if (currP2State->name == IR::ParserState::start) {
        } else {
            /* error: trying to match start state to a non-start state */
        }
    } else {
        /* state != start */
    }
    return state;
}
const IR::Node* ParaParserMerge::postorder(IR::ParserState* state) {
    return state;
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
