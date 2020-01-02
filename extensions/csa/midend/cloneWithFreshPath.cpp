/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */
#include "cloneWithFreshPath.h"

namespace CSA {

const IR::Node* CloneWithFreshPath::preorder(IR::Path* path)  {
    // std::cout<<"cloning path  "<<path->name<<"\n";
    prune();
    return new IR::Path(path->name);
}

const IR::Node* CloneWithFreshPath::preorder(IR::PathExpression* pe) { 
    prune();
    return new IR::PathExpression(pe->path->name);
}

}// namespace CSA
