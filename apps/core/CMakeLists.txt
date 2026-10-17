cmake_minimum_required(VERSION 3.20)
project(BawangCore LANGUAGES C CXX)
set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")
set(ENGINE "${ROOT}/third_party/segagenesisrecomp")
set(RUNNER "${ENGINE}/runner")
set(GEN "${ROOT}/games/bawang_sanguozhi/build/generated")
file(GLOB GEN_SOURCES CONFIGURE_DEPENDS "${GEN}/bawang_part*.c")
list(APPEND GEN_SOURCES "${GEN}/bawang_dispatch.c" "${GEN}/bawang_layout.c"
     "${GEN}/bawang_ram_helper.c")
add_library(BawangCore STATIC
  bawang_core.c bawang_font_overlay.c bawang_storage.c "${ROOT}/apps/macos/bawang_spec.c" ${GEN_SOURCES}
  "${RUNNER}/chip_trace.c" "${RUNNER}/cmd_server_stub.c"
  "${RUNNER}/netplay/genesis_netplay_identity.c"
  "${RUNNER}/glue.c" "${RUNNER}/fiber_compat.c"
  "${RUNNER}/crash_report.c" "${RUNNER}/rb_state.c"
  "${RUNNER}/sim_step.c" "${RUNNER}/runtime_evidence.c"
  "${RUNNER}/audio/event_queue.c" "${RUNNER}/audio/ym2612_ymfm.cpp"
  "${RUNNER}/external/ymfm/src/ymfm_opn.cpp"
  "${RUNNER}/external/ymfm/src/ymfm_ssg.cpp"
  "${RUNNER}/external/ymfm/src/ymfm_adpcm.cpp"
  "${RUNNER}/external/ymfm/src/ymfm_pcm.cpp"
  "${RUNNER}/audio/sn76489.c" "${RUNNER}/audio/mixer.c"
  "${RUNNER}/audio/observability.c" "${RUNNER}/cosim_state.c"
  "${RUNNER}/audio/audio_shadow.c" "${RUNNER}/audio/fm_shadow.cpp"
  "${RUNNER}/video/color_lut.c" "${RUNNER}/m68k_interp.c"
  "${ENGINE}/recompiler/src/m68k_decoder.c"
  "${ENGINE}/recompiler/src/rom_parser.c"
  "${RUNNER}/video/genesis_vdp.c" "${RUNNER}/video/genesis_bus.c"
  "${RUNNER}/video/genesis_machine.c" "${RUNNER}/external/superzazu/z80.c")
target_include_directories(BawangCore PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}")
target_include_directories(BawangCore PRIVATE
  "${GEN}" "${RUNNER}" "${RUNNER}/include"
  "${RUNNER}/external/ymfm/src" "${RUNNER}/external/superzazu"
  "${RUNNER}/external/clowncommon" "${RUNNER}/video"
  "${ENGINE}/recompiler/src")
target_compile_definitions(BawangCore PRIVATE
  INCLUDE_GENERATED_CODE=1 ENABLE_RECOMPILED_CODE=1 OWN_BACKEND=1
  GENESIS_GAME_VERSION="0.1.0")
if(NOT CMAKE_CROSSCOMPILING)
  add_executable(BawangCoreSmoke core_smoke.c)
  target_link_libraries(BawangCoreSmoke PRIVATE BawangCore)
  add_executable(BawangStorageTest storage_test.c)
  target_link_libraries(BawangStorageTest PRIVATE BawangCore)
endif()
