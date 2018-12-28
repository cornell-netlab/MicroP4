#include "annotateTypes.h"
#include "./typeChecking/typeSubstitutionVisitor.h"
#include "ir/ir.h"
#include "frontends/p4/coreLibrary.h"

namespace P4 {

const IR::Type_Name* ReplaceTypeName::preorder(IR::Type_Name* tn) {
    auto decl = refMap->getDeclaration(tn->path, false);
    if (!decl->is<IR::Type_Var>()) 
        return tn;

    auto tv = decl->to<IR::Type_Var>();
    auto newTV = tvs->lookup(tv)->to<IR::Type_Var>();
    if (!newTV) 
        return tn;
  
    auto newTN = new IR::Type_Name(tn->srcInfo, 
                    new IR::Path(newTV->getName()));
    return newTN;
}

unsigned int AnnotateTypes::i = 0;
const IR::P4ComposablePackage* AnnotateTypes::preorder(IR::P4ComposablePackage* cp) {

    i++;

        const IR::Path* path = nullptr;
        if (cp->interfaceType->is<IR::Type_Specialized>())
            path = cp->interfaceType->to<IR::Type_Specialized>()->baseType->path;
        if (cp->interfaceType->is<IR::Type_Name>()) {
            path = cp->interfaceType->to<IR::Type_Name>()->path;
            ::error("support to implement packages  without type args is disabled for now, not even checking if %1% was generic", path);
            return cp;
        }

    const IR::IDeclaration* decl = refMap->getDeclaration(path, false);
    if (decl == nullptr) {
        ::error("Cannot find declaration for %1%", path);
        return cp;
    }
    if (!decl->is<IR::Type_ComposablePackage>()) {
        ::error("Cannot implement  %1% type, it is not cpackage type", path);
        return cp;
    }
    
    auto type = decl->to<IR::Type_ComposablePackage>();

    TypeVariableSubstitution tvs;
    auto setBindings =  [&] (const IR::IMayBeGenericType* genType, unsigned int i) {
        for (auto v : genType->getTypeParameters()->parameters) {
            cstring newName = v->getName() + cstring::to_cstring(i);
            auto tv = new IR::Type_Var(v->srcInfo, IR::ID(newName, v->getName()));
            bool b = tvs.setBinding(v, tv);
            BUG_CHECK(b, "%1%: failed replacing %2% with %3%", genType, v, tv);
        }
    };
    setBindings(type, i);
    for (auto decl : *(type->getDeclarations())) {
        if (decl->is<IR::IMayBeGenericType>()) {
            setBindings(decl->to<IR::IMayBeGenericType>(), i);
        }
    }
    TypeVariableSubstitutionVisitor sv(&tvs, true);
    cp->type = type->to<IR::Type>()->apply(sv)->to<IR::Type_ComposablePackage>();

    ReplaceTypeName rtn(refMap, &tvs);
    cp->type = cp->type->apply(rtn)->to<IR::Type_ComposablePackage>();


    for (auto typeDecl : *(cp->type->getDeclarations())) {
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
            auto name = refMap->newName(cp->name+"_"+idecl->getName()+ 
                                        "default_ctor_inst");
            auto annos = new IR::Annotations();
            annos->add(new IR::Annotation(IR::Annotation::nameAnnotation,
                  { new IR::StringLiteral(cp->name+"_"+idecl->getName())}));

            IR::Type_Name* typeName = new IR::Type_Name(
                                              new IR::Path(idecl->getName()));
            auto inst = new IR::Declaration_Instance(cp->srcInfo, 
                            IR::ID(name), annos, typeName, 
                            new IR::Vector<IR::Argument>());
            cp->packageLocalDeclarations.push_back(inst);

        }
    }
    return cp;
}

}  // namespace P4
