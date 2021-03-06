#include "parserUnroll.h"
#include "lib/stringify.h"

namespace P4 {

bool AnalyzeParser::preorder(const IR::ParserState* state) {
    // LOG1("Found state " << state << " of " << current->parser);
    if (state->name.name == IR::ParserState::start)
        current->start = state;
    current->addState(state);
    return true;
}


void AnalyzeParser::postorder(const IR::PathExpression* expression) {
    auto state = findContext<IR::ParserState>();
    if (state == nullptr) {
        return;
    }
    auto decl = refMap->getDeclaration(expression->path);
    if (decl->is<IR::ParserState>())
        current->calls(state, decl->to<IR::ParserState>());
}


bool CreateXoredHeaderSets::preorder(const IR::P4Parser* parser) {
  
    CHECK_NULL(parserStructure->callGraph);
    auto callGraph = parserStructure->callGraph;
    while (callGraph->size() > 0) {
        auto zeroDegNodes = callGraph->getNodesWithoutIncomingEdge();
        xoredHeaderSet.clear();
        for (auto n : zeroDegNodes) {
            visit(n);
            callGraph->remove(n);
        }
        parserStructure->xoredHeaderSets->push_back(xoredHeaderSet);
    }

    AnalyzeParser ap(refMap, parserStructure);
    parser->apply(ap);
    return false;
}

bool CreateXoredHeaderSets::preorder(const IR::ParserState* state) {
    visit(state->components);
    return false;
}


bool CreateXoredHeaderSets::preorder(const IR::MethodCallStatement* mcs) {
    MethodInstance* mi = MethodInstance::resolve(mcs, refMap, typeMap);
    if (!mi->is<ExternMethod>()) 
        return false;
    auto em = mi->to<ExternMethod>();
    if (em->originalExternType->name.name != 
        P4CoreLibrary::instance.extractor.name ||
        em->method->name.name !=  
        P4CoreLibrary::instance.extractor.extract.name)
      return false;
    auto arg1 = mcs->methodCall->arguments->at(1);
    auto arg1Mem = arg1->expression->to<IR::Member>();
    auto hdrInstName = arg1Mem->member;
    xoredHeaderSet.insert(hdrInstName);
    // std::cout<<"CreateXoredHeaderSets "<<hdrInstName<<"\n";
    parserStructure->parsedHeaders->insert(hdrInstName.name);

    /*
     * auto argType = typeMap->getType(arg1, true);
     * auto hdrType = argType->to<IR::Type_Header>();
     */
    return false;
}


std::map<cstring, unsigned> ParserStateInfo::stateNameIndices = {};

/////////////////////////////////////

namespace ParserStructureImpl {

/* Dead Code
// Set of possible definitions of a variable
struct VarDef {
    const SymbolicValue* leftValue;
    std::vector<const IR::Node*> definitions;  // statements or parameters
};

// Definitions for all variables at a program point
struct Definitions {
    std::map<const SymbolicValue*, VarDef*> definitions;
    void add(VarDef* def)
    { definitions[def->leftValue] = def; }
};

// For each program point the definitions of all variables
struct AllDefinitions {
    std::map<const IR::Node*, Definitions*> perStatement;
};
*/



class ParserSymbolicInterpreter {
    ParserStructure*    structure;
    const IR::P4Parser* parser;
    ReferenceMap*       refMap;
    TypeMap*            typeMap;
    SymbolicValueFactory* factory;
    ParserInfo*         synthesizedParser;  // output produced
    bool                unroll;

    ValueMap* initializeVariables() {
        ValueMap* result = new ValueMap();
        ExpressionEvaluator ev(refMap, typeMap, result);

        for (const auto p : parser->getApplyParameters()->parameters) {
            auto type = typeMap->getType(p);
            bool initialized = p->direction == IR::Direction::In ||
                    p->direction == IR::Direction::InOut;
            auto value = factory->create(type, !initialized);
            result->set(p, value);
        }
        for (auto d : parser->parserLocals) {
            auto type = typeMap->getType(d);
            SymbolicValue* value = nullptr;
            if (d->is<IR::Declaration_Constant>()) {
                auto dc = d->to<IR::Declaration_Constant>();
                value = ev.evaluate(dc->initializer, false);
            } else if (d->is<IR::Declaration_Variable>()) {
                auto dv = d->to<IR::Declaration_Variable>();
                if (dv->initializer != nullptr)
                    value = ev.evaluate(dv->initializer, false);
            }

            if (value == nullptr)
                value = factory->create(type, true);
            if (value->is<SymbolicError>()) {
                ::error("%1%: %2%", d, value->to<SymbolicError>()->message());
                return nullptr;
            }
            if (value != nullptr)
                result->set(d, value);
        }
        return result;
    }

    ParserStateInfo* newStateInfo(const ParserStateInfo* predecessor,
                                  cstring stateName, ValueMap* values) {
        auto name = stateName;
        auto state = structure->get(stateName);
        if (stateName != IR::ParserState::accept &&
            stateName != IR::ParserState::reject)
            name = ParserStateInfo::GetStateNameWithIndex(stateName);
        else 
            name = "csa_"+stateName;

        auto pi = new ParserStateInfo(name, parser, state, predecessor, values->clone());
        synthesizedParser->add(pi);
        return pi;
    }

    static void stateChain(const ParserStateInfo* state, std::stringstream& stream) {
        if (state->predecessor != nullptr) {
            stateChain(state->predecessor, stream);
            stream << ", ";
        }
        stream << state->state->externalName();
    }

    static cstring stateChain(const ParserStateInfo* state) {
        CHECK_NULL(state);
        std::stringstream result;
        result << "Parser " << state->parser->externalName() << " state chain: ";
        stateChain(state, result);
        return result.str();
    }

    // Return false if an error can be detected statically
    bool reportIfError(const ParserStateInfo* state, SymbolicValue* value) const {
        if (value->is<SymbolicException>()) {
            auto exc = value->to<SymbolicException>();

            bool stateClone = false;
            auto orig = state->state;
            auto crt = state;
            while (crt->predecessor != nullptr) {
                crt = crt->predecessor;
                if (crt->state == orig) {
                    stateClone = true;
                    break;
                }
            }

            if (!stateClone)
                // errors in the original state are signalled
                ::error("%1%: error %2% will be triggered\n%3%",
                        exc->errorPosition, exc->message(), stateChain(state));
            // else this error will occur in a clone of the state produced
            // by unrolling - if the state is reached.  So we don't give an error.
            return false;
        }
        if (!value->is<SymbolicStaticError>())
            return true;
        auto ev = value->to<SymbolicStaticError>();
        ::error("%1%: %2%\n%3%", ev->errorPosition, ev->message(), stateChain(state));
        return false;
    }

    // Executes symbolically the specified statement.
    // Returns 'true' if execution completes successfully,
    // and 'false' if an error occurred.
    bool executeStatement(const ParserStateInfo* state, const IR::StatOrDecl* sord,
                          ValueMap* valueMap) const {
        ExpressionEvaluator ev(refMap, typeMap, valueMap);

        bool success = true;
        if (sord->is<IR::AssignmentStatement>()) {
            auto ass = sord->to<IR::AssignmentStatement>();
            auto left = ev.evaluate(ass->left, true);
            success = reportIfError(state, left);
            if (success) {
                auto right = ev.evaluate(ass->right, false);
                success = reportIfError(state, right);
                if (success)
                    left->assign(right);
            }
        } else if (sord->is<IR::MethodCallStatement>()) {
            // can have side-effects
            auto mc = sord->to<IR::MethodCallStatement>();
            auto e = ev.evaluate(mc->methodCall, false);
            success = reportIfError(state, e);
        } else {
            BUG("%1%: unexpected declaration or statement", sord);
        }
        LOG2("After " << sord << " state is\n" << valueMap);
        return success;
    }

    std::vector<ParserStateInfo*>* evaluateSelect(ParserStateInfo* state) {
        // TODO: update next state map
        auto select = state->state->selectExpression;
        if (select == nullptr)
            return nullptr;
        auto result = new std::vector<ParserStateInfo*>();
        if (select->is<IR::PathExpression>()) {
            auto path = select->to<IR::PathExpression>()->path;
            auto next = refMap->getDeclaration(path);
            BUG_CHECK(next->is<IR::ParserState>(), "%1%: expected a state", path);
            auto nextInfo = newStateInfo(state, next->getName(), state->after);
            state->nextParserStateInfo.emplace_back(nullptr, nextInfo);
            result->push_back(nextInfo);
        } else if (select->is<IR::SelectExpression>()) {
            // TODO: really try to match cases; today we are conservative
            // evaluate ListExpression member "select" 
            auto se = select->to<IR::SelectExpression>();
            // se->select; // ListExpression
            for (auto c : se->selectCases) {
                auto path = c->state->path;
                auto next = refMap->getDeclaration(path);
                BUG_CHECK(next->is<IR::ParserState>(), "%1%: expected a state", path);
                auto nextInfo = newStateInfo(state, next->getName(), state->after);
                state->nextParserStateInfo.emplace_back(c->keyset, nextInfo);
                result->push_back(nextInfo);
            }
        } else {
            BUG("%1%: unexpected expression", select);
        }
        return result;
    }

    static bool headerValidityChanged(const SymbolicValue* first, const SymbolicValue* second) {
        CHECK_NULL(first); CHECK_NULL(second);
        if (first->is<SymbolicHeader>()) {
            auto fhdr = first->to<SymbolicHeader>();
            auto shdr = second->to<SymbolicHeader>();
            CHECK_NULL(shdr);
            return !fhdr->valid->equals(shdr->valid);
        } else if (first->is<SymbolicArray>()) {
            auto farray = first->to<SymbolicArray>();
            auto sarray = second->to<SymbolicArray>();
            CHECK_NULL(sarray);
            for (size_t i = 0; i < farray->size; i++) {
                auto hdr = farray->get(nullptr, i);
                auto newHdr = sarray->get(nullptr, i);
                if (headerValidityChanged(hdr, newHdr))
                    return true;
            }
        } else if (first->is<SymbolicStruct>()) {
            auto fstruct = first->to<SymbolicStruct>();
            auto sstruct = second->to<SymbolicStruct>();
            CHECK_NULL(sstruct);
            for (auto f : fstruct->fieldValue) {
                auto ffield = fstruct->get(nullptr, f.first);
                auto sfield = sstruct->get(nullptr, f.first);
                if (headerValidityChanged(ffield, sfield))
                    return true;
            }
        }

        return false;
    }

    // True if any header has changed its "validity" bit
    static bool headerValidityChange(const ValueMap* before, const ValueMap* after) {
        for (auto v : before->map) {
            auto value = v.second;
            if (headerValidityChanged(value, after->get(v.first)))
                return true;
        }
        return false;
    }

    // Return true if we have detected a loop we cannot unroll
    bool checkLoops(ParserStateInfo* state) const {
        const ParserStateInfo* crt = state;
        while (true) {
            crt = crt->predecessor;
            if (crt == nullptr)
                break;
            if (crt->state == state->state) {
                LOG1("Loop detected at original parser state name : " << state->state->name);
                // Loop detected.
                // Check if any packet in the valueMap has changed
                auto filter = [](const IR::IDeclaration*, const SymbolicValue* value)
                        { return value->is<SymbolicPacketIn>(); };
                auto filterPkt = [](const IR::IDeclaration*, const SymbolicValue* value)
                        { return value->is<SymbolicPkt>(); };
                auto packets = state->before->filter(filter);
                auto prevPackets = crt->before->filter(filter);

                auto pkts = state->before->filter(filterPkt);
                auto prevPkts = crt->before->filter(filterPkt);

                if ((!packets->empty() || !prevPackets->empty()) && packets->equals(prevPackets)) {
                    bool conservative = false;
                    for (auto p : state->before->map) {
                        auto pkt = p.second->to<SymbolicPacketIn>();
                        if (pkt->isConservative()) {
                            conservative = true;
                            break;
                        }
                    }

                    if (conservative)
                        ::warning("Potential parser cycle without extracting any bytes:\n%1%",
                                  stateChain(state));
                    else
                        ::error("Parser cycle without extracting any bytes:\n%1%",
                                stateChain(state));
                    return true;
                }

                if ((!pkts->empty() || !prevPkts->empty()) && pkts->equals(prevPkts)) {
                    bool conservative = false;
                    for (auto p : state->before->map) {
                        auto pkt = p.second->to<SymbolicPkt>();
                        if (pkt->isConservative()) {
                            conservative = true;
                            break;
                        }
                    }

                    if (conservative)
                        ::warning("Potential parser cycle without extracting any bytes:\n%1%",
                                  stateChain(state));
                    else
                        ::error("Parser cycle without extracting any bytes:\n%1%",
                                stateChain(state));
                    return true;
                }


                // If no header validity has changed we can't really unroll
                if (!headerValidityChange(crt->before, state->before)) {
                    if (unroll)
                        ::error("Parser cycle cannot be unrolled:\n%1%",
                                stateChain(state));
                    return true;
                }
                break;
            }
        }
        return false;
    }

    /*
    std::vector<ParserStateInfo*>* evaluateState(ParserStateInfo* state) {
        LOG1("Analyzing " << state->state);
        auto valueMap = state->before->clone();
        for (auto s : state->state->components) {
            bool success = executeStatement(state, s, valueMap);
            if (!success)
                return nullptr;
        }
        state->after = valueMap;
        auto result = evaluateSelect(state);
        if (result == nullptr) {
        // if (state->isLeafState) {
            LOG1("After leaf state = "<<state->name<<", original state name = "<<state->state->name<<", ValueMap = "<< state->after);
            if (state->state->name == IR::ParserState::accept)
                synthesizedParser->acceptStateFinalValueMaps.push_back(state->after);
            //std::cout<<"After leaf state = "<<state->name
            //  <<", original state name = "<<state->state->name
            //  <<", ValueMap = "<< state->after<<"\n";
            synthesizedParser->allPossileFinalValueMaps.push_back(state->after);
        }
            
        return result;
    }
    */

    std::vector<ParserStateInfo*>* evaluateState(ParserStateInfo* state) {
        LOG1("Analyzing " << state->state);
        if (state->state->name == IR::ParserState::accept || 
            state->state->name == IR::ParserState::reject) {
            state->after = state->before;
            synthesizedParser->allPossileFinalValueMaps.push_back(state->after);
            if (state->state->name == IR::ParserState::accept)
                synthesizedParser->acceptStateFinalValueMaps.push_back(state->after);
            return nullptr;
        }

        auto valueMap = state->before->clone();
        for (auto s : state->state->components) {
            bool success = executeStatement(state, s, valueMap);
            if (!success)
                return nullptr;
        }
        state->after = valueMap;
        return evaluateSelect(state);
    }


 public:
    ParserSymbolicInterpreter(ParserStructure* structure, ReferenceMap* refMap,
                              TypeMap* typeMap, bool unroll)
            : structure(structure), refMap(refMap), typeMap(typeMap),
              synthesizedParser(nullptr), unroll(unroll) {
        CHECK_NULL(structure); CHECK_NULL(refMap); CHECK_NULL(typeMap);
        factory = new SymbolicValueFactory(typeMap);
        parser = structure->parser;
    }

    ParserInfo* run() {
        synthesizedParser = new ParserInfo();
        auto initMap = initializeVariables();
        if (initMap == nullptr)
            // error during initializer evaluation
            return synthesizedParser;
        auto startInfo = newStateInfo(nullptr, structure->start->name.name, initMap);
        std::vector<ParserStateInfo*> toRun;  // worklist
        toRun.push_back(startInfo);

        while (!toRun.empty()) {
            auto stateInfo = toRun.back();
            toRun.pop_back();
            LOG1("Symbolic evaluation of " << stateChain(stateInfo));
            bool infLoop = checkLoops(stateInfo);
            if (infLoop)
                // don't evaluate successors anymore
                continue;
            auto nextStates = evaluateState(stateInfo);
            // stateInfo->nextParserStateInfo = nextStates;
            if (nextStates == nullptr) {
                LOG1("No next states");
                continue;
            }
            toRun.insert(toRun.end(), nextStates->begin(), nextStates->end());
        }

        //std::cout<<synthesizedParser->toString();
        return synthesizedParser;
    }
};
}  // namespace ParserStructureImpl

void ParserStructure::analyze(ReferenceMap* refMap, TypeMap* typeMap, bool unroll) {
    ParserStateInfo::stateNameIndices.clear();
    ParserStructureImpl::ParserSymbolicInterpreter psi(this, refMap, typeMap, unroll);
    result = psi.run();
}

}  // namespace P4
