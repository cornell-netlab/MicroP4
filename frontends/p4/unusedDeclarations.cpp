/*
Copyright 2013-present Barefoot Networks, Inc.

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

#include "unusedDeclarations.h"
#include "sideEffects.h"

namespace P4 {

Visitor::profile_t RemoveUnusedDeclarations::init_apply(const IR::Node* node) {
    LOG4("Reference map " << refMap);
    // std::cout<<"init_apply "<<node->is<IR::P4Program>()<<"\n";
    hasMain = containsMain(node);
    return Transform::init_apply(node);
}

bool RemoveUnusedDeclarations::giveWarning(const IR::Node* node) {
    if (warned == nullptr)
        return false;
    auto p = warned->emplace(node);
    LOG3("Warn about " << dbp(node) << " " << p.second);
    return p.second;
}

const IR::Node* RemoveUnusedDeclarations::preorder(IR::Type_Enum* type) {
    prune();  // never remove individual enum members
    if (!refMap->isUsed(getOriginal<IR::Type_Enum>())) {
        LOG3("Removing " << type);
        return nullptr;
    }
    return type;
}

const IR::Node* RemoveUnusedDeclarations::preorder(IR::Type_SerEnum* type) {
    prune();  // never remove individual enum members
    if (!refMap->isUsed(getOriginal<IR::Type_SerEnum>())) {
        LOG3("Removing " << type);
        return nullptr;
    }
    return type;
}

const IR::Node* RemoveUnusedDeclarations::preorder(IR::P4Control* cont) {
    if (!refMap->isUsed(getOriginal<IR::IDeclaration>()) && hasMain) {
        // std::cout<<"being removed   "<<cont->name<<"\n";
        LOG3("Removing " << cont);
        prune();
        return nullptr;
    }

    visit(cont->controlLocals, "controlLocals");
    visit(cont->body);
    prune();
    return cont;
}

const IR::Node* RemoveUnusedDeclarations::preorder(IR::P4Parser* cont) {

    if (!refMap->isUsed(getOriginal<IR::IDeclaration>()) && hasMain) {
        // std::cout<<"being removed   "<<cont->name<<"\n";
        LOG3("Removing " << cont);
        prune();
        return nullptr;
    }
    visit(cont->parserLocals, "parserLocals");
    visit(cont->states, "states");
    prune();
    return cont;
}

const IR::Node* RemoveUnusedDeclarations::preorder(IR::P4Table* table) {
    if (!refMap->isUsed(getOriginal<IR::IDeclaration>())) {
        if (giveWarning(getOriginal()))
            ::warning("Table %1% is not used; removing", table);
        LOG3("Removing " << table);
        table = nullptr;
    }
    prune();
    return table;
}

const IR::Node* RemoveUnusedDeclarations::preorder(IR::Declaration_Variable* decl) {
    prune();
    if (decl->initializer == nullptr)
        return process(decl);
    if (!SideEffects::check(decl->initializer, nullptr, nullptr))
        return process(decl);
    return decl;
}

const IR::Node* RemoveUnusedDeclarations::process(const IR::IDeclaration* decl) {
    LOG3("Visiting " << decl);
    if (decl->getName().name == IR::ParserState::verify && getParent<IR::P4Program>())
        return decl->getNode();
    if (refMap->isUsed(getOriginal<IR::IDeclaration>()))
        return decl->getNode();
    LOG3("Removing " << getOriginal());
    // std::cout<<"Removing " <<getOriginal()->getNode()->toString()<<" "<<getOriginal()->id<<"\n";
    prune();  // no need to go deeper
    return nullptr;
}

const IR::Node* RemoveUnusedDeclarations::preorder(IR::Declaration_Instance* decl) {
    // Don't delete instances; they may have consequences on the control-plane API
    if (decl->getName().name == IR::P4Program::main && getParent<IR::P4Program>())
        return decl;
    
    // This will retain default and  unused programmer declared instances.
    // Revisit here and refine the logic.
    auto parentDecl = getParent<IR::P4ComposablePackage>();
    if (parentDecl && nsDeclDecisionStack.back().first->getName() 
                                      == parentDecl->getName()
                   && nsDeclDecisionStack.back().second)
        return decl;
        
    if (!refMap->isUsed(getOriginal<IR::Declaration_Instance>())) {
        if (giveWarning(getOriginal()))
            ::warning("%1%: unused instance", decl);
        // We won't delete extern instances; these may be useful even if not references.
        auto type = decl->type;
        if (type->is<IR::Type_Specialized>())
            type = type->to<IR::Type_Specialized>()->baseType;
        if (type->is<IR::Type_Name>())
            type = refMap->getDeclaration(type->to<IR::Type_Name>()->path, true)->to<IR::Type>();
        if (!type->is<IR::Type_Extern>())
            return process(decl);
        prune();
        return decl;
    }
    // don't scan the initializer: we don't want to delete virtual methods
    prune();
    return decl;
}

const IR::Node* RemoveUnusedDeclarations::preorder(IR::ParserState* state) {
    if (state->name == IR::ParserState::accept ||
        state->name == IR::ParserState::reject ||
        state->name == IR::ParserState::start)
        return state;

    if (refMap->isUsed(getOriginal<IR::ParserState>()))
        return state;
    LOG3("Removing " << state);
    prune();
    return nullptr;
}

const IR::Node* RemoveUnusedDeclarations::preorder(IR::P4ComposablePackage* p4cpkg) {
    bool pkgUsed = refMap->isUsed(getOriginal<IR::P4ComposablePackage>());
    // std::cout<<"Had Main "<<hasMain<<std::endl;
    // std::cout<<"pkgUsed "<<pkgUsed<<std::endl;
    if (pkgUsed || !hasMain) {
        nsDeclDecisionStack.emplace_back(p4cpkg, true);
        return p4cpkg;
    } else { 
        prune();
        return nullptr;
    }
}

const IR::Node* RemoveUnusedDeclarations::postorder(IR::P4ComposablePackage* p4cpkg) {
    BUG_CHECK(nsDeclDecisionStack.back().first->getName() == p4cpkg->getName(), 
        "Unexpected %1% declaration on namespace stack ",p4cpkg->getName());
    nsDeclDecisionStack.pop_back();
    return p4cpkg;
}

const IR::Node* RemoveUnusedDeclarations::preorder(IR::Type_ComposablePackage* 
                                                                      tcpkg) {
    // This is needed, because interfaceType Type_Name of P4ComposablePackage 
    // does not point to its type member in RefMap. 
    // First ResolveReference pass make interfaceType point to common
    // declaration, then TypeInference clones the declaration saves in type
    // field.
    // It would be nice to have interfaceType pointing to the clone.
    prune();
    if (getParent<IR::P4ComposablePackage>() 
        || refMap->isUsed(getOriginal<IR::Type_ComposablePackage>()) )
        return tcpkg;
    return nullptr;
}

// If the program does not have a declaration with "main", do not remove 
// top level declarations.
// Compiler will create a library json file for composable architecture.
// If there is a main declaration all unused declarations should be removed as
// per normal scenario.
bool RemoveUnusedDeclarations::containsMain(const IR::Node* node) {
    auto p4Program = node->to<IR::P4Program>();
    if (p4Program)
        hasMain = p4Program->getDeclsByName(IR::P4Program::main)
                               ->toVector()->size() == 1;
    else
        std::cout<<"P4Program "<<p4Program<<"\n";
    return hasMain;
}


}  // namespace P4
