#include "csaExternSubstituter.h"

namespace CSA {

const IR::Node* CSAPacketSubstituter::preorder(IR::Type_Control* tc) {
    auto p4c = findContext<IR::P4Control>();
    if (p4c == nullptr || declMapStack.size() == 0) {
        prune();
        return tc;
    }
    auto mapping = declMapStack.back();
    if (mapping->name != tc->getName()) {
        prune();
        return tc;
    }
    // std::cout<<"Type Control CSAPacketSubstituter: "<<tc->getName()<<"\n";
    visit(tc->applyParams);
    prune();
    return tc;
}


const IR::Node* CSAPacketSubstituter::preorder(IR::Parameter* param) {
    
    const IR::Type* t = nullptr;
    if (auto tdecl = param->type->to<IR::IDeclaration>())
        t = new IR::Type_Name(tdecl->getName());
    else 
        t = param->type;

    auto p4c = findContext<IR::P4Control>();
    if (p4c == nullptr || declMapStack.size() == 0) {
        prune();
        return new IR::Parameter(param->srcInfo, param->name, param->annotations, 
                                 param->direction, t, param->defaultValue);
    }
    auto mapping = declMapStack.back();
    if(mapping->name != p4c->getName()) {
        prune();
        return new IR::Parameter(param->srcInfo, param->name, param->annotations, 
                                 param->direction, t, param->defaultValue);
    }
    auto idecl = mapping->getMappedDecl(getOriginal()->to<IR::Parameter>());
    if (idecl == nullptr) {
        // std::cout<<"no mapping found for "<<param->getName()<<"\n";
        prune();
        return new IR::Parameter(param->srcInfo, param->name, param->annotations, 
                                 param->direction, t, param->defaultValue);
    }

    // removing the parameter.
    // e.g., if `csa_packet_in pin` and `csa_packet_out po` are mapped to the same
    // `csa_packet_struct pkt`, both of them are replaced with csa_packet_struct
    if (mapping->substituted.find(idecl) != mapping->substituted.end()) {
        // std::cout<<"parameter removed from "<<p4c->getName()
        //   <<" : param "<<param<<"\n";
        prune();
        return nullptr;
    }
    mapping->substituted.insert(idecl);
    prune();
    return idecl->getNode()->clone();
}

const IR::Node* CSAPacketSubstituter::preorder(IR::Declaration* decl) {

    auto p4c = findContext<IR::P4Control>();
    if (p4c == nullptr || declMapStack.size() == 0) {
        prune();
        return decl;
    }
    auto mapping = declMapStack.back();
    if (mapping->name != p4c->getName()) {
        prune();
        return decl;
    }
    auto idecl = mapping->getMappedDecl(getOriginal()->to<IR::Declaration>());
    if (idecl != nullptr) {
        prune();
        return nullptr;
    }
    return decl;
}

const IR::Node* CSAPacketSubstituter::preorder(IR::P4Control* p4Control) {

    // std::cout<<"visiting "<<p4Control->getName()<<"\n";

    /*
    if (p4Control->getName() == controlName) {
        auto mapping = new Mappings(controlName);
        auto newParam = new IR::Parameter(
            IR::ID(ToControl::csaPacketStructName), IR::Direction::InOut,
            new IR::Type_Name(ToControl::csaPacketStructTypeName));

        auto pl = p4Control->getApplyParameters()->parameters;
        const IR::Parameter* origParam = nullptr;
        for (auto p : pl) {
            auto type = typeMap->getTypeType(p->type, false);
            if (auto te = type->to<IR::Type_Extern>()) {
                if (te->getName() == ToControl::csaPakcetInExternTypeName ||
                    te->getName() == ToControl::csaPakcetOutExternTypeName) {
                    origParam = p;
                    break;
                }
            }
        }
        if (origParam != nullptr) {
            // std::cout<<"orig Param from P4Control "<<origParam<<"\n";
            mapping->insertMapping(origParam, newParam);
            declMapStack.push_back(mapping);
        } else {
            prune();
            return p4Control;
        }
    }
    */

    if (declMapStack.size() == 0) {
        prune();
        return p4Control;
    }
    auto mapping = declMapStack.back();
    if (mapping->name != p4Control->getName()) {
        /*
        std::cout<<"Found "<<mapping->name<<" on stack, expected "
                 <<p4Control->getName()<<"\n";
        */
        prune();
        return p4Control;
    }

    // std::cout<<"visiting body of "<<p4Control->getName()<<"\n";
    visit(p4Control->body);
    // after the visit of body, unmapped parameter may get mapped to already
    // mapped once and might required to be removed
    visit(p4Control->type);

    // removes unused local declarations
    visit(p4Control->controlLocals);

    transformedP4Controls.emplace(p4Control->getName(), p4Control);
    prune();
    return p4Control;
}


const IR::Node* CSAPacketSubstituter::preorder(IR::MethodCallStatement* mcs) {

    auto callerP4Control = findContext<IR::P4Control>();
    if (callerP4Control == nullptr || declMapStack.size() == 0) {
        prune();
        return mcs;
    }

    auto mapping = declMapStack.back();
    BUG_CHECK(mapping->name == callerP4Control->getName(),
        "CSAPacketSubstituter: expecting %1% control on stack, found %2%",
        callerP4Control->getName(), mapping->name);

    auto mi = P4::MethodInstance::resolve(mcs, refMap, typeMap);
    if (mi->is<P4::ApplyMethod>()) {
        auto am = mi->to<P4::ApplyMethod>();
        const IR::P4Control* calleeP4Control = nullptr;
        if (auto di = am->object->to<IR::Declaration_Instance>()) {
            auto diType = typeMap->getTypeType(di->type, false);
            /*
            auto inst = P4::Instantiation::resolve(di, refMap, typeMap);
            if (auto ci = inst->to<P4::ControlInstantiation>()) 
                calleeP4Control = ci->control;
            */
            calleeP4Control = diType->to<IR::P4Control>();
        }
        if (calleeP4Control != nullptr) {
            std::map<cstring, const IR::Argument*> paramArgMap;
            // create param name to arg/path mapping;
            // resolve ref for path, get mapping  for the resolved declaration
            auto pl = calleeP4Control->getApplyParameters()->parameters;
            auto args = mcs->methodCall->arguments;
            auto itArg = args->begin(); auto itParam = pl.begin();
            Mappings* calleeMapping = new Mappings(calleeP4Control->getName());
            for (;itParam != pl.end() && itArg!=args->end(); itParam++, itArg++) {
                paramArgMap.emplace((*itParam)->getName(), *itArg);
                auto type = typeMap->getTypeType((*itParam)->type, false);
                if (auto te = type->to<IR::Type_Extern>()) {
                    if (te->getName() != ToControl::csaPakcetInExternTypeName &&
                        te->getName() != ToControl::csaPakcetOutExternTypeName) {
                        continue;
                    }
                } else {
                    continue;
                }
                // store param and arg/path
                // decl = resolve path
                auto pe = (*itArg)->expression->to<IR::PathExpression>();
                if (pe == nullptr) // for now, only PathExpression
                    continue;
                auto idecl = refMap->getDeclaration(pe->path);
                auto mappedIdecl = mapping->getMappedDecl(idecl);
                // insert param -> mapped decl cloned on paramMap
                // mapping->print();
                if (mappedIdecl != nullptr) {
                    // std::cout<<"Insert mapping parameter ---- "<<(*itParam)<<"\n";
                    calleeMapping->insertMapping((*itParam), mappedIdecl);
                    paramArgMap.emplace(mappedIdecl->getName(), *itArg);
                    // std::cout<<"inserting mapping for "<<calleeMapping->name<<"\n";
                }
            }
            // std::cout<<"Mapping size for "<<calleeMapping->name;
            // std::cout<<" "<<calleeMapping->getSize()<<"\n";
            declMapStack.push_back(calleeMapping);
            // visiting callee P4Control
            // std::cout<<"callee P4Control "<<calleeP4Control->getName()<<"\n";

            visit(calleeP4Control);
            transformedP4Controls.emplace(calleeP4Control->getName(),calleeP4Control);

            // std::cout<<"\n----------\n"<<calleeP4Control<<"\n-----------\n";

            calleeMapping = declMapStack.back();
            BUG_CHECK(calleeMapping->name == calleeP4Control->getName(), 
                "CSAPacketSubstituter: expecting %1% control on stack, found %2%",
                calleeP4Control->getName(), calleeMapping->name);
            declMapStack.pop_back();
            mapping = declMapStack.back();
            BUG_CHECK(mapping->name == callerP4Control->getName(),
                "CSAPacketSubstituter: expecting %1% control on stack, found %2%",
                callerP4Control->getName(), mapping->name);
            // creating args according to new P4Control
            auto newArgs = new IR::Vector<IR::Argument>();
            auto updatedPL = calleeP4Control->getApplyParameters()->parameters;
            for (auto p : updatedPL) {
                // std::cout<<p<<"\n";
                auto iter = paramArgMap.find(p->getName());
                BUG_CHECK(iter!=paramArgMap.end(), 
                    "unexpected new parameter %1% found in control %2%",
                    p->getName(), calleeP4Control->getName());
                //newArgs->push_back(iter->second->clone());
                newArgs->push_back(iter->second);
                paramArgMap.erase(iter);
            }
            // Update methodCall with new args
            auto newMCE = mcs->methodCall->clone();
            newMCE->arguments = newArgs;
            mcs->methodCall = newMCE;
            // If the callee-control's parameter is mapped to a declaration `d1`,
            // caller's declaration supplied as argument is mapped the `d1` 
            // in the caller.
            auto iter = paramArgMap.begin();
            for (; iter!=paramArgMap.end(); iter++) {
                auto pe = iter->second->expression->to<IR::PathExpression>();
                if (pe == nullptr) // for now, only PathExpression
                    continue;
                auto idecl = refMap->getDeclaration(pe->path);
                auto paramName = iter->first;
                auto paramMappedDecl = 
                                calleeMapping->getParamMappingByName(paramName);
                if (paramMappedDecl != nullptr)
                    mapping->insertMapping(idecl, paramMappedDecl);
            }
            visit(mcs->methodCall);
            prune();
            /*
            std::cout<<"\n----------\n";
            calleeP4Control->dbprint(std::cout);
            std::cout<<"\n-----------\n";
            */
            return mcs;
        }
    }
    if (mi->is<P4::ExternMethod>()) {
        auto em = mi->to<P4::ExternMethod>();
        if (em->method->name == ToControl::csaPakcetOutSetPacketStruct) {
            // std::cout<<"Method name :"<<em->method->name<<"\n";
            // std::cout<<"decl :"<<em->object<<"\n";
            auto arg0 = mcs->methodCall->arguments->at(0);
            auto exp = arg0->expression;
            // std::cout<<"------- "<<mcs<<"\n";
            BUG_CHECK(exp->is<IR::PathExpression>(), 
                "as of now replacing only PathExpression, %1% is not", exp);
         
            auto pe = exp->to<IR::PathExpression>();
            auto argDecl = refMap->getDeclaration(pe->path, true);
            auto subArgDecl = mapping->getMappedDecl(argDecl);
            // std::cout<<"map total size: "<<mapping->getSize()<<" \n";
            if (subArgDecl != nullptr) {
                auto existingMapping = mapping->getMappedDecl(em->object);
                BUG_CHECK(existingMapping == nullptr 
                    || existingMapping == subArgDecl, 
                    "unexpect to have different mapping for %1% in statement %2%", 
                    em->object->getName(), mcs);
                // std::cout<<" mapping for "<<argDecl<<" found \n";
                if (existingMapping == nullptr)
                    mapping->insertMapping(em->object, subArgDecl);
                prune();
                return nullptr;
            } else {
                // std::cout<<"mapping not found ********************** \n";
            }
        }

        if (em->method->name == ToControl::csaPakcetOutGetPacketIn) {
            auto existingMapping = mapping->getMappedDecl(em->object);
            if (existingMapping != nullptr) {
                auto arg0 = mcs->methodCall->arguments->at(0);
                auto exp = arg0->expression;
                BUG_CHECK(exp->is<IR::PathExpression>(), 
                    "as of now replacing only PathExpression, %1% is not", exp);
                auto pe = exp->to<IR::PathExpression>();
                auto argDecl = refMap->getDeclaration(pe->path, true);
                mapping->insertMapping(argDecl, existingMapping);
                // std::cout<<"mapping size() after get_packet_in :  "<<mapping->getSize()<<"\n";
                prune();
                // mapping->print();
                return nullptr;
            }
        }
    }
    return mcs;
}


const IR::Node* CSAPacketSubstituter::preorder(IR::AssignmentStatement* as) {
    auto p4Control = findContext<IR::P4Control>();
    if (p4Control == nullptr || declMapStack.size() == 0) {
        prune();
        return as;
    }

    auto mapping = declMapStack.back();
    if (mapping->name != p4Control->getName()) {
        prune();
        return as;
    }

    auto le = as->left->to<IR::PathExpression>();
    auto re = as->right->to<IR::MethodCallExpression>();

    if (le == nullptr || re == nullptr) {
        prune();
        return as;
    }

    auto mi = P4::MethodInstance::resolve(re, refMap, typeMap);
    if (!mi->is<P4::ExternMethod>())
        return as;
    auto em = mi->to<P4::ExternMethod>();
    if (em->method->name != ToControl::csaPakcetInGetPacketStruct)
        return  as;
  
    auto ldecl = refMap->getDeclaration(le->path, true);
    auto rdecl = em->object;


    auto rMappedDecl = mapping->getMappedDecl(rdecl);
    if (rMappedDecl != nullptr) {
        auto existingMapping = mapping->getMappedDecl(ldecl);
        // std::cout<<"--------------- "<<as<<"\n";
        BUG_CHECK(existingMapping == nullptr, 
            "unexpected to have mapping for %1% already in statement %2%", 
            ldecl->getName(), as);

        mapping->insertMapping(ldecl, rMappedDecl);
        // std::cout<<"After insertion: maps size: "<<mapping->getSize()<<" \n";
        prune();
        return nullptr;
    }
    return as;
}


const IR::Node* CSAPacketSubstituter::preorder(IR::Path* path) {
    auto p4Control = findContext<IR::P4Control>();
    if (p4Control == nullptr)
        return path;

    if (declMapStack.size() == 0)
        return path;
    auto mapping = declMapStack.back();
    BUG_CHECK(mapping->name == p4Control->getName(), 
        "CSAPacketSubstituter: expected %1% control on stack for %2%", 
        p4Control->getName(), path->name.name);

    // get the original declaration
    auto idecl = refMap->getDeclaration(getOriginal()->to<IR::Path>(), true);

    // std::cout<<idecl->getName()<<"\n";

    // check if there is any declaration mapped to original declaration one for
    // substitution
    auto mappedDecl = mapping->getMappedDecl(idecl);
    if (mappedDecl != nullptr)
        return new IR::Path(mappedDecl->getName());
    return path;
}


const IR::Node* CSAPacketSubstituter::preorder(IR::P4Program* p4Program) {
    const IR::P4Control* p4Control = nullptr;

    std::map<cstring, const IR::IDeclaration*> globalMapping ;

    for (auto control : *controlTypeNames) {
        p4Control = nullptr;
        controlName = control;
        transformedP4Controls.clear();
        for (auto&& n : p4Program->objects) {
            if (auto decl = n->to<IR::P4Control>()) {
                if (decl->getName() == controlName) {
                    p4Control = decl;
                    break;
                }
            }
        }
        
        if (p4Control != nullptr) {
            auto pl = p4Control->getApplyParameters()->parameters;
            const IR::Parameter* origParam = nullptr;
            auto mapping = new Mappings(p4Control->getName());

            for (auto p : pl) {
                auto it = globalMapping.find(p->getName());
                if (it != globalMapping.end()) {
                    mapping->insertMapping(p, it->second);
                    continue;
                }
            }

            if (mapping->getSize() == 0) {
                for (auto p : pl) {
                    auto type = typeMap->getTypeType(p->type, false);
                    if (auto te = type->to<IR::Type_Extern>()) {
                        if (te->getName() == ToControl::csaPakcetInExternTypeName ||
                            te->getName() == ToControl::csaPakcetOutExternTypeName) {
                            auto newParam = new IR::Parameter(ToControl::csaPacketStructName,
                                IR::Direction::InOut, new IR::Type_Name(
                                ToControl::csaPacketStructTypeName));
                            mapping->insertMapping(p, newParam);
                            break;
                        }
                    }
                }
            }
            
            if (mapping->getSize() == 0)
                continue;
            
            declMapStack.push_back(mapping);

            // std::cout<<"CSAPacketSubstituter "<<p4Control->getName()<<"\n";
            visit(p4Control);

            auto currMapping = declMapStack.back();
            declMapStack.pop_back();
            BUG_CHECK(currMapping == mapping, "unexpected p4control on stack");

            for (auto&& n : p4Program->objects) {
                if (auto decl = n->to<IR::P4Control>()) {
                    auto iter = transformedP4Controls.find(decl->getName());
                    if (iter != transformedP4Controls.end()) {
                        n = iter->second;
                    }
                }
            }

            for (auto ele : currMapping->getParamMap()) 
                globalMapping.emplace(ele.first->getName(), ele.second);
        }

        
    }
    prune();
    refMap->clear(); 
    typeMap->clear(); 
    return p4Program;
}

}// namespace CSA
