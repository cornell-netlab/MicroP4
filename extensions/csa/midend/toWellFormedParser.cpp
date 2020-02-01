/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#include "frontends/p4/methodInstance.h"
#include "toWellFormedParser.h"

namespace CSA {

bool CheckParserGuard::preorder(const IR::ParserState* parserState) {
    if (parserState->name != IR::ParserState::start)
        return false;
    available = false;

    if (parserState->components.size() == 0) {
        if (parserState->selectExpression != nullptr) {
            if (parserState->selectExpression->is<IR::SelectExpression>())
                available = true;
        }
    }
    return false;
}

const IR::Node* ToWellFormedParser::preorder(IR::P4Program* p4program) {

    auto mainDecls = p4program->getDeclsByName(IR::P4Program::main)->toVector();
    if (mainDecls->size() != 1)
        return p4program;
    auto main = mainDecls->at(0);
    auto mainDeclInst = main->to<IR::Declaration_Instance>();
    if (mainDeclInst == nullptr)
        return p4program;
    auto type = typeMap->getType(mainDeclInst);
    BUG_CHECK(type!=nullptr && type->is<IR::P4ComposablePackage>(), 
        "could not find type of main package");
    auto cp = type->to<IR::P4ComposablePackage>();
    
    p4Program = p4program;
    for (auto& o : p4Program->objects) {
        auto ocp = o->to<IR::P4ComposablePackage>();
        if (ocp != nullptr && ocp->getName() == cp->getName()) {
            visit(o);
            break;
        }
    }
    for (auto updateNode : updateP4ProgramObjects) {
        for (auto& o : p4Program->objects) {
            auto p4cp = o->to<IR::P4ComposablePackage>();
            if (p4cp != nullptr && p4cp->getName() == updateNode->getName()) {
                o = updateNode;
            }
        }
    }
    
    for (auto e : insertAtP4ProgramObjects) {
        auto it = p4Program->objects.begin();
        for ( ; it != p4Program->objects.end(); it++) {
            auto td = (*it)->to<IR::Type_Declaration>();
            if (td != nullptr && td->getName() == e.first)
                break;
        }
        p4Program->objects.insert(it, e.second);
    }
    prune();
    return p4program;
}

const IR::Node* ToWellFormedParser::preorder(IR::Parameter* param) {
    if (param->direction != IR::Direction::In)
        return param;
    if (newInParamType == nullptr && currInParam == nullptr)
        return param;

    auto t = typeMap->getType(getOriginal(), true);
    auto tc = typeMap->getType(currInParam, true);
    if (t != tc)
        return param;
    auto np = new IR::Parameter(param->name, IR::Direction::In,
        new IR::Type_Name(IR::ID(newInParamType->name)));
    auto tp = findContext<IR::Type_Parser>();
    if (tp != nullptr)
        parserInParamName = param->name;
    return np;
}

const IR::Node* ToWellFormedParser::preorder(IR::Type_Specialized* ts) {
    std::cout<<" ToWellFormedParser Type_Specialized "<<"\n";
    if (ts->arguments == nullptr || ts->arguments->size() != 5)
        return ts;
    auto tcp = getContext()->node->to<IR::P4ComposablePackage>();
    if (tcp == nullptr)
        return ts;
    auto tn = new IR::Type_Name(IR::ID(newInParamType->name));
    auto tas = new IR::Vector<IR::Type>();
    for (auto ta : *(ts->arguments))
        tas->push_back(ta->clone());
    (*tas)[2] = tn;
    ts->arguments = tas;
    prune();
    return ts;
}

const IR::Node* ToWellFormedParser::preorder(IR::P4ComposablePackage* cp) {
    std::cout<<"ToWellFormedParser:preorder:P4ComposablePackage: "<<cp->name<<"\n";
    auto packageLocals = cp->packageLocals->clone();
    if (newInParamType != nullptr) {
        visit(cp->interfaceType);
        for (auto& p : *packageLocals) {
            if (p->is<IR::P4Parser>()) {
                visit(p);
                break;
            }
        }
    }
    // Any callee in control blocks will use above offsets( offsetsStack.back())
    // Visiting controls
    for (auto& typeDecl : *(packageLocals)) {
        auto control = typeDecl->to<IR::P4Control>();
        if (control != nullptr && control->name =="micro_control") {
            visit(typeDecl);
        }
    }
    // Visiting Deparser
    /*
    for (auto& typeDecl : *(packageLocals)) {
        auto control = typeDecl->to<IR::P4Control>();
        if (control != nullptr && control->name == "micro_deparser") {
            visit(typeDecl);
            break;
        }
    }
    */
    cp->packageLocals = packageLocals;
    updateP4ProgramObjects.push_back(cp);
    prune();
    return cp;
}

const IR::Node* ToWellFormedParser::preorder(IR::P4Parser* p4parser) {
    if (newInParamType == nullptr) {
        prune();
        return p4parser;
    }
    newStartName = IR::ParserState::start+cstring::to_cstring(id_suffix++);
    visit(p4parser->type);
    visit(p4parser->states);

    std::cout<<"only the inner most if-cond is pushed inside callees parser\n";
    auto fn = newFieldName;
    auto lexpr = new IR::Member(
          new IR::PathExpression(new IR::Path(IR::ID(parserInParamName))), fn);
    IR::Vector<IR::Expression> components;
    components.push_back(lexpr);
    auto le = new IR::ListExpression(components);

    auto state = new IR::PathExpression(new IR::Path(IR::ID(IR::ParserState::start)));
    auto keyset = value->clone();
    auto sc = new IR::SelectCase(keyset, state);
    IR::Vector<IR::SelectCase> selectCases;
    selectCases.push_back(sc);

    auto se = new IR::SelectExpression(le, selectCases);
    auto newStart = new IR::ParserState(newStartName, se);

    p4parser->states.insert(p4parser->states.begin(), newStart);

    prune();
    return p4parser;
}


const IR::Node* ToWellFormedParser::preorder(IR::ParserState* parserState) {
    if (parserState->name == IR::ParserState::start) 
        parserState->name = IR::ID(newStartName);
    return parserState;
}


const IR::Node* ToWellFormedParser::preorder(IR::P4Control* p4control) {
    auto cp = findContext<IR::P4ComposablePackage>();
    std::cout<<"ToWellFormedParser:preorder:P4Control: ";
    std::cout<<cp->name<<"-"<<p4control->name<<"\n";

    if (newInParamType != nullptr) {
        visit(p4control->type);
    }
    guardStack.push_back(currGuard);
    clStack.push_back(new IR::IndexedVector<IR::Declaration>());
    visit(p4control->body);
    auto dvs = clStack.back();
    p4control->controlLocals.append(*dvs);
    clStack.pop_back();
    currGuard = guardStack.back();
    guardStack.pop_back();
    prune();
    return p4control;
}

const IR::Node* ToWellFormedParser::preorder(IR::IfStatement* ifstmt) {
    // Ideally, we should be doing data dependence analysis
    // to identify guard
    guardMem = nullptr;
    guardVal = nullptr;
    visit(ifstmt->condition);
    if (guardVal!=nullptr && guardMem!=nullptr)
        currGuard = std::make_pair(guardMem, guardVal);
    visit(ifstmt->ifTrue);

    // TODO: need to think about what guards' value should be in 
    // callees of else block
    visit(ifstmt->ifFalse);
    prune();

    return ifstmt;
}

const IR::Node* ToWellFormedParser::preorder(IR::MethodCallStatement* mcs) {
    if (typeMap->getType(mcs->methodCall->method) == nullptr)
        return mcs;
    std::cout<<mcs<<"\n";
    auto mi = P4::MethodInstance::resolve(mcs->methodCall, refMap, typeMap);
    if (!mi->isApply())
        return mcs;
    auto a = mi->to<P4::ApplyMethod>();
    auto di = a->object->to<IR::Declaration_Instance>();
    if (di == nullptr)
        return mcs;
    auto inst = P4::Instantiation::resolve(di, refMap, typeMap);
    auto p4cpi = inst->to<P4::P4ComposablePackageInstantiation>();
    if (p4cpi == nullptr)
        return mcs;
    auto callee = p4cpi->p4ComposablePackage;
  
    CheckParserGuard hasSelect(refMap, typeMap);
    callee->apply(hasSelect);
    // if callee parser's start state has select statement. We are not pushing 
    // the guard in that case.
    if (hasSelect.hasGuard()) {
        newInParamType = nullptr;
        currInParam = nullptr;
        for (auto& o : p4Program->objects) {
            auto ocp = o->to<IR::P4ComposablePackage>();
            if (ocp != nullptr && ocp->getName() == callee->getName()) {
                visit(o);
                break;
            }
        }
        return mcs;
    }
    if (currGuard.first == nullptr)
        return mcs;
    std::cout<<mcs<<" triggers parser update in callee \n";

    // We need to push the enclosing conditions into parser before parser can be
    // moved out.
    auto mce = mcs->methodCall;
    auto& args = *(mce->arguments);
    auto newArgs = args.clone();
    unsigned short paramIndex = 0;
    currInParam = nullptr;
    for (auto p : callee->getApplyParameters()->parameters) {
        if (p->direction == IR::Direction::In) {
            currInParam = p;
            break;
        }
        paramIndex++;
    }
    BUG_CHECK(currInParam!=nullptr, "at least one in param missing (refer MSA)");
    auto currInParamType = typeMap->getType(currInParam, true);
    // create new in param type
    cstring newInParamTypeName = callee->name+"_in_param_"+
      cstring::to_cstring(id_suffix++);
    // we pass the instance of this instead of current in type
    auto dv = new IR::Declaration_Variable(IR::ID(newInParamTypeName+"_v"),
                              new IR::Type_Name(IR::ID(newInParamTypeName)));
    auto dvExpr = new IR::PathExpression(dv->getName());
    clStack.back()->push_back(dv);
    auto inArgExpr = args[paramIndex]->expression;
    (*newArgs)[paramIndex] = new IR::Argument(dvExpr);
    auto newMCE = new IR::MethodCallExpression(mce->method->clone(), newArgs);
    // assignment stmts, for copying 1) fields from old args to new. 
    // 2) members in enclosing ifcond expression to newly created fields  
    auto stmts = new IR::IndexedVector<IR::StatOrDecl>();
    IR::IndexedVector<IR::StructField> nfs;
    // creating a field for each guard
    
    auto e = currGuard;
        auto t = typeMap->getType(e.first, true);
        cstring n = "if_" + e.first->member;
        newFieldName = n;
        auto f = new IR::StructField(n, t);
        nfs.push_back(f);
        value = e.second;
        auto lhs = new IR::Member(dvExpr->clone(), IR::ID(n));
        stmts->push_back(new IR::AssignmentStatement(lhs, e.first->clone()));

    if (auto sl = currInParamType->to<IR::Type_StructLike>()) {
        for (auto f : sl->fields) {
            nfs.push_back(f->clone());
            auto lhs = new IR::Member(dvExpr->clone(), IR::ID(f->name));
            auto rhs = new IR::Member(inArgExpr->clone(), IR::ID(f->name));
            stmts->push_back(new IR::AssignmentStatement(lhs, rhs));
        }
    } else if (currInParamType->is<IR::Type_Base>()) {
        auto pe = inArgExpr->to<IR::PathExpression>();
        BUG_CHECK(pe!=nullptr, "unexpected expression");
        auto f = new IR::StructField(pe->path->name, currInParamType->clone());
        nfs.push_back(f);
        auto lhs = new IR::Member(dvExpr->clone(), IR::ID(pe->path->name));
        auto rhs = new IR::Member(inArgExpr->clone(), IR::ID(f->name));
        stmts->push_back(new IR::AssignmentStatement(lhs, rhs));
    } else {
        BUG(" have not handled this type ");
    }

    std::cout<<"new in param type name : "<<newInParamTypeName<<"\n";
    std::cout<<"callee name"<<callee->name<<"\n";
    newInParamType = new IR::Type_Struct(IR::ID(newInParamTypeName), nfs);
    insertAtP4ProgramObjects.emplace(callee->name, newInParamType);
    stmts->push_back(new IR::MethodCallStatement(newMCE));

    for (auto& o : p4Program->objects) {
        auto ocp = o->to<IR::P4ComposablePackage>();
        if (ocp != nullptr && ocp->getName() == callee->getName()) {
            visit(o);
            break;
        }
    }
    return stmts;
}

/*
 * Currently, we are handling a simple case to move guard.
 */
const IR::Node* ToWellFormedParser::preorder(IR::Equ* equ) {
    visit(equ->left);
    visit(equ->right);
    return equ;
}

const IR::Node* ToWellFormedParser::preorder(IR::Member* mem) { 
    auto anstrIf = findContext<IR::IfStatement>();
    auto anstrEqu = findContext<IR::Equ>();
    if (anstrEqu == nullptr || anstrIf == nullptr)
        return mem;

    // TODO: match with parameter
    // guardMem = mem;
    guardMem = getOriginal()->to<IR::Member>();
    /*
    auto type  = typeMap->getType(mem->expr, true);
    if (type->is<IR::Type_Header>()) {
        guardMem = mem;
    } else {
        // mem should be written by one or more header fields.
        // localEthType = vlan.ethType ... localEthType = eth.ethType
        // And header fields should not have been altered before this program
        // point
    }
    */

    return mem;
}

const IR::Node* ToWellFormedParser::preorder(IR::Constant* cs) { 
    auto anstrIf = findContext<IR::IfStatement>();
    auto anstrEqu = findContext<IR::Equ>();
    if (anstrEqu == nullptr || anstrIf == nullptr)
        return cs;
    guardVal = cs;
    return cs;
}

const IR::P4ComposablePackage* ToWellFormedParser::getNodeFromP4Program(
    const IR::P4Program* p4Program, const IR::P4ComposablePackage* cp) {
    for (auto& o : p4Program->objects) {
        auto ocp = o->to<IR::P4ComposablePackage>();
        if (ocp != nullptr && ocp->getName() == cp->getName()) {
            return ocp;
        }
    }
    BUG("%1% not found in P4Program ", cp->getName());
    return nullptr;
}

}// namespace CSA
