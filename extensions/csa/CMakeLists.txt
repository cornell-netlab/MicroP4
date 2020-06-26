configure_file("${CMAKE_CURRENT_SOURCE_DIR}/switch/version.h.cmake"
  "${CMAKE_CURRENT_BINARY_DIR}/switch/version.h" @ONLY)


set (MSA_IR_SRCS
     ${CMAKE_CURRENT_SOURCE_DIR}/ir/dbprint-csa-ext.cpp
     ${CMAKE_CURRENT_SOURCE_DIR}/ir/ir-csa-ext.cpp
    )
set(EXTENSION_FRONTEND_SOURCES ${EXTENSION_FRONTEND_SOURCES} ${MSA_IR_SRCS} PARENT_SCOPE)

set (MSA_SOURCE_DIR  ${P4C_SOURCE_DIR}/extensions/csa)
set (MSA_MIDEND_SOURCE_DIR  ${P4C_SOURCE_DIR}/extensions/csa/midend)
set (MSA_BACKEND_SOURCE_DIR  ${P4C_SOURCE_DIR}/extensions/csa/backend)


include_directories (
    ${MSA_SOURCE_DIR}
    ${MSA_MIDEND_SOURCE_DIR}
    ${MSA_BACKEND_SOURCE_DIR}
    )

set (MSA_MIDEND_HDRS
  #  midend/headerMerge.h
  #  midend/compareStorageExp.h
  #  midend/deParMotionCSTRChkr.h
  #  midend/toWellFormedParser.h
  #  midend/concatDeParMerge.h
  #  midend/paraDeParMerge.h
  #  midend/alignParamNames.h
  #  midend/deParMotion.h
    midend/msaNameConstants.h
    midend/cloneWithFreshPath.h
    midend/staticAnalyzer.h
    midend/scanForHdrVOps.h
    midend/removeMSAConstructs.h
    midend/removeUnusedApplyParams.h
    midend/hdrToStructs.h
    midend/csamidend.h
    midend/msaPacketSubstituter.h
    midend/controlStateReconInfo.h
    midend/parserConverter.h
    midend/deparserConverter.h
    midend/deparserInverter.h
    midend/mergeDeclarations.h
    midend/slicePipeControl.h
    midend/identifyStorage.h
    midend/deadFieldElimination.h
    midend/toControl.h
    )

set (MSA_MIDEND_SRCS
 #   midend/headerMerge.cpp
 #   midend/compareStorageExp.cpp
 #   midend/deParMotionCSTRChkr.cpp
 #   midend/toWellFormedParser.cpp
 #   midend/concatDeParMerge.cpp
 #   midend/paraDeParMerge.cpp
 #   midend/alignParamNames.cpp
 #   midend/deParMotion.cpp
    midend/msaNameConstants.cpp
    midend/cloneWithFreshPath.cpp
    midend/staticAnalyzer.cpp
    midend/scanForHdrVOps.cpp
    midend/removeMSAConstructs.cpp
    midend/removeUnusedApplyParams.cpp
    midend/hdrToStructs.cpp
    midend/csamidend.cpp
    midend/msaPacketSubstituter.cpp
    midend/controlStateReconInfo.cpp
    midend/parserConverter.cpp
    midend/deparserConverter.cpp
    midend/deparserInverter.cpp
    midend/mergeDeclarations.cpp
    midend/slicePipeControl.cpp
    midend/identifyStorage.cpp
    midend/deadFieldElimination.cpp
    midend/toControl.cpp
    )

add_cpplint_files (${CMAKE_CURRENT_SOURCE_DIR} "${MSA_MIDEND_SRCS};${MSA_MIDEND_HDRS}")
build_unified(MSA_MIDEND_SRCS)
add_library(msamidend ${MSA_MIDEND_SRCS})
add_dependencies(msamidend genIR frontend)

set (MSA_V1MODEL_BACKEND_HDRS
    backend/v1model/v1modelConstants.h
    backend/v1model/toV1Model.h
    backend/v1model/msaV1ModelBackend.h
    )

set (MSA_V1MODEL_BACKEND_SRCS
    backend/v1model/v1modelConstants.cpp
    backend/v1model/toV1Model.cpp
    backend/v1model/msaV1ModelBackend.cpp
    )

add_cpplint_files (${CMAKE_CURRENT_SOURCE_DIR} "${MSA_V1MODEL_BACKEND_SRCS};${MSA_V1MODEL_BACKEND_HDRS}")
build_unified(MSA_V1MODEL_BACKEND_SRCS)
add_library(msav1modelbackend ${MSA_V1MODEL_BACKEND_SRCS})
add_dependencies(msav1modelbackend genIR frontend msamidend)


set (MSA_TOFINO_BACKEND_HDRS
    backend/tofino/tofinoConstants.h
    backend/tofino/replaceByteHdrStack.h
    backend/tofino/annotateFields.h
    backend/tofino/toTofino.h
    backend/tofino/msaTofinoBackend.h
    )

set (MSA_TOFINO_BACKEND_SRCS
    backend/tofino/tofinoConstants.cpp
    backend/tofino/replaceByteHdrStack.cpp
    backend/tofino/annotateFields.cpp
    backend/tofino/toTofino.cpp
    backend/tofino/msaTofinoBackend.cpp
    )

add_cpplint_files (${CMAKE_CURRENT_SOURCE_DIR} "${MSA_TOFINO_BACKEND_SRCS};${MSA_TOFINO_BACKEND_HDRS}")
build_unified(MSA_TOFINO_BACKEND_SRCS)
add_library(msatofinobackend ${MSA_TOFINO_BACKEND_SRCS})
add_dependencies(msatofinobackend genIR frontend msamidend)


# sources for backend executable
set (MSA_COMPILER_SRCS
    switch/main.cpp
    switch/msaOptions.h
    switch/parseInput.h
    switch/parseInput.cpp
    )
add_cpplint_files (${CMAKE_CURRENT_SOURCE_DIR} "${MSA_COMPILER_SRCS}")

set (P4C_MSA_EXT_HEADERS 
     ${CMAKE_CURRENT_SOURCE_DIR}/p4include/msa.up4
     ${CMAKE_CURRENT_SOURCE_DIR}/p4include/v1model.p4
    )
set (IR_DEF_FILES ${IR_DEF_FILES} ${CMAKE_CURRENT_SOURCE_DIR}/ir/csa.def PARENT_SCOPE)

build_unified(MSA_COMPILER_SRCS)
add_executable(p4c-msa ${MSA_COMPILER_SRCS})
target_link_libraries (p4c-msa msatofinobackend msav1modelbackend msamidend ${P4C_LIBRARIES} ${P4C_LIB_DEPS})


include_directories(${Boost_INCLUDE_DIRS})
include_directories(${PROTOBUF_INCLUDE_DIRS})

install(TARGETS p4c-msa RUNTIME DESTINATION ${P4C_RUNTIME_OUTPUT_DIRECTORY})
install (DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/p4include DESTINATION ${P4C_ARTIFACTS_OUTPUT_DIRECTORY})


add_custom_target(linkp4cmsa
    COMMAND ${CMAKE_COMMAND} -E create_symlink ${CMAKE_CURRENT_BINARY_DIR}/p4c-msa ${P4C_BINARY_DIR}/p4c-msa
    #    COMMAND ${CMAKE_COMMAND} -E make_directory ${P4C_BINARY_DIR}/p4include &&
    #            ${CMAKE_COMMAND} -E copy ${P4C_MSA_EXT_HEADERS} ${P4C_BINARY_DIR}/p4include
    COMMAND ${CMAKE_COMMAND} -E create_symlink ${P4C_BINARY_DIR}/p4include ${CMAKE_CURRENT_BINARY_DIR}/p4include
    )

add_dependencies(p4c_driver linkp4cmsa)
