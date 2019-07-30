/*
 * Author: Hardik Soni
 * Email: hks57@cornell.edu
 */

#ifndef _EXTENSIONS_CSA_LINKER_VIRTUALBUFFER_H_
#define _EXTENSIONS_CSA_LINKER_VIRTUALBUFFER_H_
#include <sstream>
#include "ir/ir.h"
#include "lib/source_file.h"

namespace CSA {

enum class VBufOccupancyStatus {
    UNKNOWN,
    KNOWN
};

class VirtualBuffer : public IHasDbPrint {

  private:
    const IR::ParameterList* elementType;
    VBufOccupancyStatus countStatus;
    unsigned int count;
    cstring bufferId;

    constexpr static char statusKnown[] = "Known";
    constexpr static char statusUnknown[] = "Unknown";

  public:
    VirtualBuffer(const IR::ParameterList* elementType) : 
        elementType(elementType), countStatus(VBufOccupancyStatus::KNOWN), count(0) {}

    void enqueue() { count++; }
    void dequeue() { count--; }

    void resetCount() {
        countStatus = VBufOccupancyStatus::KNOWN;
        count = 0;
    }

    void setCountUnkown() {
        countStatus = VBufOccupancyStatus::UNKNOWN;
    }

    unsigned int getCount() { return count; }
    VBufOccupancyStatus getOccupancyStatus() { return countStatus; } 


    void dbprint(std::ostream& out) const override {
        out<<"Buffer ID - "<<bufferId
           <<"Count Status"<<(countStatus==VBufOccupancyStatus::KNOWN?statusKnown:statusUnknown)
           <<"Count - "<<count<<std::endl;
    }

};


class ComposableUnit : public IHasDbPrint {

  private:
    VirtualBuffer     *inVBuf;
    VirtualBuffer     *outVBuf;

    // IApply nodes or IfStatement or SwitchStatement
    const IR::IApply        *applyNode;


  public:
    explicit ComposableUnit(const IR::ParameterList* inParameters, 
                            const IR::ParameterList* outParameters, 
                            const IR::IApply* applyNode) {
        inVBuf = new VirtualBuffer(inParameters);
        outVBuf = new VirtualBuffer(outParameters);
        applyNode = applyNode;
    }

    void dbprint(std::ostream& out) const override { 
        
    }
};

}
#endif  /* _EXTENSIONS_CSA_LINKER_VIRTUALBUFFER_H_ */
