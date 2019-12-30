/*
Copyright 2016 VMware, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#ifndef _MIDEND_PARSERUNROLL_H_
#define _MIDEND_PARSERUNROLL_H_

#include <algorithm>
#include "ir/ir.h"
#include "frontends/common/resolveReferences/referenceMap.h"
#include "frontends/p4/typeChecking/typeChecker.h"
#include "frontends/p4/typeMap.h"
#include "frontends/p4/callGraph.h"
#include "interpreter.h"

namespace P4 {

//////////////////////////////////////////////
// The following are for a single parser

// Information produced for a parser state by the symbolic evaluator
struct ParserStateInfo {
    const IR::P4Parser*    parser;
    const IR::ParserState* state;  // original state this is produced from
    const ParserStateInfo* predecessor;  // how we got here in the symbolic evaluation
    std::vector<std::pair<const IR::Expression*, const ParserStateInfo*>>
                           nextParserStateInfo;  
    cstring                name;  // new state name
    ValueMap*              before;
    ValueMap*              after;

    // bool                   isLeafState;

    static std::map<cstring, unsigned> stateNameIndices;

    static cstring GetStateNameWithIndex(cstring stateName) {
        unsigned i = 0;
        auto iter = ParserStateInfo::stateNameIndices.find(stateName);
        if (iter == ParserStateInfo::stateNameIndices.end())
            ParserStateInfo::stateNameIndices.emplace(stateName, i);
        else
            i = ++(iter->second);
        return stateName+"_"+std::to_string(i);
    }

    ParserStateInfo(cstring name, const IR::P4Parser* parser, 
          const IR::ParserState* state, const ParserStateInfo* predecessor, 
          ValueMap* before) 
        : parser(parser), state(state), predecessor(predecessor), name(name), 
          before(before), after(nullptr) /*, isLeafState(false)*/ { 
            CHECK_NULL(parser); CHECK_NULL(state); CHECK_NULL(before); 
      //nextParserStateInfo = nullptr;
    }

    cstring toString() {
        std::ostringstream out(std::ostringstream::ate);
        out<<"ParserStateInfo: new state name - "<<name
           <<" original state name - "<<state->name<<"\n";
        return cstring(out.str());
    }

};

// Information produced for a parser by the symbolic evaluator
class ParserInfo {
    // for each original state a vector of states produced by unrolling
    std::map<cstring, std::vector<ParserStateInfo*>*> states;

 public:
    std::vector<ValueMap*> allPossileFinalValueMaps;
    std::vector<ValueMap*> acceptStateFinalValueMaps;

    std::vector<ParserStateInfo*>* get(cstring origState) const {
        std::vector<ParserStateInfo*> *vec;
        auto it = states.find(origState);
        if (it == states.end()) {
            vec = new std::vector<ParserStateInfo*>;
            // states.emplace(origState, vec);
        } else {
            vec = it->second;
        }
        return vec;
    }
    void add(ParserStateInfo* si) {
        cstring origState = si->state->name.name;
        std::vector<ParserStateInfo*> *vec;
        auto it = states.find(origState);
        if (it == states.end()) {
            vec = new std::vector<ParserStateInfo*>;
            states.emplace(origState, vec);
        } else {
            vec = it->second;
        }
       // auto vec = get(origState);
        vec->push_back(si);
    }

    cstring toString() {
        std::ostringstream out(std::ostringstream::ate);
        out<<"ParserInfo states size : "<<states.size()<<"\n";
        for (auto kv :  states) {
            out<<"State : " << kv.first 
               <<" number of unrolled states " << kv.second->size() <<"\n";
            for (auto e : *(kv.second)) {
                out<<e->toString();
            }
        }
        return cstring(out.str());
    }


    unsigned getPacketInMaxOffset() const {
        unsigned ret = 0;
        for (auto valueMap : allPossileFinalValueMaps) {
            auto filter = [](const IR::IDeclaration*, const P4::SymbolicValue* value)
                            { return value->is<P4::SymbolicPacketIn>(); };
            auto vm = valueMap->filter(filter);
            unsigned val = 0;
            if (vm->map.size() == 1) {
                auto spi = vm->map.begin()->second->to<P4::SymbolicPacketIn>();
                val = spi->getCurrentStreamOffset();
                if (ret < val)
                    ret = val;
            }
        }
        return ret;
    }


    unsigned getPktMaxOffset() const {
        unsigned ret = 0;
        for (auto valueMap : allPossileFinalValueMaps) {
            auto filter = [](const IR::IDeclaration*, const P4::SymbolicValue* value)
                            { return value->is<P4::SymbolicPkt>(); };
            auto vm = valueMap->filter(filter);
            unsigned val = 0;
            if (vm->map.size() == 1) {
                auto spi = vm->map.begin()->second->to<P4::SymbolicPkt>();
                val = spi->getOffset();
                if (ret < val)
                    ret = val;
            }
        }
        return ret;
    }


    std::vector<unsigned> getAcceptedPktOffsets() const { 
        std::vector<unsigned> acceptedPktOffsets;
        for (auto valueMap : acceptStateFinalValueMaps) {
            auto filter = [](const IR::IDeclaration*, const P4::SymbolicValue* value)
                            { return value->is<P4::SymbolicPkt>(); };
            auto vm = valueMap->filter(filter);
            unsigned val = 0;
            if (vm->map.size() == 1) {
                auto spi = vm->map.begin()->second->to<P4::SymbolicPkt>();
                val = spi->getOffset();
                acceptedPktOffsets.push_back(val);
            }
        }
        return acceptedPktOffsets;
    }
};

typedef CallGraph<const IR::ParserState*> StateCallGraph;

// Information about a parser in the input program
class ParserStructure {
    std::map<cstring, const IR::ParserState*> stateMap;
 public:
    StateCallGraph* callGraph;
    const IR::P4Parser*    parser;
    const IR::ParserState* start;
    const ParserInfo*      result;

    std::vector<std::set<cstring>>* xoredHeaderSets = 
                                            new std::vector<std::set<cstring>>();

    // parsedHeaders stores all the headers that may be parsed by parser.
    // Some header instances may not be parsed but only emitted.
    // This is used in DeparserConverter.
    std::set<cstring>* parsedHeaders = new std::set<cstring>();

    void setParser(const IR::P4Parser* parser) {
        CHECK_NULL(parser);
        callGraph = new StateCallGraph(parser->name);
        this->parser = parser;
        start = nullptr;
    }
    void addState(const IR::ParserState* state)
    { stateMap.emplace(state->name, state); }
    const IR::ParserState* get(cstring state) const
    { return ::get(stateMap, state); }
    void calls(const IR::ParserState* caller, const IR::ParserState* callee)
    {  callGraph->calls(caller, callee); }

    void analyze(ReferenceMap* refMap, TypeMap* typeMap, bool unroll);
};

class AnalyzeParser : public Inspector {
    const ReferenceMap* refMap;
    ParserStructure*    current;
 public:
    AnalyzeParser(const ReferenceMap* refMap, ParserStructure* current) :
            refMap(refMap), current(current) {
        CHECK_NULL(refMap); CHECK_NULL(current); setName("AnalyzeParser");
        visitDagOnce = false;
    }

    bool preorder(const IR::ParserState* state) override;
    void postorder(const IR::PathExpression* expression) override;
};


class CreateXoredHeaderSets : public Inspector {
    ReferenceMap* refMap;
    TypeMap*      typeMap;
    ParserStructure*    parserStructure;

    std::set<cstring> xoredHeaderSet;
 public:
    CreateXoredHeaderSets(ReferenceMap* refMap, TypeMap* typeMap, 
                          ParserStructure* parserStructure)
      : refMap(refMap), typeMap(typeMap), parserStructure(parserStructure) {
        CHECK_NULL(refMap);   CHECK_NULL(parserStructure); 
        CHECK_NULL(typeMap);   
        setName("CreateXoredHeaderSets");
    }

    bool preorder(const IR::P4Parser* parser) override;
    bool preorder(const IR::ParserState* state) override;
    bool preorder(const IR::MethodCallStatement* mcs) override;
};


// Applied to a P4Parser object.
class ParserRewriter : public PassManager {
    ParserStructure  *current;
 public:
    ParserRewriter(ReferenceMap* refMap, TypeMap* typeMap, bool unroll, 
                   ParserStructure* parserEval = nullptr) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);
        if(parserEval == nullptr) 
            current = new ParserStructure();
        else 
            current = parserEval;
    
        passes.push_back(new AnalyzeParser(refMap, current));
        passes.push_back(new CreateXoredHeaderSets(refMap, typeMap, current));
        passes.push_back(new VisitFunctor (
            [this, refMap, typeMap, unroll](const IR::Node* root) -> const IR::Node* {
                current->analyze(refMap, typeMap, unroll);
                return root;
            }));
    }

    Visitor::profile_t init_apply(const IR::Node* node) override {
        LOG1("Scanning " << node);
        BUG_CHECK(node->is<IR::P4Parser>(), "%1%: expected a parser", node);
        current->setParser(node->to<IR::P4Parser>());
        return PassManager::init_apply(node);
    }
};

// cstring is P4ComposablePackage name + " _ "+ parser name 
// As of now, no nested definitions of P4ComposablePackage are allowed, so it is
// safe to uniquely identify parsers using these names.
typedef std::map<cstring, P4::ParserStructure*> ParserStructuresMap;

class AnalyzeAllParsers : public Inspector {
    ReferenceMap* refMap;
    TypeMap*      typeMap;
    ParserStructuresMap* parserStructures;
 public:
    AnalyzeAllParsers(ReferenceMap* refMap, TypeMap* typeMap, 
                      ParserStructuresMap* parserStructures) :
        refMap(refMap), typeMap(typeMap), parserStructures(parserStructures) { 
        CHECK_NULL(refMap); CHECK_NULL(typeMap); 
        CHECK_NULL(parserStructures);
    }

    bool preorder(const IR::P4Parser* parser) override {
        auto parserStructure = new P4::ParserStructure();
        ParserRewriter rewriter(refMap, typeMap, true, parserStructure);
        parser->apply(rewriter);

        cstring parser_fqn = parser->getName();
        auto cp = findContext<IR::P4ComposablePackage>();
        if (cp != nullptr)
            parser_fqn = cp->getName() +"_"+ parser->getName();

        parserStructures->emplace(parser_fqn, parserStructure);
        return false;
    }
};

class ParsersUnroll : public PassManager {
 public:
    ParsersUnroll(ReferenceMap* refMap, TypeMap* typeMap, 
                  ParserStructuresMap* parserStructures) {
        passes.push_back(new TypeChecking(refMap, typeMap));
        passes.push_back(new AnalyzeAllParsers(refMap, typeMap, 
                         parserStructures));
        setName("ParsersUnroll");
    }
};

}  // namespace P4

#endif /* _MIDEND_PARSERUNROLL_H_ */
