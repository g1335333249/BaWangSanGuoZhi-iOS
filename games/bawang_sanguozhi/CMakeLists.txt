cmake_minimum_required(VERSION 3.20)
project(BawangGenerated C)
set(CMAKE_C_STANDARD 11)
set(GENERATED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/build/generated")
file(GLOB GENERATED_SOURCES CONFIGURE_DEPENDS
    "${GENERATED_DIR}/bawang_part*.c"
    "${GENERATED_DIR}/bawang_dispatch.c"
    "${GENERATED_DIR}/bawang_layout.c"
    "${GENERATED_DIR}/bawang_ram_helper.c"
    "${GENERATED_DIR}/bawang_cycles.c")
if(NOT GENERATED_SOURCES)
    message(FATAL_ERROR "Run scripts/generate.sh before configuring")
endif()
add_library(bawang_generated STATIC ${GENERATED_SOURCES})
target_include_directories(bawang_generated PRIVATE
    "${GENERATED_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/segagenesisrecomp/runner"
    "${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/segagenesisrecomp/runner/include")
