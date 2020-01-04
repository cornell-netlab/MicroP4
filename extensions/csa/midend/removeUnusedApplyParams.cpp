/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */
#include "frontends/p4/methodInstance.h"
#include "removeUnusedApplyParams.h"

namespace CSA {

const IR::Node* RemoveUnusedApplyParams::preorder(IR::Parameter* param) { 
    auto p4c = findContext<IR::P4Control>();
    if (p4c == nullptr) {
        prune();
        return param;
    }

    if (!refMap->isUsed(getOriginal()->to<IR::Declaration>())) {
        // std::cout<<"unused param : "<<param<<"\n";
        unusedParams.push_back(param);
    }
    prune();
    return param;
}

const IR::Node* RemoveUnusedApplyParams::preorder(IR::MethodCallExpression* mce) {
    auto p4c = findContext<IR::P4Control>();
    if (p4c == nullptr) {
        prune();
        return mce;
    }

    auto mi = P4::MethodInstance::resolve(mce, refMap, typeMap);
    if (mi->isApply()) {
        auto a = mi->to<P4::ApplyMethod>();
        if (auto di = a->object->to<IR::Declaration_Instance>()) {
            auto inst = P4::Instantiation::resolve(di, refMap, typeMap);
            if (auto ci = inst->to<P4::ControlInstantiation>()) {
                auto calleeName = ci->control->name;
                auto iter = controlUnusedParamLocMap.find(calleeName);
                if (iter == controlUnusedParamLocMap.end()) {
                    /*
                    std::cout<<"--- No Argsa re deleted for ---- \n";
                    std::cout<<"Declaration instance "<<di<<" \n";
                    std::cout<<"Name "<<calleeName<<" \n";
                    std::cout<<"--------------------------------- \n";
                    */
                    prune();
                    return mce;
                }

                auto& unusedLocs = iter->second;
                /*
                if (di->getName() == "ModularRouterv4_ingress_deparser_inst") {
                    std::cout<<"ModularRouterv4_ingress_deparser_inst.apply \n";
                    std::cout<<"unused decl "<<unusedLocs.size()<<"\n";
                }
                */
                if (unusedLocs.size() > 0) {
                    auto newArgs = new IR::Vector<IR::Argument>();
                    for (size_t s = 0; s<mce->arguments->size(); s++) {
                        if (unusedLocs.find(s) == unusedLocs.end())
                            newArgs->push_back((*(mce->arguments))[s]);
                    }
                    mce->arguments = newArgs;
                }
            }
        }
    }
    prune();
    return mce;
}
    
const IR::Node* RemoveUnusedApplyParams::preorder(IR::P4Control* p4control) {

    // std::cout<<"RemoveUnusedApplyParams visiting "<<p4control->name<<"\n";;
    if (skipDecl!= nullptr && skipDecl->find(p4control->name) != skipDecl->end()) {
        visit(p4control->body);
        prune();
        return p4control;
    }
    
    unusedParams.clear();
    unusedParamLocations.clear();
    visit(p4control->type);
    visit(p4control->controlLocals);
    visit(p4control->body);
    if (unusedParamLocations.size() != 0) {
        controlUnusedParamLocMap.insert(
            std::make_pair(p4control->name, unusedParamLocations));
    } else {
        // std::cout<<"---- entry not added in Map --- "<<p4control->name<<
        //  " size "<<unusedParamLocations.size()<<"\n";;
    }
    unusedParamLocations.clear();
    unusedParams.clear();
    prune();
    return p4control;
}

const IR::Node* RemoveUnusedApplyParams::preorder(IR::Type_Control* tc) {
    auto p4c = findContext<IR::P4Control>();
    if (p4c == nullptr) {
        prune();
        return tc;
    }

    visit(tc->applyParams);
    prune();
    return tc;
}

const IR::Node* RemoveUnusedApplyParams::postorder(IR::ParameterList* pl) {
    auto p4c = findContext<IR::P4Control>();
    if (p4c == nullptr) {
        prune();
        return pl;
    }

    // std::cout<<"---in  parameterlist "<<p4c->name<<"---\n";
    for (size_t s = 0; s < pl->parameters.size(); s++) {
        // std::cout<<pl->parameters[s]->name<<"\n";
        if (unusedParams.getDeclaration(pl->parameters[s]->name) != nullptr) {
            unusedParamLocations.insert(s);
        }
    }
    // std::cout<<"---in  parameterlist -------------------\n";

    for (auto unused : unusedParams) {
        pl->parameters.removeByName(unused->getName());
    }
    
    return pl;
}

}// namespace CSA
