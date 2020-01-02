/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */
#include <algorithm>
#include <cmath>
#include <list>
#include <vector>
#include <unordered_set>
#include "deparserConverter.h"
#include "frontends/p4/coreLibrary.h"
#include "frontends/p4/parserCallGraph.h"
#include "frontends/p4/methodInstance.h"


namespace CSA {

const IR::Node* DeparserInverter::preorder(IR::Parameter* p) {
    
    auto old = p->name.name;
    /*
    std::cout<<old<<" dir "<<cstring::to_cstring(p->direction)<<"\n";
    cstring ds = cstring::to_cstring(p->direction);
    cstring dsIn = cstring::to_cstring(IR::Direction::In);
    cstring dsOut = cstring::to_cstring(IR::Direction::Out);
    if (ds == dsIn)
      p->direction = IR::Direction::Out;
    if (ds ==  dsOut)
      p->direction = IR::Direction::In;
    */

    if (p->name == headerParamName) 
        p->direction = IR::Direction::Out;
    p->name.name = "parse_"+ old;
    newNameMap.emplace(old, p->name.name);
    // std::cout<<old<<" dir "<<cstring::to_cstring(p->direction)<<"\n";
    return p;
}

const IR::Node* DeparserInverter::preorder(IR::P4Table* act) {
    auto old = act->name.name;
    act->name.name = "parse_"+ old;
    newNameMap.emplace(old, act->name.name);
    return act;
}

const IR::Node* DeparserInverter::preorder(IR::P4Action* act) {
    auto old = act->name.name;
    act->name.name = "parse_"+ old;
    newNameMap.emplace(old, act->name.name);
    return act;
}

const IR::Node* DeparserInverter::preorder(IR::Path* p) {
    auto it =  newNameMap.find(p->name.name);
    cstring newName = p->name.name;
    if (it != newNameMap.end())
        newName = it->second;
    return new IR::Path(newName);
}

const IR::Node* DeparserInverter::preorder(IR::Type_Control* tc) {
    tc->name = newName;
    return tc;
}


const IR::Node* DeparserInverter::preorder(IR::P4Control* deparser) {
    deparser->name = newName;
    return deparser;
}

const IR::Node* DeparserInverter::preorder(IR::AssignmentStatement* as) {
    auto lhs = as->left;
    auto rhs = as->right;

    if (rhs->is<IR::Constant>() 
        || rhs->is<IR::ArrayIndex>() 
        || rhs->is<IR::BoolLiteral>())
        return nullptr;
    return new IR::AssignmentStatement(rhs, lhs);
}



}// namespace CSA
