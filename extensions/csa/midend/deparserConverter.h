/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_LINKER_DEPARSERCONVERTER_H_ 
#define _EXTENSIONS_CSA_LINKER_DEPARSERCONVERTER_H_ 

#include <tuple>
#include "ir/ir.h"
#include "lib/ordered_map.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeMap.h"
#include "midend/interpreter.h"
#include "frontends/p4/callGraph.h"
#include "msaNameConstants.h"

/*
 * This pass converts parser into a MAT
 */
namespace CSA {

typedef P4::CallGraph<const IR::MethodCallStatement*> EmitCallGraph;

class DeparserConverter final : public Transform {

// global throught the pass
    cstring noActionName;
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    cstring tableName = "deparser_tbl";

    P4::SymbolicValueFactory* symbolicValueFactory;

// per deparser
    const std::vector<unsigned>& initialOffsets;
    const std::vector<std::set<cstring>>* xoredHeaderSets;
    EmitCallGraph* emitCallGraph;
    IR::IndexedVector<IR::Declaration> varDecls;
    std::map<const IR::MethodCallStatement*, 
             IR::IndexedVector<IR::Declaration>> actionDecls;
    IR::IndexedVector<IR::Declaration> tableDecls;

    cstring paketOutParamName;
    std::map<const IR::MethodCallStatement*, cstring> emitIds;
    //  mcs -> <varname, action setting the var> 
    std::map<const IR::MethodCallStatement*, std::pair<cstring, cstring>> 
        controlVar;

    // used to build key. 
    // IR::Member -> hdr.ip  
    // bool -> true -> exact, false->ternary
    std::map<const IR::MethodCallStatement*, 
             std::vector<std::pair<const IR::Expression*, bool>>>  keyElementLists;

    std::map<const IR::MethodCallStatement*, 
             std::vector<std::tuple<IR::ListExpression*, unsigned, IR::P4Action*>>> 
                keyValueEmitOffsets;

    void createTableEntryList(const IR::MethodCallStatement* mcs);
    IR::P4Action* createP4Action(const IR::MethodCallStatement* mcs,
            unsigned& currentEmitOffset, const IR::P4Action* ancestorAction);
    IR::P4Action* createP4Action(const IR::MethodCallStatement* mcs,
                           unsigned& currentEmitOffset);
    IR::Key* createKey(const IR::MethodCallStatement* mcs);

    IR::P4Table* createP4Table(cstring name, IR::Key* key, IR::ActionList* al, 
                               IR::EntriesList* el);

    IR::P4Table* createEmitTable(const IR::MethodCallStatement* mcs);

    IR::P4Table* extendEmitTable(const IR::MethodCallStatement* mcs,
                         const IR::MethodCallStatement* predecessor);

    /*
    IR::P4Table* mergeAndExtendEmitTables(const IR::P4Table* oldTable, const IR::MethodCallStatement*,
                                  std::vector<const IR::MethodCallStatement*>*);
    */

    void createID(const IR::MethodCallStatement* emitStmt);
    const IR::Expression* getArgHeaderExpression(const IR::MethodCallStatement* mcs, 
                                                 unsigned& width) const;

    bool isDeparser(const IR::P4Control* p4control);

    void initTableWithOffsetEntries(const IR::MethodCallStatement* mcs);

    std::vector<cstring> keyExpToNameStrVec(
        std::vector<std::pair<const IR::Expression*, bool>>& ke);

    bool emitsXORedHdrs(const std::vector<cstring>& vec, const IR::ListExpression* ls);

 public:
    using Transform::preorder;
    using Transform::postorder;

    explicit DeparserConverter(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
        const std::vector<unsigned>& initialOffsets,
        const std::vector<std::set<cstring>>* xoredHeaderSets)
        : refMap(refMap), typeMap(typeMap), initialOffsets(initialOffsets), 
          xoredHeaderSets(xoredHeaderSets) {
        setName("DeparserConverter"); 
        symbolicValueFactory = new P4::SymbolicValueFactory(typeMap);
        noActionName = "NoAction";
    }

    const IR::Node* preorder(IR::P4Control* deparser) override;
    const IR::Node* postorder(IR::P4Control* deparser) override;
    const IR::Node* preorder(IR::MethodCallStatement* mcs) override;
    const IR::Node* postorder(IR::Parameter* param) override;
    const IR::Node* postorder(IR::BlockStatement* param) override;
};


class CreateEmitSchedule final : public Inspector { 
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    EmitCallGraph* emitCallGraph;
    std::vector<std::vector<const IR::MethodCallStatement*>> frontierStack;
    bool addDummyInit;
  public:
    
    CreateEmitSchedule(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
                       EmitCallGraph* emitCallGraph, bool addDummyInit=false) 
      :  refMap(refMap), typeMap(typeMap), emitCallGraph(emitCallGraph), 
         addDummyInit(addDummyInit) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap); 
        setName("CreateEmitSchedule"); 
    }
    bool preorder(const IR::P4Control* deparser) override;
    bool preorder(const IR::MethodCallStatement* mcs) override;
    bool preorder(const IR::IfStatement* ifStmt) override;
    bool preorder(const IR::SwitchStatement* swStmt) override;
};


}  // namespace CSA

#endif /* _EXTENSIONS_CSA_LINKER_DEPARSERCONVERTER_H_ */
