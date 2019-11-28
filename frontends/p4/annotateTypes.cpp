#include "annotateTypes.h"
#include "./typeChecking/typeSubstitutionVisitor.h"
#include "ir/ir.h"
#include "frontends/p4/coreLibrary.h"

namespace P4 {

const IR::Node* RenameTypeDeclarations::preorder(IR::Type_Declaration* idecl) {
    auto n = getContext()->node;
    if (n->is<IR::P4Program>())
        std::cout<<"top level decl "<<idecl->getName()<<"\n";
    return idecl;
}

const IR::Node* RenameTypeDeclarations::preorder(IR::Declaration* idecl) {
    auto n = getContext()->node;
    if (n->is<IR::P4Program>())
        std::cout<<"top level decl "<<idecl->getName()<<"\n";
    return idecl;
}
/*
const IR::Node* RenameTypeDeclarations::preorder(IR::P4ComposablePackage* cp) {
    return cp;
}

const IR::Node* RenameTypeDeclarations::preorder(IR::Type_ComposablePackage* cp) {
    return tcp;
}
*/


unsigned int AnnotateTypes::i = 0;
const IR::P4ComposablePackage* AnnotateTypes::preorder(IR::P4ComposablePackage* cp) {


    const IR::Path* path = nullptr;
    if (cp->interfaceType->is<IR::Type_Specialized>())
        path = cp->interfaceType->to<IR::Type_Specialized>()->baseType->path;
    if (cp->interfaceType->is<IR::Type_Name>()) {
        path = cp->interfaceType->to<IR::Type_Name>()->path;
        ::error("support to implement packages  without type args is disabled for now, not even checking if %1% was generic", path);
        return cp;
    }

    i++;
    const IR::IDeclaration* decl = refMap->getDeclaration(path, false);
    if (decl == nullptr) {
        ::error("Cannot find declaration for %1%", path);
        return cp;
    }
    if (!decl->is<IR::Type_ComposablePackage>()) {
        ::error("Cannot implement  %1% type, it is not cpackage type", path);
        return cp;
    }
    
    auto interfaceType = decl->to<IR::Type_ComposablePackage>();


    for (auto typeDecl : *(interfaceType->getDeclarations())) {
        auto typeArchBlock = typeDecl->to<IR::Type_ArchBlock>();
        if (!typeArchBlock)
            continue;
        auto idecl = cp->getDeclByName(typeArchBlock->getName());

        if (typeArchBlock->getAnnotation(IR::Annotation::optionalAnnotation) 
            == nullptr && idecl == nullptr) { // There must be an implementation
                ::error("%1% is not implemented", typeArchBlock->getName());
                return cp;
        }
        if (idecl != nullptr) {
            if (!((typeDecl->is<IR::Type_Parser>() && idecl->is<IR::P4Parser>()) 
                || (typeDecl->is<IR::Type_Control>() && idecl->is<IR::P4Control>()) 
                || (typeDecl->is<IR::Type_ComposablePackage>() && 
                   idecl->is<IR::P4ComposablePackage>()))) {
                ::error("%1% can not implement %2", idecl->getName(),
                                                    typeArchBlock->getName());
                return cp;
            }

            // create declaration_instance of instance of idecl
            auto name = refMap->newName(cp->name+"_"+idecl->getName()+"_inst");
            // std::cout<<"annotateTypes new name: "<<name<<"\n";
            auto annos = new IR::Annotations();
            annos->add(new IR::Annotation(IR::Annotation::nameAnnotation,
                  { new IR::StringLiteral(cp->name+"."+idecl->getName())}));

            IR::Type_Name* typeName = new IR::Type_Name(
                                              new IR::Path(idecl->getName()));
            auto inst = new IR::Declaration_Instance(
                            // cp->srcInfo, 
                            //IR::ID(name), annos, typeName, 
                            IR::ID(name), typeName, 
                            new IR::Vector<IR::Argument>());
            cp->packageLocalDeclarations.push_back(inst);

        }
    }
    return cp;
}

}  // namespace P4
