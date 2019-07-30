/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "mergeDeclarations.h"

namespace CSA {

const IR::Node* MergeDeclarations::preorder(IR::P4Program* p4Program) {

    p4Programs.push_back(p4Program);
    
    auto mergedP4Program = p4Programs[0]->clone();
    // std::cout<<mergedP4Program<<"\n";
    for (size_t i = 1; i<p4Programs.size(); i++) {
        mergedP4Program->objects.append(p4Programs[i]->objects);
    }

    Consolidator consolidator;
    auto consolidatedP4Program = mergedP4Program->apply(consolidator);
    // std::cout<<"Consolidated  P4Program -----------------------------\n";;
    // std::cout<<consolidatedP4Program<<"\n";;
    // std::cout<<"Consolidated  P4Program -----------------------------\n";;
    InvalidateSourceInfo invalidateSourceInfo;
    return consolidatedP4Program->apply(invalidateSourceInfo);
}


bool Consolidator::isTopLevel() {
    auto n = getContext()->node;
    bool ret = n->is<IR::P4Program>();
    if (!ret) 
        prune();
    return ret;
}

bool Consolidator::addDecl(const IR::Declaration* decl) {
    auto id = decls.getDeclaration(decl->getName());
    if (id == nullptr) {
        decls.push_back(decl);
        return true;
    }
    return false;

}


bool Consolidator::addTypeDecl(const IR::Type_Declaration* tDecl) {
    auto id = typeDecls.getDeclaration(tDecl->getName());
    if (id == nullptr) {
        // std::cout<<"Adding "<<idecl->getName()<<"\n";
        typeDecls.push_back(tDecl);
        return true;
    }
    return false;

}


const IR::Node* Consolidator::preorder(IR::Type_ComposablePackage* tcp) {
    auto n = getContext()->node;
    if (n->is<IR::P4ComposablePackage>()) {
        prune();
        // std::cout<<"Type_ComposablePackage "<<tcp->getName()<<"\n";
        return nullptr;
    }

    if (isTopLevel()) {
        if (!addTypeDecl(tcp)) {
            prune();
            // std::cout<<"Type_ComposablePackage "<<tcp->getName()<<"\n";
            return nullptr;
        }
    }
    return tcp;
}


const IR::Node* Consolidator::preorder(IR::Type_Declaration* typeDecl) {
    if (!isTopLevel())
        return typeDecl;
    // std::cout<<"Type_Declaration : "<<typeDecl->getName()<<"\n";
    if (addTypeDecl(typeDecl))
        return typeDecl;
    prune();
    return nullptr;
}


const IR::Node* Consolidator::preorder(IR::Type_Error* te) {
    if (typeError == nullptr)
        typeError = new IR::Type_Error(IR::Type_Error::error);
    return te;
}


const IR::Node* Consolidator::postorder(IR::Type_Error* te) {
    if (!remove) {
        remove = true;
        return typeError;
    }
    return nullptr;
}

const IR::Node* Consolidator::preorder(IR::Declaration_ID* id) {
    auto n = getContext()->node;
    if (!n->is<IR::Type_Error>())
        return id;
    if (typeError == nullptr)
        std::cout<<"nullptr for type error \n";
    if (typeError->getDeclByName(id->getName()) == nullptr) {
        typeError->members.push_back(id->clone());
    }
    return id;
}


const IR::Node* Consolidator::preorder(IR::Declaration_MatchKind* matchKindDecl) {
    if (!removeMatchKind) {
        removeMatchKind = true;
        return matchKindDecl;
    }
    return nullptr;
}

const IR::Node* Consolidator::preorder(IR::Method* method) {
    auto n = getContext()->node;
    if (!n->is<IR::P4Program>())
        return method;

    auto iterbool = seenMethods.emplace(std::piecewise_construct,
                                        std::forward_as_tuple(method->getName()),
                                        std::forward_as_tuple(1, method));
    if (!iterbool.second) {
        // TODO: add logic to match overloads..
        prune();
        return nullptr;
    }
    return method;
}


const IR::Node* Consolidator::preorder(IR::P4Action* p4action) {

    if (!isTopLevel())
        return p4action;
    if (addDecl(p4action))
        return p4action;
    prune();
    return nullptr;
}

/*
const IR::Node* Consolidator::postorder(IR::P4Program* p4program) {
    
    if (!hasNoAction) {
        auto statOrDeclList = new IR::IndexedVector<IR::StatOrDecl>();
        auto actionBlock = new IR::BlockStatement(*statOrDeclList);
        auto action = new IR::P4Action(noActionName, 
                                       new IR::ParameterList(), actionBlock);
        p4program->objects.insert(p4program->objects.begin(), action);
    }
    return p4program;
}
*/

}// namespace CSA
