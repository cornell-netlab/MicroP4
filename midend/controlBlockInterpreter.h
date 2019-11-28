/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _MIDEND_CONTROLBLOCKINTERPRETER_H_
#define _MIDEND_CONTROLBLOCKINTERPRETER_H_

#include "ir/ir.h"
#include "frontends/common/resolveReferences/referenceMap.h"
#include "frontends/p4/typeMap.h"
#include "frontends/p4/coreLibrary.h"
#include "interpreter.h"

// Symbolic Evaluation of `selective code` of P4 Control blocks.
// This interpreter finds maximum increase and maximum decrease in packet size by
// every control block in the program.

namespace P4 {

class SymbolicValueFactory;

class ControlBlockInterpreter : public Inspector {
    ReferenceMap*       refMap;
    TypeMap*            typeMap;
    ValueMap*           valueMap;
    const SymbolicValueFactory* factory;


 public:
    ControlBlockInterpreter(ReferenceMap* refMap, TypeMap* typeMap, ValueMap* valueMap) :
            refMap(refMap), typeMap(typeMap), valueMap(valueMap) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap); CHECK_NULL(valueMap);
        factory = new SymbolicValueFactory(typeMap);
    }

    bool preorder(const IR::P4Control* p4Control) override;
    bool preorder(const IR::SwitchStatement* swStmt) override;
    bool preorder(const IR::IfStatement* ifStmt) override;
    
    bool preorder(const IR::MethodCallExpression* expression) override;
    bool preorder(const IR::P4Action* p4Control) override;
    bool preorder(const IR::P4Table* p4Table) override;
    bool preorder(const IR::ActionList* actionList) override;

    bool preorder(const IR::P4ComposablePackage* p4cp) override;
};

}  // namespace P4

#endif /* _MIDEND_CONTROLBLOCKINTERPRETER_H_ */
