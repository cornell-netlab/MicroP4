#include "../../../ir/ir.h"

namespace IR {

const Type_Method* 
Type_ComposablePackage::getConstructorMethodType() const {
    return new Type_Method(getTypeParameters(), this, constructorParams);
}

const Type_Method*
Type_ComposablePackage::getApplyMethodType() const {
    return new Type_Method(getTypeParameters(), this, applyParams);
}

const Type_Method*
P4ComposablePackage::getConstructorMethodType() const {
    return new Type_Method(getTypeParameters(), this, getConstructorParameters());
}

const Type_Method*
P4ComposablePackage::getApplyMethodType() const {
    return new Type_Method(getTypeParameters(), this, getApplyParameters());
}

const TypeParameters*
P4ComposablePackage::getTypeParameters() const {
    if (type == nullptr)
        return new TypeParameters(srcInfo);
    return type->getTypeParameters(); 
}

const ParameterList*
P4ComposablePackage::getApplyParameters() const {
    if (type == nullptr) 
        return new ParameterList(srcInfo);
    return type->getApplyParameters(); 
}

const ParameterList*
P4ComposablePackage::getConstructorParameters() const {
    if (type == nullptr) 
        return new ParameterList(srcInfo);
    return type->getConstructorParameters();
}

} // namespace IR
