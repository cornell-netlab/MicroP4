/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "deparserEvaluator.h"

namespace CSA {

class DeparserSymbolicInterpreter {
    P4::ReferenceMap*           refMap;
    P4::TypeMap*                typeMap;
    const IR::P4Control*        deparser;
    DeparserExecutionTree*      execTree;
    P4::SymbolicValueFactory*   factory;

    P4::ValueMap* initializeVariables() {
        P4::ValueMap* result = new P4::ValueMap();
        P4::ExpressionEvaluator ev(refMap, typeMap, result);

        for (const auto p : deparser->getApplyParameters()->parameters) {
            auto type = typeMap->getType(p);
            bool initialized = p->direction == IR::Direction::In ||
                    p->direction == IR::Direction::InOut;
            auto value = factory->create(type, !initialized);
            result->set(p, value);
        }
        for (auto d : deparser->controlLocals) {
            auto type = typeMap->getType(d);
            P4::SymbolicValue* value = nullptr;
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
            if (value->is<P4::SymbolicError>()) {
                ::error("%1%: %2%", d, value->to<P4::SymbolicError>()->message());
                return nullptr;
            }
            if (value != nullptr)
                result->set(d, value);
        }
        return result;
    }


    // Executes symbolically the specified statement.
    // Returns 'true' if execution completes successfully,
    // and 'false' if an error occurred.
    std::pair<std::vector<DeparserInfo*>*, bool>
    executeStatement(const IR::StatOrDecl* sord, P4::ValueMap* valueMap) const {
        std::vector<DeparserInfo*>* branches = nullptr;
        P4::ExpressionEvaluator ev(refMap, typeMap, valueMap);
        bool success = true;
        if (sord->is<IR::AssignmentStatement>()) {
            auto ass = sord->to<IR::AssignmentStatement>();
            auto left = ev.evaluate(ass->left, true);
            // success = reportIfError(state, left);
            if (success) {
                auto right = ev.evaluate(ass->right, false);
                // success = reportIfError(state, right);
                if (success)
                    left->assign(right);
            }
        } else if (sord->is<IR::MethodCallStatement>()) {
            // can have side-effects
            auto mc = sord->to<IR::MethodCallStatement>();
            auto e = ev.evaluate(mc->methodCall, false);
            // success = reportIfError(state, e);
        } if (sord->is<IR::IfStatement>()) {
            auto ifs = sord->to<IR::IfStatement>();
            auto branches = executeIfStatement();
        } else if (sord->is<IR::SwitchStatement>()) {
            auto sws = sord->to<IR::SwitchStatement>();
            auto branches = executeSwitchStatement(sws, valueMap)
        } else {
            BUG("%1%: unexpected declaration or statement", sord);
        }
        LOG2("After " << sord << " state is\n" << valueMap);
        return success;
    }

    std::vector<DeparserInfo*>* executeIfStatement (
        const IR::IfStatement* ifStmt, P4::ValueMap* valueMap) {
        std::vector<DeparserInfo*>* result = nullptr;

        
        auto ifTrue = ifStmt->ifTrue;
        auto ifFalse = ifStmt->ifFalse;
        
        return result;
    }


    std::vector<DeparserInfo*>* executeSwitchStatement (
            const IR::SwitchStatement* sord, P4::ValueMap* valueMap) {
        std::vector<DeparserInfo*>* result = nullptr;

            
        return result;
    }

    std::vector<DeparserInfo*>* executeBlockStatement(const DeparserInfo* di) {
        di->after = di->before->clone();
        for (; endStmtIndex<components.size(); endStmtIndex++) {
            auto statOrDecl = components.at(endStmtIndex);

            auto pair = executeStatement(statOrDecl, di->after);
            if (pair.first != nullptr) {
                return pair.first;
            }
        }
        return nullptr;
    } 

 public:
    DeparserSymbolicInterpreter(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
                                const IR::P4Control* deparser)
            : refMap(refMap), typeMap(typeMap), deparser(deparser), 
              execTree(nullptr) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap); CHECK_NULL(deparser);
        factory = new P4::SymbolicValueFactory(typeMap);

    }

    DeparserExecutionTree* run() {
        auto initMap = initializeVariables();
        if (initMap == nullptr)
            // error during initializer evaluation
            return execTree;
        DeparserInfo::components = deparser->body->components;
        auto treeRoot = new DeparserInfo(0, nullptr, initMap);
        execTree = new DeparserExecutionTree(deparser, treeRoot);

        std::vector<DeparserInfo*> toRun;  // worklist
        toRun.push_back(treeRoot);

        while (!toRun.empty()) {
            auto deparserInfo = toRun.back();
            toRun.pop_back();
            LOG1("Symbolic evaluation of " << deparserInfo);
            auto nextDeparserInfo = getNextForks(deparserInfo);
            if (nextDeparserInfo == nullptr) {
                LOG1("No next forks.");
                continue;
            }
            toRun.insert(toRun.end(), nextDeparserInfo->begin(), 
                         nextDeparserInfo->end());
        }
        return execTree;
    }
};


}  // namespace CSA
