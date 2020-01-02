/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */
#include "scanForHdrVOps.h"
#include "frontends/p4/methodInstance.h"


namespace CSA {


bool ScanForHdrVOps::preorder(const IR::MethodCallExpression* mce) {

    auto mt = typeMap->getType(mce->method);
    if (mt  == nullptr)
        return false;
    std::cout<<"From ScanForHdrVOps "<<mce<<"\n";
    auto mi = P4::MethodInstance::resolve(mce, refMap, typeMap);
    if (mi->is<P4::BuiltInMethod>()) {
        auto bm = mi->to<P4::BuiltInMethod>();
        auto exp = bm->appliedTo;
        auto basetype = typeMap->getType(exp);
        BUG_CHECK(basetype->is<IR::Type_Header>(), "only HeaderType expected");
        auto th = basetype->to<IR::Type_Header>();
        // std::cout<<"Header size:"<<hs<<"\n";
        if (bm->name == IR::Type_Header::setValid || 
            bm->name == IR::Type_Header::setInvalid) {
            if (auto mem = exp->to<IR::Member>()) {
                hdrTypeInstNames->emplace_back(th->getName(), mem->member);
                return false;
            }
        }
    }

    return false;
}


}// namespace CSA
