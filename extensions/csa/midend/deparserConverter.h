/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_LINKER_DEPARSERCONVERTER_H_ 
#define _EXTENSIONS_CSA_LINKER_DEPARSERCONVERTER_H_ 

#include "ir/ir.h"
#include "lib/ordered_map.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeMap.h"
#include "midend/interpreter.h"
#include "frontends/p4/callGraph.h"

/*
 * This pass converts parser into DAG of MATs
 */
namespace CSA {

typedef P4::CallGraph<const IR::MethodCallStatement*> EmitCallGraph;

class DeparserConverter final : public Transform {

// global throught the pass
    cstring noActionName;
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    cstring structTypeName;
    cstring fieldName;
    cstring tableName = "deparser_tbl";

    P4::SymbolicValueFactory* symbolicValueFactory;

// per deparser
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
             std::vector<std::pair<IR::ListExpression*, unsigned>>> 
                keyValueEmitOffsets;



    void createTableEntryList(const IR::MethodCallStatement* mcs);
    cstring createP4Action(const IR::MethodCallStatement* mcs,
                           unsigned& currentEmitOffset);
    IR::Key* createKey(const IR::MethodCallStatement* mcs);


    IR::P4Table* createP4Table(cstring name, IR::Key* key, IR::ActionList* al, 
                               IR::EntriesList* el);

    IR::P4Table* createEmitTable(const IR::MethodCallStatement* mcs);

    IR::P4Table* extendEmitTable(const IR::P4Table* oldTable, const IR::MethodCallStatement* mcs,
                         const IR::MethodCallStatement* predecessor);

    IR::P4Table* mergeAndExtendEmitTables(const IR::P4Table* oldTable, const IR::MethodCallStatement*,
                                  std::vector<const IR::MethodCallStatement*>*);

    void createID(const IR::MethodCallStatement* emitStmt);
    const IR::Expression* getArgHeaderExpression(const IR::MethodCallStatement* mcs, 
                                                 unsigned& width) const;


    bool isDeparser(const IR::P4Control* p4control);
 public:
    using Transform::preorder;
    using Transform::postorder;

    explicit DeparserConverter(P4::ReferenceMap* refMap, P4::TypeMap* typeMap,
                               cstring structTypeName, cstring fieldName)
        : refMap(refMap), typeMap(typeMap), structTypeName(structTypeName), 
          fieldName(fieldName) { 
        setName("DeparserConverter"); 
        symbolicValueFactory = new P4::SymbolicValueFactory(typeMap);
        noActionName = "NoAction";
    }

    const IR::Node* preorder(IR::P4Control* deparser) override;
    const IR::Node* postorder(IR::P4Control* deparser) override;
    const IR::Node* preorder(IR::MethodCallStatement* mcs) override;
    const IR::Node* postorder(IR::Parameter* param) override;
};


class CreateEmitSchedule final : public Inspector { 
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    EmitCallGraph* emitCallGraph;
    std::vector<std::vector<const IR::MethodCallStatement*>> frontierStack;
  public:
    
    CreateEmitSchedule(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
                       EmitCallGraph* emitCallGraph) 
      :  refMap(refMap), typeMap(typeMap), emitCallGraph(emitCallGraph) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap); 
        setName("CreateEmitSchedule"); 
    }
    bool preorder(const IR::MethodCallStatement* mcs) override;
    bool preorder(const IR::IfStatement* ifStmt) override;
    bool preorder(const IR::SwitchStatement* swStmt) override;
};


/*
class ConvertAllDeparsers final : public PassManager {
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    unsigned maxOffset;
  public:
    ConvertAllParsers(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
                      const IR::P4Parser* mainParser = nullptr, 
                      bool convertMainParser = false) 
        : refMap(refMap), typeMap(typeMap) {
        CHECK_NULL(refMap); CHECK_NULL(typeMap);

        cstring structTypeName = "csa_packet_in_t";
        cstring fieldName = "bitStream";
        passes.push_back(new EvaluateAllDeparsers(refMap, typeMap, &parserEvalMap,
                                &maxOffset));
        passes.push_back(new ParserConverter(refMap, typeMap, structTypeName, 
                                fieldName));
    }

};
*/

}  // namespace CSA

#endif /* _EXTENSIONS_CSA_LINKER_DEPARSERCONVERTER_H_ */
