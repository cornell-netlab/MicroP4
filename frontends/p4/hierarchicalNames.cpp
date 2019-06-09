/*
Copyright 2017 VMware, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#include "hierarchicalNames.h"

namespace P4 {

cstring HierarchicalNames::getName(const IR::IDeclaration* decl) {
    if (decl->is<IR::IAnnotated>()) {
        auto node = decl->to<IR::IAnnotated>();
        auto annotation = node->getAnnotation(IR::Annotation::nameAnnotation);
        if (annotation != nullptr) {
            return IR::Annotation::getName(annotation);
        }
    }
    return decl->getName();
}

const IR::Node* HierarchicalNames::postorder(IR::Annotation* annotation) {
    if (annotation->name != IR::Annotation::nameAnnotation)
        return annotation;

    cstring name = IR::Annotation::getName(annotation);
    // std::cout<<name<<"\n";
    if (name.startsWith("."))
        return annotation;
    cstring newName = "";
    for (cstring s : stack)
        newName += s + ".";
    newName += name;
    LOG2("Changing " << name << " to " << newName);
    annotation = new IR::Annotation(annotation->name, { new IR::StringLiteral(newName) });
    return annotation;
}

}  // namespace P4
