#include "alignParamNames.h"

namespace CSA {

    void AlignParamNames::end_apply(const IR::Node* node) {
        std::cout << "end_apply" << std::endl;
        refMap->clear();
        typeMap->clear();
    }

    const IR::Node* AlignParamNames::preorder(IR::P4Program* p4program) {
        for (auto &decl : p4program->objects) {
            if (decl->is<IR::P4ComposablePackage>()) {
                visit(decl);
            }
        }
        prune();
        return p4program;
    }

    const IR::Node* AlignParamNames::preorder(IR::P4ComposablePackage* cpkg) {
        LOG5("visiting " << cpkg);
        packetName = nullptr;
        ingressMetadataName = nullptr;
        headerName = nullptr;
        metadataName = nullptr;
        inArgName = nullptr;
        inOutArgName = nullptr;
        visit(cpkg->packageLocals);
        LOG5("done visiting " << cpkg);
        prune();
        return cpkg;
    }

    const IR::Node* AlignParamNames::preorder(IR::P4Parser* parser) {
        LOG5("visiting " << parser);
        renamings.clear();
        visit(parser->type);
        visit(parser->parserLocals);
        visit(parser->states);
        prune();
        return parser;
    }

    const IR::Node* AlignParamNames::preorder(IR::Type_Parser* parserType) {
        LOG5("visiting " << parserType);
        visit(parserType->applyParams);
        prune();
        return parserType;
    }

    const IR::Node* AlignParamNames::preorder(IR::Type_Control* controlType) {
        LOG5("visiting " << controlType);
        LOG4("before visiting params" << controlType);
        visit(controlType->applyParams);
        LOG4("after visiting params" << controlType);
        prune();
        return controlType;
    }

    void AlignParamNames::setOrRename(cstring *classField, const IR::Parameter* param) {
        if (param == nullptr) {
            return;
        }
        cstring observedValue = param->name.name;
        if (*classField == nullptr) {
            *classField = observedValue;
        } else if (*classField != observedValue) {
            renamings.emplace(observedValue, *classField);
        }
    }

    const IR::Node* AlignParamNames::preorder(IR::ParameterList* params) {
        LOG5("visiting " << params);
        auto ctx = getContext();
        if (ctx == nullptr
            || ctx->parent == nullptr
            || ctx->parent->node == nullptr) {
            ::error("unexpected context");
            return params;
        }
        if (!ctx->node->is<IR::Type_Declaration>()) {
            LOG5("ctx not a type decl: " << ctx->node);
            return params;
        }

        auto decl = ctx->node->to<IR::Type_Declaration>();

        const IR::Parameter *declPacketName = nullptr;
        const IR::Parameter *declIngressMetadataName = nullptr;
        const IR::Parameter *declHeaderName = nullptr;
        const IR::Parameter *declMetadataName = nullptr;
        const IR::Parameter *declInArgName = nullptr;
        const IR::Parameter *declInOutArgName = nullptr;
        
        auto enumerator = params->getEnumerator();
        /* XXX i've been comparing cstrings with ==. Does that even work */
        if (decl->name == "micro_parser") {
            if (params->size() != 7) {
                BUG("micro_parser should have 7 params but has: %1%", params->size());
            }
            enumerator->moveNext();
            /* skip 1st arg, the extractor */
            enumerator->moveNext();
            declPacketName = enumerator->getCurrent();
            enumerator->moveNext();
            declIngressMetadataName = enumerator->getCurrent();
            enumerator->moveNext();
            declHeaderName = enumerator->getCurrent();
            enumerator->moveNext();
            declMetadataName = enumerator->getCurrent();
            LOG5("declMetadataName: " << declMetadataName);
            enumerator->moveNext();
            declInArgName = enumerator->getCurrent();
            enumerator->moveNext();
            declInOutArgName = enumerator->getCurrent();
        } else if (decl->name == "micro_control") {
            if (params->size() != 7) {
                BUG("micro_control should have 7 params but has: %1%", params->size());
            }
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
            /* skip 6th arg, the out argument */
            enumerator->moveNext();
            declInOutArgName = enumerator->getCurrent();
        } else if (decl->name == "micro_deparser") {
            if (params->size() != 3) {
                BUG("micro_deparser should have 3 params but has: %1%", params->size());
            }

            enumerator->moveNext();
            /* skip 1st arg, the emitter */
            enumerator->moveNext();
            declPacketName = enumerator->getCurrent();
            enumerator->moveNext();
            declHeaderName = enumerator->getCurrent();

        }

        setOrRename(&packetName, declPacketName);
        setOrRename(&ingressMetadataName, declIngressMetadataName);
        setOrRename(&headerName, declHeaderName);
        LOG4("before setOrRename, metadataName = " << metadataName);
        setOrRename(&metadataName, declMetadataName);
        LOG4("after setOrRename, metadataName = " << metadataName);
        LOG4("after setOrRename, declMetadataName = " << declMetadataName);
        setOrRename(&inArgName, declInArgName);
        setOrRename(&inOutArgName, declInOutArgName);

        LOG4("before visiting parameters " << params);
        visit(params->parameters);
        LOG4("after visiting parameters " << params);
        prune();
        return params;
    }

    const IR::Node* AlignParamNames::preorder(IR::P4Control* control) {
        LOG5("visiting " << control);
        renamings.clear();
        LOG4("before visiting type" << control);
        visit(control->type);
        LOG4("after visiting type" << control);
        visit(control->controlLocals);
        visit(control->body);
        prune();
        return control;
    }

    const IR::Node* AlignParamNames::preorder(IR::Path* path) {
        LOG5("visiting " << path);
        auto name = path->name;
        auto it = renamings.find(name.name);
        if (it != renamings.end()) {
            auto newName = it->second;
            path = new IR::Path(IR::ID(name.srcInfo, newName));
        }
        return path;
    }

    const IR::Node* AlignParamNames::preorder(IR::Parameter* param) {
        LOG4("visiting " << param);
        auto name = param->name;
        auto it = renamings.find(name.name);
        IR::Parameter *ret;
        if (it != renamings.end()) {
            LOG4("found: " << param);
            auto newName = it->second;
            auto newID = IR::ID(name.srcInfo, newName);
            ret = new IR::Parameter(newID, param->direction, param->type);
            LOG4("changed to: " << ret);
        } else {
            ret = new IR::Parameter(param->name, param->direction, param->type);
            LOG4("not found: " << param);
        }

        return ret;
    }

}
