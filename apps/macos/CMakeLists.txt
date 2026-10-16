cmake_minimum_required(VERSION 3.20)
project(BawangMac LANGUAGES C CXX)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")
set(ENGINE "${ROOT}/third_party/segagenesisrecomp")
set(RUNNER "${ENGINE}/runner")
set(GEN "${ROOT}/games/bawang_sanguozhi/build/generated")
find_package(SDL2 REQUIRED)
set(RBE_BUILD_TESTS OFF CACHE BOOL "" FORCE)
add_subdirectory("${ENGINE}/external/rbengine" "${CMAKE_CURRENT_BINARY_DIR}/rbengine")
file(GLOB GEN_SOURCES CONFIGURE_DEPENDS "${GEN}/bawang_part*.c")
list(APPEND GEN_SOURCES "${GEN}/bawang_dispatch.c" "${GEN}/bawang_layout.c"
  "${GEN}/bawang_ram_helper.c")
set(BAWANG_SOURCES
  bawang_spec.c ${GEN_SOURCES}
  "${RUNNER}/main.c" "${RUNNER}/audio.c" "${RUNNER}/chip_trace.c"
  "${RUNNER}/cmd_server_stub.c" "${RUNNER}/glue.c"
  "${RUNNER}/fiber_compat.c" "${RUNNER}/crash_report.c"
  "${RUNNER}/input_script.c" "${RUNNER}/gamepad.c"
  "${RUNNER}/input_map.c" "${RUNNER}/app_config.c"
  "${RUNNER}/local_states.c" "${RUNNER}/overlay_draw.c"
  "${RUNNER}/rb_state.c" "${RUNNER}/rb_probe.c"
  "${RUNNER}/sim_step.c" "${RUNNER}/runtime_evidence.c"
  "${RUNNER}/audio/event_queue.c"
  "${RUNNER}/audio/ym2612_ymfm.cpp"
  "${RUNNER}/external/ymfm/src/ymfm_opn.cpp"
  "${RUNNER}/external/ymfm/src/ymfm_ssg.cpp"
  "${RUNNER}/external/ymfm/src/ymfm_adpcm.cpp"
  "${RUNNER}/external/ymfm/src/ymfm_pcm.cpp"
  "${RUNNER}/audio/sn76489.c" "${RUNNER}/audio/mixer.c"
  "${RUNNER}/audio/observability.c" "${RUNNER}/cosim_state.c"
  "${RUNNER}/audio/audio_shadow.c" "${RUNNER}/audio/fm_shadow.cpp"
  "${RUNNER}/video/color_lut.c"
  "${RUNNER}/m68k_interp.c"
  "${ENGINE}/recompiler/src/m68k_decoder.c"
  "${ENGINE}/recompiler/src/rom_parser.c"
  "${RUNNER}/video/genesis_vdp.c"
  "${RUNNER}/video/genesis_bus.c"
  "${RUNNER}/video/genesis_machine.c"
  "${RUNNER}/external/superzazu/z80.c")
set(BAWANG_INCLUDES
  "${GEN}" "${RUNNER}" "${RUNNER}/include"
  "${RUNNER}/external/ymfm/src" "${RUNNER}/external/superzazu"
  "${RUNNER}/external/clowncommon" "${RUNNER}/video"
  "${ENGINE}/recompiler/src" "${SDL2_INCLUDE_DIRS}")
set(BAWANG_DEFINES
  INCLUDE_GENERATED_CODE=1 ENABLE_RECOMPILED_CODE=1 OWN_BACKEND=1
  GENESIS_GAME_VERSION="0.1.0")

add_executable(BawangMac ${BAWANG_SOURCES})
target_include_directories(BawangMac PRIVATE ${BAWANG_INCLUDES})
target_compile_definitions(BawangMac PRIVATE ${BAWANG_DEFINES})
target_link_libraries(BawangMac PRIVATE SDL2::SDL2main SDL2::SDL2 retcomm_rbengine)

option(BAWANG_BUILD_COSIM "Build diagnostic native/interpreter differential runner" OFF)
if(BAWANG_BUILD_COSIM)
  add_executable(BawangMac_cosim ${BAWANG_SOURCES}
    "${RUNNER}/cosim.c" "${RUNNER}/cosim_visible.c"
    "${RUNNER}/frame_snapshots.c"
    "${RUNNER}/cosim_cycles.c" "${RUNNER}/game_cycles.c"
    "${GEN}/bawang_cycles.c")
  target_include_directories(BawangMac_cosim PRIVATE ${BAWANG_INCLUDES})
  target_compile_definitions(BawangMac_cosim PRIVATE ${BAWANG_DEFINES} GENESIS_COSIM=1)
  target_link_libraries(BawangMac_cosim PRIVATE SDL2::SDL2main SDL2::SDL2 retcomm_rbengine)
endif()
