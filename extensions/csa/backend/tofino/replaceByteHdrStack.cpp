#include "replaceByteHdrStack.h"

#include "../../midend/msaNameConstants.h"


namespace CSA {



bool CompareExpression::preorder(const IR::Member* mem) {
    auto currMem = currExpr->to<IR::Member>();
    if (currMem == nullptr) {
        *match = false;
        return false;
    }
    if (currMem->member != mem->member) {
        *match = false;
        return false;
    }
    currExpr = currMem->expr;
    visit(mem->expr);
    return false;
}


bool CompareExpression::preorder(const IR::PathExpression* pe) {

    auto curr = currExpr->to<IR::PathExpression>();
    if (curr == nullptr) {
        *match = false;
        return false;
    }

    if (pe->path->name != curr->path->name)
        *match = false;
    return false;
}


bool CompareExpression::preorder(const IR::ArrayIndex* ai) {

    auto curr = currExpr->to<IR::ArrayIndex>();
    if (curr == nullptr) {
        *match = false;
        return false;
    }
    currExpr = ai->left;
    visit(ai->left);
    if (*match == false) {
        return false;
    }
    currExpr = ai->right;
    visit(ai->right);
    return false;
}


bool CompareExpression::preorder(const IR::Constant* c) {

    auto curr = currExpr->to<IR::Constant>();
    if (curr == nullptr) {
        *match = false;
        return false;
    }
    if (c->asUnsigned() != curr->asUnsigned())
        *match = false;
    return false;
}




const IR::Node* ReplaceByteHdrStack::postorder(IR::P4Program* program) {

    auto byteType = IR::Type::Bits::get(hdrBitWidth, false);
    auto dataField = new IR::StructField(IR::ID(fieldName), byteType);
    IR::IndexedVector<IR::StructField> fields;
    fields.push_back(dataField);
    auto newHdrType = new IR::Type_Header(NameConstants::multiByteHdrTypeName, fields);

    program->objects.insert(program->objects.begin(), newHdrType);
    return program;
}


const IR::Node* ReplaceByteHdrStack::preorder(IR::Type_Header* typeHdr) { 

    auto hdrName = typeHdr->getName();
    if (hdrName != NameConstants::headerTypeName)
        return typeHdr;
    fieldName = typeHdr->fields.at(0)->getName();
    return typeHdr;
}


const IR::Node* ReplaceByteHdrStack::preorder(IR::Type_Struct* typeStruct) {

    auto name = typeStruct->getName();
    if (name != NameConstants::csaPacketStructTypeName)
        return typeStruct;

    auto fd = typeStruct->fields.getDeclaration(
                                    NameConstants::csaHeaderInstanceName);
    BUG_CHECK(fd != nullptr, "byte stack field is missing");

    auto field =  fd->to<IR::StructField>();
    auto ft = field->type->to<IR::Type_Stack>();

    // std::cout<<"single byte header stack size :"<<ft->getSize()<<"\n";
    byteStackSize = ft->getSize();
    typeStruct->fields.removeByName(NameConstants::csaHeaderInstanceName);

    unsigned fac = hdrBitWidth / 8;
    if (byteStackSize % fac != 0) {
        addOneByteHdr = true;
        auto sf = new IR::StructField(IR::ID(NameConstants::msaOneByteHdrInstName), 
                            new IR::Type_Name(NameConstants::headerTypeName));
        typeStruct->fields.push_back(sf);
    }
    unsigned numTwoBytes = byteStackSize / fac;
  
    *residualStackSize = numTwoBytes % stackSize;
    *numFullStacks = (numTwoBytes / stackSize);

    //std::cout<<"single byte header stack size :"<<*residualStackSize<<"\n";

    for (unsigned s = 0; s < *numFullStacks; s++) {
        auto ts = new IR::Type_Stack(
                          new IR::Type_Name(NameConstants::multiByteHdrTypeName), 
                          new IR::Constant((stackSize)));
        auto sf = new IR::StructField(IR::ID(
              ReplaceMSAByteHdrStack::getHdrStackInstName(s)), ts);
        typeStruct->fields.push_back(sf);
    }
    if (*residualStackSize > 0) {
        auto ts = new IR::Type_Stack(
                          new IR::Type_Name(NameConstants::multiByteHdrTypeName), 
                          new IR::Constant((*residualStackSize)));
        auto sf = new IR::StructField(IR::ID(
              ReplaceMSAByteHdrStack::getHdrStackInstName(*numFullStacks)), ts);
        typeStruct->fields.push_back(sf);
    }
        
    return typeStruct;
}


const IR::Node* ReplaceByteHdrStack::preorder(IR::Member* member) {
    
    IR::Expression* subExp = nullptr;
    int index = getIndexOfByteStack(member, &subExp);
    if (index < 0)
        return member;
    unsigned byteStackIndex = (unsigned)index;

    unsigned sn = 0;
    unsigned si = 0;
    unsigned nh = 0;
    unsigned nl = 0;
    bool ir = translateIndexAndSlice(byteStackIndex, 7, 0, sn, si, nh, nl);
    const IR::Expression* slice = nullptr;
    if (ir) {
      auto m = new IR::Member(subExp, IR::ID(ReplaceMSAByteHdrStack::getHdrStackInstName(sn)));
      auto ai = new IR::ArrayIndex(m, new IR::Constant(si));
      auto aim = new IR::Member(ai, IR::ID(fieldName));
      slice = IR::Slice::make(aim, nl, nh);
    } else {
        BUG("write some code  here to handle _odd number of bytes_ case");
    }
    prune();
    return slice;
}



const IR::Node* ReplaceByteHdrStack::preorder(IR::Slice* slice) {

    if (!slice->e0->is<IR::Member>())
        return slice;
        
    IR::Expression* subExp;
    int index = getIndexOfByteStack(slice->e0->to<IR::Member>(), &subExp);
    if (index < 0)
        return slice;

    unsigned byteStackIndex = (unsigned)index;
    unsigned h = slice->getH();
    unsigned l = slice->getL();

    unsigned sn = 0;
    unsigned si = 0;
    unsigned nh = 0;
    unsigned nl = 0;
    bool ir = translateIndexAndSlice(byteStackIndex, h, l, sn, si, nh, nl);
    const IR::Expression* newSlice = nullptr;
    if (ir) {
        auto m = new IR::Member(subExp, 
            IR::ID(ReplaceMSAByteHdrStack::getHdrStackInstName(sn)));
        auto ai = new IR::ArrayIndex(m, new IR::Constant(si));
        auto aim = new IR::Member(ai, IR::ID(fieldName));
        newSlice = IR::Slice::make(aim, nl, nh);
    } else {
        BUG("write some code  here to handle _odd number of bytes_ case");
    }
    prune();
    return newSlice;
}


int ReplaceByteHdrStack::getIndexOfByteStack(const IR::Member* member, 
                                             IR::Expression** subExp) {
    if (!member->expr->is<IR::ArrayIndex>() || 
        member->member != fieldName)
        return -1;

    auto arrayIndex = member->expr->to<IR::ArrayIndex>();
    
    auto le = arrayIndex->left;
    auto mem = le->to<IR::Member>();
    if (mem == nullptr)
        return -1;
    if (mem->member != NameConstants::csaHeaderInstanceName)
        return -1;

    *subExp = mem->expr->clone();
    auto cnst = arrayIndex->right->to<IR::Constant>();
    return cnst->asUnsigned();
} 


bool ReplaceByteHdrStack::translateIndexAndSlice(unsigned in, unsigned h, unsigned l, 
    unsigned& stackNumber, unsigned& stackIndex, unsigned& nh, unsigned& nl) {

    unsigned nsRange = ((*numFullStacks * stackSize) + *residualStackSize) * 2;
    if (in >= nsRange)
        return false;

    unsigned fac = hdrBitWidth / 8;
    unsigned continuousIndex = in / fac;
    unsigned offset = (in % fac) * 8;

    stackNumber = continuousIndex / stackSize;
    stackIndex = continuousIndex % stackSize;

    offset = (offset + (hdrBitWidth-8)) % hdrBitWidth;
    nh = offset + h;
    nl = offset + l;
    return true;
}


void FoldLExpSlicesInAsStmts::resetFoldContext() {
    lExpMember = nullptr;
    currentSubLExpMember = nullptr;
    slices.clear();
    rightExprVec.clear();
}


bool FoldLExpSlicesInAsStmts::matchLExpSliceIndices(const IR::Expression* lexp, 
                                                    unsigned& l, unsigned& h) {
    bool first = false;
    if (lExpMember == nullptr) {
        first = true;
        lExpMember = lexp;
    }
    auto le = lexp->to<IR::Slice>();
    if (le == nullptr)
        return false;

    auto currExpr = lExpMember->to<IR::Slice>();
    if (currExpr == nullptr)
        return false;

    l = le->getL();
    h = le->getH();

    if (first)
        return true;
    auto curL = slices.back().first;

    /*
    std::cout<<"lexp :: "<<lexp<<"\n";
    std::cout<<"l = "<<l<<"\n";
    std::cout<<"h = "<<h<<"\n";
    std::cout<<"curL = "<<curL<<"\n";
    */
    if (curL != h+1)
        return false;

    currentSubLExpMember = currExpr->e0;
    match = true;
    visit(le->e0);
    return match;
}


IR::AssignmentStatement* FoldLExpSlicesInAsStmts::fold() {
    auto sl =  lExpMember->to<IR::Slice>();
    auto mem = sl->e0;
    auto les = mem->clone();
    
    unsigned h = slices.front().second;
    unsigned l = slices.back().first;
    auto ls = IR::Slice::make(les, l, h);
    
    BUG_CHECK(rightExprVec.size() > 0, "bug in FoldLExpSlicesInAsStmts");
    auto currConcatLeft = rightExprVec[0];

    if (rightExprVec.size() > 1) {
        for (unsigned i = 1; i<rightExprVec.size(); i++) {
            currConcatLeft = new IR::Concat(currConcatLeft, rightExprVec[i]);
        }
    }

    auto as = new IR::AssignmentStatement(ls, currConcatLeft);
    return as;
}


const IR::Node* FoldLExpSlicesInAsStmts::preorder(IR::Member* mem) {
    
    auto currMem = currentSubLExpMember->to<IR::Member>();
    if (currMem == nullptr) {
        match = false;
        return mem;
    }

    if (currMem->member != mem->member) {
        match = false;
        return mem;
    }
    currentSubLExpMember = currMem->expr;
    visit(mem->expr);
    prune();
    return mem;
}


const IR::Node* FoldLExpSlicesInAsStmts::preorder(IR::ArrayIndex* ai) {
    auto curr = currentSubLExpMember->to<IR::ArrayIndex>();
    if (curr == nullptr) {
        match = false;
        prune();
        return ai;
    }

    currentSubLExpMember = ai->left;
    visit(ai->left);
    if (match == false) {
        prune();
        return ai;
    }
    currentSubLExpMember = ai->right;
    visit(ai->right);
    prune();
    return ai;
}

const IR::Node* FoldLExpSlicesInAsStmts::preorder(IR::PathExpression* pe) {
    
    auto curr = currentSubLExpMember->to<IR::PathExpression>();
    if (curr == nullptr) {
        match = false;
        prune();
        return pe;
    }

    if (pe->path->name != curr->path->name)
        match = false;
    prune();
    return pe;
}


const IR::Node* FoldLExpSlicesInAsStmts::preorder(IR::Constant* c) {
    auto curr = currentSubLExpMember->to<IR::Constant>();
    if (curr == nullptr) {
        match = false;
        prune();
        return c;
    }
    if (c->asUnsigned() != curr->asUnsigned())
        match = false;
    prune();
    return c;

}


const IR::Node* FoldLExpSlicesInAsStmts::preorder(IR::AssignmentStatement* as) {

    // std::cout<<as<<"\n";

    unsigned l=0, h=0;
    if (matchLExpSliceIndices(as->left, l, h)) {
        rightExprVec.push_back(as->right);
        slices.emplace_back(l, h);
        prune();
        return nullptr;
    }

    if (rightExprVec.size() != 0) {
        auto asfolded = fold();
        resetFoldContext();
        lExpMember = as->left->clone();
        slices.emplace_back(l, h);
        rightExprVec.push_back(as->right);
        prune();
        return asfolded;
    }
    return as;
}


const IR::Node* FoldLExpSlicesInAsStmts::postorder(IR::StatOrDecl* sd) {

    auto con = findContext<IR::BlockStatement>();
    if (con == nullptr)
        return sd;

    if (rightExprVec.size()!=0) {
        auto as = fold();
        resetFoldContext();
        auto com = new IR::IndexedVector<IR::StatOrDecl>();
        com->push_back(as);
        com->push_back(sd);
        // std::cout<<"as  ---- \n"<<as<<"\n";
        // std::cout<<"sd --- \n"<<sd<<"\n";
        auto bs = new IR::BlockStatement(*com);
        return bs;
    }
    return sd;
}


const IR::Node* FoldLExpSlicesInAsStmts::preorder(IR::BlockStatement* bs) {

    resetFoldContext();

    for (auto& stmt : bs->components)
        visit(stmt);

    if (rightExprVec.size()!=0) {
        auto as = fold();
        bs->components.push_back(as);
    }

    IR::IndexedVector<IR::StatOrDecl> components;
    for (auto s : bs->components) {
        if (s != nullptr)
            components.push_back(s);
    }
    bs->components = components;
    prune();
    return bs;
}



bool FlattenConcatExpression::preorder(const IR::Concat* concat) {

    if (concat->left->is<IR::Concat>()) 
        visit(concat->left);
    else
        exprVec->push_back(concat->left);

    if (concat->right->is<IR::Concat>()) 
        visit(concat->right);
    else
        exprVec->push_back(concat->right);
    return false;
}




bool ReduceConcatExpression::checkReducibility(const IR::Slice* curr, const IR::Slice* exp,
                                            unsigned curL, unsigned& newL) {

    unsigned eH = exp->getH();
    if (eH+1 != curL)
        return false;
        
    bool match = true;
    auto e = exp->e0;
    CompareExpression ce(curr->e0, &match);
    e->apply(ce);
    newL = exp->getL();
    return match;
}

const IR::Expression* ReduceConcatExpression::reduce(const IR::Slice* curr, 
                                               unsigned l, unsigned h) {
    auto ne0 = curr->e0->clone();
    return IR::Slice::make(ne0, l, h);
}


const IR::Expression* ReduceConcatExpression::createConcat(
                                        IR::Vector<IR::Expression>& vec) {

    BUG_CHECK(vec.size() > 0, " bug in ReduceConcatExpression::createConcat");
    auto currConcatLeft = vec[0]->clone();
    if (vec.size() > 1) {
        for (unsigned i = 1; i<vec.size(); i++) {
            currConcatLeft = new IR::Concat(currConcatLeft, vec[i]->clone());
        }
    }
    return currConcatLeft;
}



const IR::Node* ReduceConcatExpression::preorder(IR::Concat* concat) {

    IR::Vector<IR::Expression> exprVec;
    IR::Vector<IR::Expression> concatVec;
    FlattenConcatExpression fce(&exprVec);
    concat->apply(fce);

    const IR::Slice* curr = nullptr;
    unsigned curL = 0;
    unsigned h = 0;
    for (auto exp : exprVec) {
        // std::cout<<exp<<"\n";
        auto e = exp->to<IR::Slice>();
        if (e != nullptr) {
            if (curr == nullptr) {
                curr = e;
                h = e->getH();
                curL = e->getL();
            } else {
                unsigned nl = 0;
                match = checkReducibility(curr, e, curL, nl);
                if (match) {
                    curL = nl;
                } else {
                    auto re = reduce(curr, curL, h);
                    curr = e;
                    curL = e->getL();
                    h = e->getH();
                    concatVec.push_back(re);
                }
            }
        } else {
            if (curr != nullptr) {
                auto re = reduce(curr, curL, h);
                concatVec.push_back(re);
                curr = nullptr;
                curL = 0;
                h = 0;
            }
            concatVec.push_back(e);
        }
    }

    if (curr != nullptr) {
        auto re = reduce(curr, curL, h);
        concatVec.push_back(re);
    }
    return createConcat(concatVec);
}

cstring ReplaceMSAByteHdrStack::getHdrStackInstName(unsigned sn) {
    return NameConstants::csaHeaderInstanceName+"_s"+ cstring::to_cstring(sn);
}


}
