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
#include "midend/controlBlockInterpreter.h"

/*
 * This pass converts parser into a MAT
 */
namespace CSA {

typedef P4::CallGraph<const IR::MethodCallStatement*> EmitCallGraph;

class DeparserConverter final : public Transform {

  typedef std::tuple<IR::ListExpression*, unsigned, IR::P4Action*, unsigned> EntryContext;

  // currOffset, cumulative moveOffset, hdr name
  // Current offset is index for the state of stack after parsing.
  // emitIndex would be currOffset+moveOffset for deparsing
  typedef std::tuple<unsigned, int, cstring> 
    CurrOSMoveOSHdr;


// global throught the pass
    cstring noActionName;
    P4::ReferenceMap* refMap;
    P4::TypeMap* typeMap;
    cstring tableName = "deparser_tbl";
    cstring hdrVOPTypeParamName = "hdr_vop";

    P4::SymbolicValueFactory* symbolicValueFactory;

// per deparser
    const std::vector<unsigned>& initialOffsets;
    const std::vector<std::set<cstring>>* xoredHeaderSets;
    const std::set<cstring>* parsedHeaders;
    const P4::HdrValidityOpsRecVec* xoredValidityOps;
    const unsigned* byteStackSize;
    IR::Type_Struct* hdrVOPType;
    cstring parserMSAMetaStrTypeName;

    EmitCallGraph* emitCallGraph;
    std::unordered_map<cstring, unsigned> hdrSizeByInstName;
    std::unordered_map<cstring, const IR::MethodCallStatement*> hdrMCSMap;

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

    // Only "member" part is stored incase of member.
    // e.g., for hdr.eth, only <eth, 112> is stored
    std::vector<std::pair<cstring, unsigned>> keyNamesWidths;
    std::vector<std::vector<char>> headerKeyValues;
    const IR::MethodCallStatement* lastMcsEmitted = nullptr;

    std::map<const IR::MethodCallStatement*, std::vector<EntryContext>> 
        keyValueEmitOffsets;


    IR::P4Action* createP4Action(const IR::MethodCallStatement* mcs,
            unsigned& currentEmitOffset, const IR::P4Action* ancestorAction);
    IR::P4Action* createP4Action(const IR::MethodCallStatement* mcs,
                           unsigned& currentEmitOffset);

    IR::P4Action* createP4Action(const cstring hdrInstName, 
                                unsigned currentEmitOffset);

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
                                                 unsigned& width, 
                                                 cstring& hdrInstName);

    bool isDeparser(const IR::P4Control* p4control);

    void initTableWithOffsetEntries(const IR::MethodCallStatement* mcs);

    std::vector<cstring> keyExpToNameStrVec(
        std::vector<std::pair<const IR::Expression*, bool>>& ke);

    bool emitsXORedHdrs(const std::vector<cstring>& vec, const IR::ListExpression* ls);

    bool isParsableHeader(cstring hdr);


    void resizeReplicateKeyValueVec(size_t nfold);
    void insertValueKeyValueVec(char v, size_t begin, size_t end);
    void removeEmptyElementsKeyValueVec();
    void printHeaderKeyValues();


    std::vector<std::pair<cstring, bool>> hdrOpKeyNames;
    std::vector<std::vector<char>> hdrValidityOpKeyValues;

    void createHdrValidityOpsKeysNames(const IR::MethodCallStatement* dummyMCS);
    void createHdrValidityOpsKeysValues();
    EntryContext extendEntry(const IR::MethodCallStatement* mcs,
        const EntryContext& entry, const std::vector<char>& newKVs, 
        const std::vector<CurrOSMoveOSHdr>& emitData, 
        int moveOffset, unsigned currOffset);
    IR::P4Table* multiplyHdrValidityOpsTable(const IR::MethodCallStatement* dummyMCS);
    IR::P4Action* createByteMoveP4Action(unsigned moveInitIdx, 
                                      int moveOffset, unsigned moveBlockSize);
    
    void printEIMvOsHdr(const std::vector<CurrOSMoveOSHdr>& v);

 public:
    using Transform::preorder;
    using Transform::postorder;

    explicit DeparserConverter(P4::ReferenceMap* refMap, P4::TypeMap* typeMap, 
        const std::vector<unsigned>& initialOffsets,
        const std::vector<std::set<cstring>>* xoredHeaderSets,
        const std::set<cstring>* parsedHeaders = nullptr,
        const P4::HdrValidityOpsRecVec* xoredValidityOps = nullptr,
        const unsigned* byteStackSize = nullptr,
        IR::Type_Struct* hdrVOPType = nullptr, 
        cstring parserMSAMetaStrTypeName = "")
        : refMap(refMap), typeMap(typeMap), initialOffsets(initialOffsets), 
          xoredHeaderSets(xoredHeaderSets),  parsedHeaders(parsedHeaders),
          xoredValidityOps(xoredValidityOps), 
          byteStackSize(byteStackSize),
          hdrVOPType(hdrVOPType), 
          parserMSAMetaStrTypeName(parserMSAMetaStrTypeName){
        setName("DeparserConverter"); 
        symbolicValueFactory = new P4::SymbolicValueFactory(typeMap);
        noActionName = "NoAction";
    }

    Visitor::profile_t init_apply(const IR::Node* node) override;
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
