#include "wayland.hpp"

#include <EGL/eglext.h>
#include <GL/gl.h>
#include <wayland-client.h>
#include <wayland-egl.h>

#define namespace wl_namespace
#include "wlr-layer-shell-unstable-v1-client-protocol.h"
#undef namespace
#include "xdg-shell-client-protocol.h"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

namespace sw {

namespace {

void reg_global(void* data, wl_registry*, uint32_t name, const char* iface, uint32_t ver) {
    static_cast<WaylandApp*>(data)->on_registry_global(name, iface, ver);
}
void reg_remove(void* data, wl_registry*, uint32_t name) {
    static_cast<WaylandApp*>(data)->on_registry_remove(name);
}
const wl_registry_listener kRegListener = {reg_global, reg_remove};

void out_geom(void* data, wl_output*, int32_t x, int32_t y, int32_t, int32_t, int32_t, const char*, const char*, int32_t) {
    auto* pair = static_cast<std::pair<WaylandApp*, OutputSurface*>*>(data);
    pair->first->on_output_geometry(pair->second, x, y);
}
void out_mode(void* data, wl_output*, uint32_t flags, int32_t w, int32_t h, int32_t) {
    auto* pair = static_cast<std::pair<WaylandApp*, OutputSurface*>*>(data);
    pair->first->on_output_mode(pair->second, flags, w, h);
}
void out_done(void* data, wl_output*) {
    auto* pair = static_cast<std::pair<WaylandApp*, OutputSurface*>*>(data);
    pair->first->on_output_done(pair->second);
}
void out_scale(void* data, wl_output*, int32_t factor) {
    auto* pair = static_cast<std::pair<WaylandApp*, OutputSurface*>*>(data);
    pair->first->on_output_scale(pair->second, factor);
}
void out_name(void* data, wl_output*, const char* name) {
    auto* pair = static_cast<std::pair<WaylandApp*, OutputSurface*>*>(data);
    pair->first->on_output_name(pair->second, name);
}
void out_desc(void*, wl_output*, const char*) {}

const wl_output_listener kOutListener = {out_geom, out_mode, out_done, out_scale, out_name, out_desc};

void layer_configure(void* data, zwlr_layer_surface_v1*, uint32_t serial, uint32_t w, uint32_t h) {
    auto* pair = static_cast<std::pair<WaylandApp*, OutputSurface*>*>(data);
    pair->first->on_layer_configure(pair->second, serial, w, h);
}
void layer_closed(void* data, zwlr_layer_surface_v1*) {
    auto* pair = static_cast<std::pair<WaylandApp*, OutputSurface*>*>(data);
    pair->first->on_layer_closed(pair->second);
}
const zwlr_layer_surface_v1_listener kLayerListener = {layer_configure, layer_closed};

void xdg_wm_ping(void*, xdg_wm_base* wm, uint32_t serial) {
    xdg_wm_base_pong(wm, serial);
}
const xdg_wm_base_listener kXdgWmListener = {xdg_wm_ping};

void xdg_surf_cfg(void* data, xdg_surface*, uint32_t serial) {
    auto* pair = static_cast<std::pair<WaylandApp*, OutputSurface*>*>(data);
    pair->first->on_xdg_configure(pair->second, serial);
}
const xdg_surface_listener kXdgSurfListener = {xdg_surf_cfg};

void xdg_top_cfg(void* data, xdg_toplevel*, int32_t w, int32_t h, wl_array*) {
    auto* pair = static_cast<std::pair<WaylandApp*, OutputSurface*>*>(data);
    pair->first->on_xdg_toplevel_configure(pair->second, w, h);
}
void xdg_top_close(void* data, xdg_toplevel*) {
    auto* pair = static_cast<std::pair<WaylandApp*, OutputSurface*>*>(data);
    pair->first->on_xdg_toplevel_close(pair->second);
}
void xdg_top_bounds(void*, xdg_toplevel*, int32_t, int32_t) {}
void xdg_top_caps(void*, xdg_toplevel*, wl_array*) {}
const xdg_toplevel_listener kXdgTopListener = {xdg_top_cfg, xdg_top_close, xdg_top_bounds, xdg_top_caps};

void seat_caps(void* data, wl_seat*, uint32_t caps) {
    static_cast<WaylandApp*>(data)->on_seat_capabilities(caps);
}
void seat_name(void*, wl_seat*, const char*) {}
const wl_seat_listener kSeatListener = {seat_caps, seat_name};

void ptr_enter(void* data, wl_pointer*, uint32_t, wl_surface* surf, wl_fixed_t sx, wl_fixed_t sy) {
    static_cast<WaylandApp*>(data)->on_pointer_enter(surf, wl_fixed_to_double(sx), wl_fixed_to_double(sy));
}
void ptr_leave(void*, wl_pointer*, uint32_t, wl_surface*) {}
void ptr_motion(void* data, wl_pointer*, uint32_t, wl_fixed_t sx, wl_fixed_t sy) {
    static_cast<WaylandApp*>(data)->on_pointer_motion(wl_fixed_to_double(sx), wl_fixed_to_double(sy));
}
void ptr_button(void*, wl_pointer*, uint32_t, uint32_t, uint32_t, uint32_t) {}
void ptr_axis(void*, wl_pointer*, uint32_t, uint32_t, wl_fixed_t) {}
void ptr_frame(void*, wl_pointer*) {}
void ptr_axis_source(void*, wl_pointer*, uint32_t) {}
void ptr_axis_stop(void*, wl_pointer*, uint32_t, uint32_t) {}
void ptr_axis_discrete(void*, wl_pointer*, uint32_t, int32_t) {}
void ptr_axis_v120(void*, wl_pointer*, uint32_t, int32_t) {}
void ptr_axis_rel_dir(void*, wl_pointer*, uint32_t, uint32_t) {}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmissing-field-initializers"
const wl_pointer_listener kPtrListener = {
    .enter = ptr_enter,
    .leave = ptr_leave,
    .motion = ptr_motion,
    .button = ptr_button,
    .axis = ptr_axis,
    .frame = ptr_frame,
    .axis_source = ptr_axis_source,
    .axis_stop = ptr_axis_stop,
    .axis_discrete = ptr_axis_discrete,
    .axis_value120 = ptr_axis_v120,
    .axis_relative_direction = ptr_axis_rel_dir,
};
#pragma GCC diagnostic pop

} // namespace

WaylandApp::~WaylandApp() {
    shutdown();
}

bool WaylandApp::init_egl(bool headless) {
    if (headless) {
        auto get_platform_dpy = reinterpret_cast<PFNEGLGETPLATFORMDISPLAYEXTPROC>(
            eglGetProcAddress("eglGetPlatformDisplayEXT"));
        if (get_platform_dpy) {
            egl_dpy_ = get_platform_dpy(EGL_PLATFORM_SURFACELESS_MESA, EGL_DEFAULT_DISPLAY, nullptr);
        }
        if (egl_dpy_ == EGL_NO_DISPLAY) {
            egl_dpy_ = eglGetDisplay(EGL_DEFAULT_DISPLAY);
        }
    } else {
        egl_dpy_ = eglGetDisplay(reinterpret_cast<EGLNativeDisplayType>(display_));
    }

    if (egl_dpy_ == EGL_NO_DISPLAY) {
        std::cerr << "[egl] eglGetDisplay failed\n";
        return false;
    }

    EGLint major = 0, minor = 0;
    if (!eglInitialize(egl_dpy_, &major, &minor)) {
        std::cerr << "[egl] eglInitialize failed\n";
        return false;
    }

    if (!eglBindAPI(EGL_OPENGL_API)) {
        std::cerr << "[egl] eglBindAPI(GL) failed\n";
        return false;
    }

    EGLint cfg_attribs[] = {
        EGL_SURFACE_TYPE, headless ? EGL_PBUFFER_BIT : EGL_WINDOW_BIT,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
        EGL_NONE
    };
    EGLint num_cfg = 0;
    if (!eglChooseConfig(egl_dpy_, cfg_attribs, &egl_cfg_, 1, &num_cfg) || num_cfg < 1) {
        std::cerr << "[egl] eglChooseConfig failed\n";
        return false;
    }

    EGLint ctx_attribs[] = {
        EGL_CONTEXT_MAJOR_VERSION, 3,
        EGL_CONTEXT_MINOR_VERSION, 3,
        EGL_CONTEXT_OPENGL_PROFILE_MASK, EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT,
        EGL_NONE
    };
    egl_ctx_ = eglCreateContext(egl_dpy_, egl_cfg_, EGL_NO_CONTEXT, ctx_attribs);
    if (egl_ctx_ == EGL_NO_CONTEXT) {
        std::cerr << "[egl] eglCreateContext(GL 3.3 Core) failed\n";
        return false;
    }
    return true;
}

bool WaylandApp::init_headless(int w, int h) {
    headless_ = true;
    if (!init_egl(true)) return false;

    auto s = std::make_unique<OutputSurface>();
    s->name = "headless";
    s->width = w;
    s->height = h;
    s->configured = true;

    EGLint pb_attribs[] = {
        EGL_WIDTH, w,
        EGL_HEIGHT, h,
        EGL_NONE
    };
    s->egl_surface = eglCreatePbufferSurface(egl_dpy_, egl_cfg_, pb_attribs);
    if (s->egl_surface == EGL_NO_SURFACE) {
        // Fallback: surfaceless context (caller renders to FBO)
        if (!eglMakeCurrent(egl_dpy_, EGL_NO_SURFACE, EGL_NO_SURFACE, egl_ctx_)) {
            std::cerr << "[egl] failed to create pbuffer or surfaceless context\n";
            return false;
        }
    } else {
        eglMakeCurrent(egl_dpy_, s->egl_surface, s->egl_surface, egl_ctx_);
    }
    surfaces_.push_back(std::move(s));
    return true;
}

bool WaylandApp::init(bool windowed, const std::string& target_output, int win_w, int win_h) {
    windowed_ = windowed;
    target_output_ = target_output;

    if (const char* sig = std::getenv("HYPRLAND_INSTANCE_SIGNATURE")) {
        const char* rt = std::getenv("XDG_RUNTIME_DIR");
        if (rt && sig[0]) {
            hypr_sock_path_ = std::string(rt) + "/hypr/" + sig + "/.socket.sock";
        }
    }

    display_ = wl_display_connect(nullptr);
    if (!display_) {
        std::cerr << "[wayland] failed to connect to Wayland display\n";
        return false;
    }

    registry_ = wl_display_get_registry(display_);
    wl_registry_add_listener(registry_, &kRegListener, this);
    wl_display_roundtrip(display_);
    wl_display_roundtrip(display_); // second roundtrip for wl_output::name & mode

    if (!compositor_) {
        std::cerr << "[wayland] missing wl_compositor\n";
        return false;
    }
    if (!windowed_ && !layer_shell_) {
        std::cerr << "[wayland] compositor does not support zwlr_layer_shell_v1\n";
        return false;
    }
    if (windowed_ && !xdg_wm_) {
        std::cerr << "[wayland] compositor does not support xdg_wm_base\n";
        return false;
    }

    if (!init_egl(false)) return false;

    if (windowed_) {
        create_window_surface(win_w, win_h);
    } else {
        for (auto& s : surfaces_) {
            if (target_output_.empty() || s->name == target_output_) {
                create_layer_surface(*s);
            }
        }
    }

    wl_display_roundtrip(display_);

    // Make context current on first configured surface so OpenGL calls work during scene load
    for (auto& s : surfaces_) {
        if (s->egl_surface != EGL_NO_SURFACE) {
            make_current(*s);
            break;
        }
    }
    return true;
}

void WaylandApp::shutdown() {
    for (auto& s : surfaces_) {
        destroy_output_surface(*s);
        if (s->output) wl_output_destroy(s->output);
    }
    surfaces_.clear();

    if (egl_dpy_ != EGL_NO_DISPLAY) {
        eglMakeCurrent(egl_dpy_, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        if (egl_ctx_ != EGL_NO_CONTEXT) eglDestroyContext(egl_dpy_, egl_ctx_);
        eglTerminate(egl_dpy_);
        egl_ctx_ = EGL_NO_CONTEXT;
        egl_dpy_ = EGL_NO_DISPLAY;
    }

    if (pointer_) { wl_pointer_destroy(pointer_); pointer_ = nullptr; }
    if (seat_) { wl_seat_destroy(seat_); seat_ = nullptr; }
    if (xdg_wm_) { xdg_wm_base_destroy(xdg_wm_); xdg_wm_ = nullptr; }
    if (layer_shell_) { zwlr_layer_shell_v1_destroy(layer_shell_); layer_shell_ = nullptr; }
    if (compositor_) { wl_compositor_destroy(compositor_); compositor_ = nullptr; }
    if (registry_) { wl_registry_destroy(registry_); registry_ = nullptr; }
    if (display_) { wl_display_disconnect(display_); display_ = nullptr; }
}

void WaylandApp::on_registry_global(uint32_t name, const char* iface, uint32_t ver) {
    if (std::strcmp(iface, wl_compositor_interface.name) == 0) {
        compositor_ = static_cast<wl_compositor*>(
            wl_registry_bind(registry_, name, &wl_compositor_interface, std::min(ver, 4u)));
    } else if (std::strcmp(iface, zwlr_layer_shell_v1_interface.name) == 0) {
        layer_shell_ = static_cast<zwlr_layer_shell_v1*>(
            wl_registry_bind(registry_, name, &zwlr_layer_shell_v1_interface, std::min(ver, 4u)));
    } else if (std::strcmp(iface, xdg_wm_base_interface.name) == 0) {
        xdg_wm_ = static_cast<xdg_wm_base*>(
            wl_registry_bind(registry_, name, &xdg_wm_base_interface, std::min(ver, 2u)));
        xdg_wm_base_add_listener(xdg_wm_, &kXdgWmListener, this);
    } else if (std::strcmp(iface, wl_seat_interface.name) == 0) {
        seat_ = static_cast<wl_seat*>(
            wl_registry_bind(registry_, name, &wl_seat_interface, std::min(ver, 5u)));
        wl_seat_add_listener(seat_, &kSeatListener, this);
    } else if (std::strcmp(iface, wl_output_interface.name) == 0 && !windowed_) {
        auto s = std::make_unique<OutputSurface>();
        s->wl_name = name;
        s->output = static_cast<wl_output*>(
            wl_registry_bind(registry_, name, &wl_output_interface, std::min(ver, 4u)));
        auto* pair = new std::pair<WaylandApp*, OutputSurface*>(this, s.get());
        wl_output_add_listener(s->output, &kOutListener, pair);
        surfaces_.push_back(std::move(s));
    }
}

void WaylandApp::on_registry_remove(uint32_t name) {
    for (auto it = surfaces_.begin(); it != surfaces_.end(); ++it) {
        if ((*it)->wl_name == name) {
            destroy_output_surface(**it);
            if ((*it)->output) wl_output_destroy((*it)->output);
            surfaces_.erase(it);
            break;
        }
    }
}

void WaylandApp::on_output_geometry(OutputSurface* s, int32_t x, int32_t y) {
    s->x = x;
    s->y = y;
}

void WaylandApp::on_output_mode(OutputSurface* s, uint32_t flags, int32_t w, int32_t h) {
    if (flags & WL_OUTPUT_MODE_CURRENT) {
        if (s->logical_w == 0) { s->logical_w = w; s->logical_h = h; }
    }
}

void WaylandApp::on_output_scale(OutputSurface* s, int32_t factor) {
    s->scale = std::max(1, factor);
    if (s->surface) {
        wl_surface_set_buffer_scale(s->surface, s->scale);
        if (s->egl_win && s->logical_w > 0 && s->logical_h > 0) {
            s->width = s->logical_w * s->scale;
            s->height = s->logical_h * s->scale;
            wl_egl_window_resize(s->egl_win, s->width, s->height, 0, 0);
        }
    }
}

void WaylandApp::on_output_name(OutputSurface* s, const char* name) {
    if (name) s->name = name;
}

void WaylandApp::on_output_done(OutputSurface* s) {
    if (!windowed_ && egl_ctx_ != EGL_NO_CONTEXT && !s->surface) {
        if (target_output_.empty() || s->name == target_output_) {
            create_layer_surface(*s);
        }
    }
}

void WaylandApp::create_layer_surface(OutputSurface& s) {
    if (s.surface) return;
    s.surface = wl_compositor_create_surface(compositor_);
    wl_surface_set_buffer_scale(s.surface, s.scale);

    // Empty input region so desktop clicks & SomeShell widgets above us are never blocked
    wl_region* empty_reg = wl_compositor_create_region(compositor_);
    wl_surface_set_input_region(s.surface, empty_reg);
    wl_region_destroy(empty_reg);

    s.layer_surface = zwlr_layer_shell_v1_get_layer_surface(
        layer_shell_, s.surface, s.output,
        ZWLR_LAYER_SHELL_V1_LAYER_BACKGROUND, "somewall");

    zwlr_layer_surface_v1_set_anchor(
        s.layer_surface,
        ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP | ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
        ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT | ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);
    zwlr_layer_surface_v1_set_exclusive_zone(s.layer_surface, -1);
    zwlr_layer_surface_v1_set_keyboard_interactivity(
        s.layer_surface, ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_NONE);

    auto* pair = new std::pair<WaylandApp*, OutputSurface*>(this, &s);
    zwlr_layer_surface_v1_add_listener(s.layer_surface, &kLayerListener, pair);
    wl_surface_commit(s.surface);
}

void WaylandApp::create_window_surface(int w, int h) {
    auto s = std::make_unique<OutputSurface>();
    s->name = "window";
    s->logical_w = w;
    s->logical_h = h;
    s->width = w;
    s->height = h;
    s->surface = wl_compositor_create_surface(compositor_);
    s->xdg_surf = xdg_wm_base_get_xdg_surface(xdg_wm_, s->surface);
    auto* pair = new std::pair<WaylandApp*, OutputSurface*>(this, s.get());
    xdg_surface_add_listener(s->xdg_surf, &kXdgSurfListener, pair);
    s->xdg_top = xdg_surface_get_toplevel(s->xdg_surf);
    xdg_toplevel_add_listener(s->xdg_top, &kXdgTopListener, pair);
    xdg_toplevel_set_title(s->xdg_top, "somewall preview");
    wl_surface_commit(s->surface);

    s->egl_win = wl_egl_window_create(s->surface, w, h);
    s->egl_surface = eglCreateWindowSurface(egl_dpy_, egl_cfg_,
                                            reinterpret_cast<EGLNativeWindowType>(s->egl_win), nullptr);
    surfaces_.push_back(std::move(s));
}

void WaylandApp::destroy_output_surface(OutputSurface& s) {
    if (s.egl_surface != EGL_NO_SURFACE && egl_dpy_ != EGL_NO_DISPLAY) {
        eglDestroySurface(egl_dpy_, s.egl_surface);
        s.egl_surface = EGL_NO_SURFACE;
    }
    if (s.egl_win) { wl_egl_window_destroy(s.egl_win); s.egl_win = nullptr; }
    if (s.xdg_top) { xdg_toplevel_destroy(s.xdg_top); s.xdg_top = nullptr; }
    if (s.xdg_surf) { xdg_surface_destroy(s.xdg_surf); s.xdg_surf = nullptr; }
    if (s.layer_surface) { zwlr_layer_surface_v1_destroy(s.layer_surface); s.layer_surface = nullptr; }
    if (s.surface) { wl_surface_destroy(s.surface); s.surface = nullptr; }
}

void WaylandApp::on_layer_configure(OutputSurface* s, uint32_t serial, uint32_t w, uint32_t h) {
    zwlr_layer_surface_v1_ack_configure(s->layer_surface, serial);
    if (w > 0 && h > 0) {
        s->logical_w = static_cast<int32_t>(w);
        s->logical_h = static_cast<int32_t>(h);
    }
    int px_w = std::max(1, s->logical_w * s->scale);
    int px_h = std::max(1, s->logical_h * s->scale);
    s->width = px_w;
    s->height = px_h;

    if (!s->egl_win) {
        s->egl_win = wl_egl_window_create(s->surface, px_w, px_h);
        s->egl_surface = eglCreateWindowSurface(egl_dpy_, egl_cfg_,
                                                reinterpret_cast<EGLNativeWindowType>(s->egl_win), nullptr);
    } else {
        wl_egl_window_resize(s->egl_win, px_w, px_h, 0, 0);
    }
    s->configured = true;
    std::cerr << "[wayland] configured layer on " << (s->name.empty() ? "output" : s->name)
              << " (" << px_w << "x" << px_h << ", scale=" << s->scale << ")\n";
}

void WaylandApp::on_layer_closed(OutputSurface* s) {
    s->closed = true;
}

void WaylandApp::on_xdg_configure(OutputSurface* s, uint32_t serial) {
    xdg_surface_ack_configure(s->xdg_surf, serial);
    s->configured = true;
}

void WaylandApp::on_xdg_toplevel_configure(OutputSurface* s, int32_t w, int32_t h) {
    if (w > 0 && h > 0 && (w != s->width || h != s->height)) {
        s->logical_w = w;
        s->logical_h = h;
        s->width = w;
        s->height = h;
        if (s->egl_win) wl_egl_window_resize(s->egl_win, w, h, 0, 0);
    }
}

void WaylandApp::on_xdg_toplevel_close(OutputSurface* s) {
    s->closed = true;
    quit_ = true;
}

void WaylandApp::on_seat_capabilities(uint32_t caps) {
    if ((caps & WL_SEAT_CAPABILITY_POINTER) && !pointer_) {
        pointer_ = wl_seat_get_pointer(seat_);
        wl_pointer_add_listener(pointer_, &kPtrListener, this);
    }
}

void WaylandApp::on_pointer_enter(wl_surface* surf, double sx, double sy) {
    pointer_surf_ = nullptr;
    for (auto& s : surfaces_) {
        if (s->surface == surf) { pointer_surf_ = s.get(); break; }
    }
    has_wl_pointer_ = true;
    on_pointer_motion(sx, sy);
}

void WaylandApp::on_pointer_motion(double sx, double sy) {
    if (pointer_surf_ && pointer_surf_->logical_w > 0 && pointer_surf_->logical_h > 0) {
        ptr_norm_x_ = static_cast<float>(sx / pointer_surf_->logical_w);
        ptr_norm_y_ = static_cast<float>(sy / pointer_surf_->logical_h);
    }
}

int WaylandApp::wl_fd() const {
    return display_ ? wl_display_get_fd(display_) : -1;
}

bool WaylandApp::poll_events(bool fd_readable) {
    if (!display_) return !quit_;
    while (wl_display_prepare_read(display_) != 0) {
        if (wl_display_dispatch_pending(display_) < 0) {
            quit_ = true;
            return false;
        }
    }
    wl_display_flush(display_);
    if (fd_readable) {
        if (wl_display_read_events(display_) < 0) {
            quit_ = true;
            return false;
        }
    } else {
        wl_display_cancel_read(display_);
    }
    if (wl_display_dispatch_pending(display_) < 0) {
        quit_ = true;
        return false;
    }
    return !quit_;
}

bool WaylandApp::make_current(OutputSurface& surf) {
    if (egl_dpy_ == EGL_NO_DISPLAY || egl_ctx_ == EGL_NO_CONTEXT) return false;
    if (surf.egl_surface == EGL_NO_SURFACE && !headless_) return false;
    bool ok = eglMakeCurrent(egl_dpy_, surf.egl_surface, surf.egl_surface, egl_ctx_) == EGL_TRUE;
    if (ok && !headless_) {
        eglSwapInterval(egl_dpy_, 0); // We pace our own target FPS cleanly
    }
    return ok;
}

void WaylandApp::swap_buffers(OutputSurface& surf) {
    if (headless_ || surf.egl_surface == EGL_NO_SURFACE) return;
    eglSwapBuffers(egl_dpy_, surf.egl_surface);
}

bool WaylandApp::query_hypr_cursor(float& out_norm_x, float& out_norm_y) {
    if (hypr_sock_path_.empty() || surfaces_.empty()) return false;

    int fd = ::socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return false;

    sockaddr_un addr{};
    addr.sun_family = AF_UNIX;
    if (hypr_sock_path_.size() >= sizeof(addr.sun_path)) {
        ::close(fd);
        return false;
    }
    std::strncpy(addr.sun_path, hypr_sock_path_.c_str(), sizeof(addr.sun_path) - 1);

    if (::connect(fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
        ::close(fd);
        return false;
    }

    const char cmd[] = "cursorpos";
    ssize_t wr = ::write(fd, cmd, sizeof(cmd) - 1);
    if (wr < 0) {
        ::close(fd);
        return false;
    }

    char buf[128] = {};
    ssize_t rd = ::read(fd, buf, sizeof(buf) - 1);
    ::close(fd);
    if (rd <= 0) return false;

    int cx = 0, cy = 0;
    if (std::sscanf(buf, "%d, %d", &cx, &cy) != 2) return false;

    // Map global cursor to the monitor it is on (or first monitor)
    const OutputSurface* chosen = surfaces_[0].get();
    for (const auto& s : surfaces_) {
        if (s->logical_w > 0 && s->logical_h > 0 &&
            cx >= s->x && cx < s->x + s->logical_w &&
            cy >= s->y && cy < s->y + s->logical_h) {
            chosen = s.get();
            break;
        }
    }
    if (chosen && chosen->logical_w > 0 && chosen->logical_h > 0) {
        out_norm_x = std::clamp(static_cast<float>(cx - chosen->x) / chosen->logical_w, 0.0f, 1.0f);
        out_norm_y = std::clamp(static_cast<float>(cy - chosen->y) / chosen->logical_h, 0.0f, 1.0f);
        return true;
    }
    return false;
}

} // namespace sw
