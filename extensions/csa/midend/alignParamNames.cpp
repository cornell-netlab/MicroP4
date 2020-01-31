#include "alignParamNames.h"

namespace CSA {
    const IR::Node* AlignParamNames::preorder(IR::P4ComposablePackage* cpkg) {
        auto parser = cpkg->getDeclByName("micro_parser")->getNode();
        auto control = cpkg->getDeclByName("micro_control")->getNode();
        auto deparser = cpkg->getDeclByName("micro_deparser")->getNode();
        visit(*parser);
        visit(*control);
        visit(*deparser);
        prune();
        return cpkg;
    }

    const IR::Node* AlignParamNames::preorder(IR::P4Parser* parser) {
        renamings.clear();
        visit(parser->type);
        prune();
        return parser;
    }

    const IR::Node* AlignParamNames::preorder(IR::Type_Parser* parserType) {
        visit(parserType->applyParams);
        prune();
        return parserType;
    }

    const IR::Node* AlignParamNames::preorder(IR::Type_Control* controlType) {
        visit(controlType->applyParams);
        prune();
        return controlType;
    }

    void AlignParamNames::setOrRename(cstring *classField, const IR::Parameter* param) {
        cstring observedValue = param->name.name;
        if (*classField == nullptr) {
            *classField = observedValue;
        } else {
            renamings.emplace(observedValue, *classField);
        }
    }

    const IR::Node* AlignParamNames::preorder(IR::ParameterList* params) {
        auto ctx = getContext();
        if (ctx == nullptr
            || ctx->parent == nullptr
            || !ctx->node->is<IR::Type>()
            || !ctx->parent->node->is<IR::Declaration>()) {
            return params;
        }
        auto decl = ctx->parent->node->to<IR::Declaration>();
        auto enumerator = params->getEnumerator();
        const IR::Parameter *declPacketName;
        const IR::Parameter *declIngressMetadataName;
        const IR::Parameter *declHeaderName;
        const IR::Parameter *declMetadataName;
        const IR::Parameter *declInArgName;
        const IR::Parameter *declInOutArgName;
        
        /* XXX i've been comparing cstrings with ==. Does that even work */
        if (decl->name == "micro_parser") {
            if (params->size() != 7) {
                ::error("micro_parser should have 7 params but has: %1", params);
            }
            /* skip 1st arg, the extractor */
            enumerator->moveNext();
            declPacketName = enumerator->getCurrent();
            enumerator->moveNext();
            declIngressMetadataName = enumerator->getCurrent();
            enumerator->moveNext();
            declHeaderName = enumerator->getCurrent();
            enumerator->moveNext();
            declMetadataName = enumerator->getCurrent();
            enumerator->moveNext();
            declInArgName = enumerator->getCurrent();
            enumerator->moveNext();
            declInOutArgName = enumerator->getCurrent();
        } else if (decl->name == "micro_control") {
            if (params->size() != 7) {
                ::error("micro_control should have 7 params but has: %1", params);
            }
            declPacketName = enumerator->getCurrent();
            enumerator->moveNext();
            declIngressMetadataName = enumerator->getCurrent();
            enumerator->moveNext();
            declHeaderName = enumerator->getCurrent();
            enumerator->moveNext();
            declMetadataName = enumerator->getCurrent();
            enumerator->moveNext();
            declInArgName = enumerator->getCurrent();
            enumerator->moveNext();
            /* skip 6th arg, the out argument */
            enumerator->moveNext();
            declInOutArgName = enumerator->getCurrent();
        } else if (decl->name == "micro_deparser") {
            if (params->size() != 3) {
                ::error("micro_deparser should have 3 params but has: %1", params);
            }

            /* skip 1st arg, the emitter */
            enumerator->moveNext();
            declPacketName = enumerator->getCurrent();
            enumerator->moveNext();
            declHeaderName = enumerator->getCurrent();

        }

        setOrRename(&packetName, declPacketName);
        setOrRename(&ingressMetadataName, declIngressMetadataName);
        setOrRename(&headerName, declHeaderName);
        setOrRename(&metadataName, declMetadataName);
        setOrRename(&inArgName, declInArgName);
        setOrRename(&inOutArgName, declInOutArgName);

        return params;
    }

    const IR::Node* AlignParamNames::preorder(IR::P4Control* control) {
        renamings.clear();
        visit(control->type);
        return control;
    }

    const IR::Node* AlignParamNames::preorder(IR::Path* path) {
        auto name = path->name;
        auto it = renamings.find(name.name);
        if (it != renamings.end()) {
            auto newName = it->second;
            path->name = IR::ID(name.srcInfo, newName, name.originalName);
        }
        return path;
    }

    const IR::Node* AlignParamNames::preorder(IR::Parameter* param) {
        auto name = param->name;
        auto it = renamings.find(name.name);
        if (it != renamings.end()) {
            auto newName = it->second;
            param->name = IR::ID(name.srcInfo, newName, name.originalName);
        }
        return param;
    }

}
