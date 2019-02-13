/*
Copyright 2013-present Barefoot Networks, Inc.

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

#include <sstream>

#include "symbol_table.h"
#include "lib/exceptions.h"
#include "lib/error.h"
#include "lib/log.h"

namespace Util {

class NamedSymbol {
 protected:
    Util::SourceInfo sourceInfo;
    Namespace* parent;
    cstring name;

 public:
    NamedSymbol(cstring name, Util::SourceInfo si) :
            sourceInfo(si),
            parent(nullptr),
            name(name) {}
    virtual ~NamedSymbol() {}

    void setParent(Namespace* ns) {
        BUG_CHECK(parent == nullptr, "Parent already set");
        parent = ns;
    }

    Namespace* getParent() const { return parent; }
    SourceInfo getSourceInfo() const { return sourceInfo; }
    cstring getName() const { return name; }
    virtual cstring toString() const { return getName(); }
    virtual void dump(std::stringstream& into, unsigned indent) const {
        std::string s(indent, ' ');
        into << s << toString() << std::endl;
    }
    virtual bool sameType(const NamedSymbol* other) const {
        return typeid(*this) == typeid(*other);
    }

    virtual NamedSymbol* clone() const = 0;
};

class Namespace : public NamedSymbol {
 protected:
    std::unordered_map<cstring, NamedSymbol*> contents;
    bool allowDuplicates;

 public:
    Namespace(const Namespace& ns)
        : NamedSymbol(ns.getName(), ns.getSourceInfo()), 
          allowDuplicates(ns.allowDuplicates) {}

    Namespace(cstring name, Util::SourceInfo si, bool allowDuplicates) :
            NamedSymbol(name, si),
            allowDuplicates(allowDuplicates) {}

    void declare(NamedSymbol* symbol) {
        cstring symname = symbol->getName();
        if (symname.isNullOrEmpty()) return;

        auto it = contents.find(symname);
        if (it != contents.end()) {
            // Check that both declarations have the same type
            if (!it->second->sameType(symbol)) {
                ::error("Re-declaration of %1%%2% with different type: %3%",
                        symbol->getName(), symbol->getSourceInfo(), it->second->getSourceInfo());
                return;
            }

            if (!allowDuplicates) {
                ::error("Duplicate declaration of %1%%2%; previous at %3%",
                        symbol->getName(), symbol->getSourceInfo(), it->second->getSourceInfo());
                return;
            }
        }
        contents.emplace(symbol->getName(), symbol);
    }

    void cloneNamedSymbolsTo(Namespace* parent) const {
        for (const auto& item : contents) {
            auto symbol = item.second->clone();
            symbol->setParent(parent);
            parent->declare(symbol);
        }
    }

    NamedSymbol* lookup(cstring name) const {
        auto it = contents.find(name);
        if (it == contents.end())
            return nullptr;
        return it->second;
    }

    virtual Namespace* clone() const override {
        Namespace* newNS = new Namespace(*this);
        newNS->clear();
        cloneNamedSymbolsTo(newNS);
        return newNS;
    }

    cstring toString() const override { return cstring("Namespace ") + getName(); }
    void dump(std::stringstream& into, unsigned indent) const override {
        std::string s(indent, ' ');
        into << s;
        into << toString() << "{" << std::endl;
        for (auto it : contents)
            it.second->dump(into, indent+1);
        into << s;
        into << "}" << std::endl;
    }
    void clear() {
        contents.clear();
    }
};

class Object : public NamedSymbol {
 public:
    Object(cstring name, Util::SourceInfo si) : NamedSymbol(name, si) {}

    Object(const Object& obj)
      : NamedSymbol(obj.getName(), obj.getSourceInfo()) {}


    cstring toString() const override { return cstring("Object ") + getName(); }
    virtual Object* clone() const override {
        Object* obj = new Object(*this);
        return obj;
    }
};

class SimpleType : public NamedSymbol {
 public:
    SimpleType(cstring name, Util::SourceInfo si) : NamedSymbol(name, si) {}

    SimpleType(const SimpleType& st)
      : NamedSymbol(st.getName(), st.getSourceInfo()) {}
  
    cstring toString() const { return cstring("SimpleType ") + getName(); }
    virtual SimpleType* clone() const override {
        SimpleType* st = new SimpleType(*this);
        return st;
    }
};

// A Type that is also a namespace (e.g., a parser)
class ContainerType : public Namespace {
 public:
    ContainerType(cstring name, Util::SourceInfo si, bool allowDuplicates) :
            Namespace(name, si, allowDuplicates) {}

    ContainerType(const ContainerType& ct) 
      : Namespace(ct.getName(), ct.getSourceInfo(), ct.allowDuplicates)  {}
  

    cstring toString() const { return cstring("ContainerType ") + getName(); }

    virtual ContainerType* clone() const override {
        ContainerType* ct = new ContainerType(*this);
        ct->clear();
        cloneNamedSymbolsTo(ct);
        return ct;
    }

};

/////////////////////////////////////////////////

ProgramStructure::ProgramStructure()
        : debug(false),
          debugStream(nullptr),
          rootNamespace(nullptr),
          currentNamespace(nullptr) {
    rootNamespace = new Namespace("", Util::SourceInfo(), true);
    currentNamespace = rootNamespace;
    // We use stderr because we want debugging output
    // to be the same as the bison debugging output.
    debugStream = stderr;
}

void ProgramStructure::push(Namespace* ns) {
    CHECK_NULL(ns);
    if (debug)
        fprintf(debugStream, "ProgramStructure: pushing %s\n", ns->toString().c_str());
    BUG_CHECK(currentNamespace != nullptr, "Null currentNamespace");
    currentNamespace->declare(ns);
    ns->setParent(currentNamespace);
    currentNamespace = ns;
}

void ProgramStructure::pushNamespace(SourceInfo si, bool allowDuplicates) {
    // Today we don't have named namespaces
    auto ns = new Util::Namespace("", si, allowDuplicates);
    push(ns);
}

void ProgramStructure::pushContainerType(IR::ID id, bool allowDuplicates) {
    auto ct = new Util::ContainerType(id.name, id.srcInfo, allowDuplicates);
    push(ct);
}

/* change implementedFrom  to IR::Type.
 *  IR::Type -> IR::Type_Name has  path OR
 *  IR::Type -> Type_Specialized has IR::Type_Name has path
 */
void ProgramStructure::pushContainerType(IR::ID id, const IR::Type* implements, 
                                         bool allowDuplicates) {
    cstring implementedFrom;
    if (implements->is<IR::Type_Name>()) {
        implementedFrom = implements->to<IR::Type_Name>()->path->name;
    } else if (implements->is<IR::Type_Specialized>()) {
        implementedFrom = implements->to<IR::Type_Specialized>()->baseType->path->name;
    } else {
        BUG("unexpected base type for interface to be implemented");
    }
    pushContainerType(id, implementedFrom, allowDuplicates);
}


void ProgramStructure::pushContainerType(IR::ID id, cstring implementedFrom, 
                                         bool allowDuplicates) {
    auto ct = new Util::ContainerType(id.name, id.srcInfo, allowDuplicates);
    if (Namespace *ns = dynamic_cast<Namespace*>(lookup(implementedFrom))) {
        ns->cloneNamedSymbolsTo(ct);
        push(ct);
    } else {
        ::error("%1% can not be implemented", implementedFrom.c_str());
    }
}

void ProgramStructure::pop() {
    Namespace* parent = currentNamespace->getParent();
    BUG_CHECK(parent != nullptr, "Popping root namespace");
    if (debug)
        fprintf(debugStream, "ProgramStructure: popping %s\n",
                currentNamespace->toString().c_str());
    currentNamespace = parent;
}

void ProgramStructure::declareType(IR::ID id) {
    if (debug)
        fprintf(debugStream, "ProgramStructure: adding type %s\n", id.name.c_str());

    auto st = new SimpleType(id.name, id.srcInfo);
    currentNamespace->declare(st);
}

void ProgramStructure::declareObject(IR::ID id) {
    if (debug)
        fprintf(debugStream, "ProgramStructure: adding object %s\n", id.name.c_str());

    auto o = new Object(id.name, id.srcInfo);
    currentNamespace->declare(o);
}

void ProgramStructure::startAbsolutePath() {
    identifierContext.lookupContext = rootNamespace;
}

void ProgramStructure::clearPath() {
    identifierContext.lookupContext = nullptr;
}

NamedSymbol* ProgramStructure::lookup(cstring identifier) const {
    Namespace* parent = identifierContext.lookupContext;
    if (parent == nullptr) {
        // We don't have a parent, try lookup up the stack
        parent = currentNamespace;
        while (parent != nullptr) {
            NamedSymbol* symbol = parent->lookup(identifier);
            if (symbol != nullptr)
                return symbol;
            parent = parent->getParent();
        }
    }

    if (parent == nullptr)
        return nullptr;
    return parent->lookup(identifier);
}

ProgramStructure::SymbolKind ProgramStructure::lookupIdentifier(cstring identifier) const {
    NamedSymbol* ns = lookup(identifier);
    if (ns == nullptr || dynamic_cast<Object*>(ns) != nullptr) {
        LOG2("Identifier " << identifier);
        return ProgramStructure::SymbolKind::Identifier;
    }
    if (dynamic_cast<SimpleType*>(ns) != nullptr || dynamic_cast<ContainerType*>(ns) != nullptr) {
        return ProgramStructure::SymbolKind::Type;
        LOG2("Type " << identifier);
    }
    BUG("Should be unreachable");
}

void ProgramStructure::declareTypes(const IR::IndexedVector<IR::Type_Var>* typeVars) {
    if (typeVars == nullptr)
        return;
    for (auto tv : *typeVars)
        declareType(tv->name);
}

void ProgramStructure::endParse() {
    BUG_CHECK(currentNamespace == rootNamespace,
              "Namespace stack is not empty at the end of parsing");
}

cstring ProgramStructure::toString() const {
    std::stringstream res;
    rootNamespace->dump(res, 0);
    return cstring(res.str());
}

void ProgramStructure::clear() {
    rootNamespace->clear();
    currentNamespace = rootNamespace;
    debugStream = stderr;
}
}  // namespace Util
