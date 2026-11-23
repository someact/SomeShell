cmake_minimum_required(VERSION 3.20)
project(somewall LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(PkgConfig REQUIRED)
pkg_check_modules(WL_CLIENT REQUIRED wayland-client)
pkg_check_modules(WL_EGL REQUIRED wayland-egl)
pkg_check_modules(EGL REQUIRED egl)
pkg_check_modules(GL REQUIRED gl)
pkg_check_modules(LZ4 REQUIRED liblz4)
pkg_check_modules(AVFORMAT REQUIRED libavformat)
pkg_check_modules(AVCODEC REQUIRED libavcodec)
pkg_check_modules(AVUTIL REQUIRED libavutil)
pkg_check_modules(SWSCALE REQUIRED libswscale)
pkg_check_modules(FREETYPE REQUIRED freetype2)
pkg_check_modules(FONTCONFIG REQUIRED fontconfig)
pkg_check_modules(DUKTAPE REQUIRED duktape)

find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)

set(PROTO_GEN_DIR "${CMAKE_BINARY_DIR}/protocols")
file(MAKE_DIRECTORY "${PROTO_GEN_DIR}")

function(gen_wayland_proto XML_FILE NAME)
    set(HDR "${PROTO_GEN_DIR}/${NAME}-client-protocol.h")
    set(SRC "${PROTO_GEN_DIR}/${NAME}-protocol.c")
    add_custom_command(
        OUTPUT "${HDR}"
        COMMAND "${WAYLAND_SCANNER}" client-header "${XML_FILE}" "${HDR}"
        DEPENDS "${XML_FILE}"
        COMMENT "Generating Wayland client header for ${NAME}"
    )
    add_custom_command(
        OUTPUT "${SRC}"
        COMMAND "${WAYLAND_SCANNER}" private-code "${XML_FILE}" "${SRC}"
        DEPENDS "${XML_FILE}"
        COMMENT "Generating Wayland private code for ${NAME}"
    )
    set(PROTO_SRCS ${PROTO_SRCS} "${SRC}" "${HDR}" PARENT_SCOPE)
endfunction()

gen_wayland_proto("/usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml" "xdg-shell")
gen_wayland_proto("${CMAKE_SOURCE_DIR}/protocols/wlr-layer-shell-unstable-v1.xml" "wlr-layer-shell-unstable-v1")

add_executable(somewall
    src/main.cpp
    src/json.cpp
    src/vfs.cpp
    src/video.cpp
    src/tex.cpp
    src/shader.cpp
    src/script.cpp
    src/text.cpp
    src/particles.cpp
    src/scene.cpp
    src/wayland.cpp
    ${PROTO_SRCS}
)

target_include_directories(somewall PRIVATE
    "${CMAKE_SOURCE_DIR}/src"
    "${PROTO_GEN_DIR}"
    ${WL_CLIENT_INCLUDE_DIRS}
    ${WL_EGL_INCLUDE_DIRS}
    ${EGL_INCLUDE_DIRS}
    ${GL_INCLUDE_DIRS}
    ${LZ4_INCLUDE_DIRS}
    ${AVFORMAT_INCLUDE_DIRS}
    ${AVCODEC_INCLUDE_DIRS}
    ${AVUTIL_INCLUDE_DIRS}
    ${SWSCALE_INCLUDE_DIRS}
    ${FREETYPE_INCLUDE_DIRS}
    ${FONTCONFIG_INCLUDE_DIRS}
    ${DUKTAPE_INCLUDE_DIRS}
)

target_compile_definitions(somewall PRIVATE GL_GLEXT_PROTOTYPES)

target_compile_options(somewall PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:-Wall -Wextra -Wno-unused-parameter -O2>
    $<$<COMPILE_LANGUAGE:C>:-O2>
)

target_link_libraries(somewall PRIVATE
    ${WL_CLIENT_LIBRARIES}
    ${WL_EGL_LIBRARIES}
    ${EGL_LIBRARIES}
    ${GL_LIBRARIES}
    ${LZ4_LIBRARIES}
    ${AVFORMAT_LIBRARIES}
    ${AVCODEC_LIBRARIES}
    ${AVUTIL_LIBRARIES}
    ${SWSCALE_LIBRARIES}
    ${FREETYPE_LIBRARIES}
    ${FONTCONFIG_LIBRARIES}
    ${DUKTAPE_LIBRARIES}
    pthread
    dl
    m
)
