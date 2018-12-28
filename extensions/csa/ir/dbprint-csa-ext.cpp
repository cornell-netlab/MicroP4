#include "../../../ir/ir.h"
#include "../../../ir/dbprint.h"

using namespace DBPrint;
using namespace IndentCtl;

void IR::Type_ComposablePackage::dbprint(std::ostream& out) const {
    out<<getName()<<typeParameters<<"("<<applyParams<<")"<<"("<<constructorParams<<")";
    if (typeLocalDeclarations) {
        out<<" {";
        for (auto decl : *(getDeclarations())) {
            out<<"\n    ";
            out<<decl->to<IR::Type_Declaration>();
        }
        out<<"\n}";
    } else {
        out<<";\n";
    }

}

void IR::P4ComposablePackage::dbprint(std::ostream& out) const {
    Node::dbprint(out);
}
