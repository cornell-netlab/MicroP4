#include "headerMerge.h"

namespace CSA {
    const IR::Type* HeaderMerger::setEquivalent(const IR::Type* type1, const IR::Type* type2) {
        if (type2 == nullptr) {
            return type1;
        } else {
            return type2;
        }
    }

    bool HeaderMerger::checkEquivalent(const IR::Type* type1, const IR::Type* type2) {
        if (type1->is<IR::Type_Name>()) {
            BUG("type %1% is only a type name", type1);
        }
        if (type2->is<IR::Type_Name>()) {
            BUG("type %1% is only a type name", type1);
        }

        if (oldTypeMap->equivalent(type1, type2))
            return true;

        if (type1->is<IR::Type_StructLike>()) {
            auto sl = type1->to<IR::Type_StructLike>();
            auto sr = type2->to<IR::Type_StructLike>();
            if (sl->fields.size() != sr->fields.size())
                return false;
            for (size_t i = 0; i < sl->fields.size(); i++) {
                auto fl = sl->fields.at(i);
                auto fr = sr->fields.at(i);
                if (!checkEquivalent(fl->type, fr->type))
                    return false;
            }
            return true;
        }

        return false;
    }
}
