/*
 * mcengineConverter.h
 *
 *  Created on: Apr 3, 2020
 *      Author: myriana
 */

#ifndef EXTENSIONS_CSA_MIDEND_MCENGINECONVERTER_H_
#define EXTENSIONS_CSA_MIDEND_MCENGINECONVERTER_H_

#include "ir/ir.h"
#include "lib/ordered_map.h"
#include "frontends/common/resolveReferences/resolveReferences.h"
#include "frontends/p4/typeMap.h"
#include "controlStateReconInfo.h"
#include "msaNameConstants.h"

/*
 * This pass converts parser into DAG of MATs
 */
namespace CSA {

class MCengineConverter final : public Transform {

	  	P4::ReferenceMap* refMap;
	    P4::TypeMap* typeMap;
	    unsigned initOffset;
	    cstring pktParamName;
	    cstring fieldName;

	    P4::SymbolicValueFactory svf;
	    std::vector<const IR::AssignmentStatement*> createPerFieldAssignmentStmts(
	          const IR::Expression* hdrVar, unsigned start);

	 public:
	    using Transform::preorder;
	    using Transform::postorder;

	    explicit MCengineConverter(P4::ReferenceMap* refMap, P4::TypeMap* typeMap,
	                                unsigned initOffset, cstring pktParamName,
	                                cstring fieldName)
	        : refMap(refMap), typeMap(typeMap), initOffset(initOffset),
			  pktParamName(pktParamName),
	          fieldName(fieldName), svf(typeMap) {
	        setName("MCengineConverter");
	    }


	    const IR::Node* preorder(IR::MethodCallStatement* mcs) override;

};

}

#endif /* EXTENSIONS_CSA_MIDEND_MCENGINECONVERTER_H_ */
