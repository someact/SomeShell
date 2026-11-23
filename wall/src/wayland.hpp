#pragma once

#include <EGL/egl.h>
#include <functional>
#include <memory>
#include <string>
#include <vector>

struct wl_display;
struct wl_registry;
struct wl_compositor;
struct wl_seat;
struct wl_pointer;
struct wl_output;
struct wl_surface;
struct wl_egl_window;
struct zwlr_layer_shell_v1;
struct zwlr_layer_surface_v1;
struct xdg_wm_base;
struct xdg_surface;
struct xdg_toplevel;
struct wp_viewporter;
struct wp_viewport;

namespace sw {

struct OutputSurface {
    uint32_t wl_name = 0;
    wl_output* output = nullptr;
    std::string name;
    int32_t x = 0;
    int32_t y = 0;
    int32_t logical_w = 0;
    int32_t logical_h = 0;
    int32_t scale = 1;

    wl_surface* surface = nullptr;
    zwlr_layer_surface_v1* layer_surface = nullptr;
    xdg_surface* xdg_surf = nullptr;
    xdg_toplevel* xdg_top = nullptr;
    wp_viewport* viewport = nullptr;
    wl_egl_window* egl_win = nullptr;
    EGLSurface egl_surface = EGL_NO_SURFACE;

    int width = 0;
    int height = 0;
    bool configured = false;
    bool closed = false;
    bool paused = false;
    // Must be drawn again (new size, just configured) even if nothing moved
    bool dirty = true;
};

class WaylandApp {
public:
    WaylandApp() = default;
    ~WaylandApp();

    WaylandApp(const WaylandApp&) = delete;
    WaylandApp& operator=(const WaylandApp&) = delete;

    bool init(bool windowed, const std::string& target_output, int win_w = 1280, int win_h = 720);
    bool init_headless(int w, int h);
    void shutdown();

    bool poll_events(bool fd_readable = false);
    int wl_fd() const;

    // Draw at a fraction of the screen's pixels (0.25..1); the compositor
    // stretches the picture (wp_viewporter). Without viewporter: always 1.
    void set_render_scale(float scale);
    float render_scale() const { return render_scale_; }

    bool make_current(OutputSurface& surf);
    void swap_buffers(OutputSurface& surf);

    // Optional: query Hyprland cursorpos over Unix domain socket (zero fork)
    bool query_hypr_cursor(float& out_norm_x, float& out_norm_y);

    std::vector<std::unique_ptr<OutputSurface>>& surfaces() { return surfaces_; }
    bool should_quit() const { return quit_; }
    void request_quit() { quit_ = true; }

    float pointer_x() const { return ptr_norm_x_; }
    float pointer_y() const { return ptr_norm_y_; }
    bool has_pointer() const { return has_wl_pointer_; }

    // Internal callbacks
    void on_registry_global(uint32_t name, const char* interface, uint32_t version);
    void on_registry_remove(uint32_t name);
    void on_output_geometry(OutputSurface* s, int32_t x, int32_t y);
    void on_output_mode(OutputSurface* s, uint32_t flags, int32_t w, int32_t h);
    void on_output_scale(OutputSurface* s, int32_t factor);
    void on_output_name(OutputSurface* s, const char* name);
    void on_output_done(OutputSurface* s);
    void on_layer_configure(OutputSurface* s, uint32_t serial, uint32_t w, uint32_t h);
    void on_layer_closed(OutputSurface* s);
    void on_xdg_configure(OutputSurface* s, uint32_t serial);
    void on_xdg_toplevel_configure(OutputSurface* s, int32_t w, int32_t h);
    void on_xdg_toplevel_close(OutputSurface* s);
    void on_seat_capabilities(uint32_t caps);
    void on_pointer_enter(wl_surface* surf, double sx, double sy);
    void on_pointer_motion(double sx, double sy);

private:
    bool init_egl(bool headless);
    void create_layer_surface(OutputSurface& s);
    void create_window_surface(int w, int h);
    void destroy_output_surface(OutputSurface& s);
    void apply_size(OutputSurface& s);

    bool windowed_ = false;
    bool headless_ = false;
    std::string target_output_;
    bool quit_ = false;

    wl_display* display_ = nullptr;
    wl_registry* registry_ = nullptr;
    wl_compositor* compositor_ = nullptr;
    wl_seat* seat_ = nullptr;
    wl_pointer* pointer_ = nullptr;
    zwlr_layer_shell_v1* layer_shell_ = nullptr;
    xdg_wm_base* xdg_wm_ = nullptr;
    wp_viewporter* viewporter_ = nullptr;
    float render_scale_ = 1.0f;

    EGLDisplay egl_dpy_ = EGL_NO_DISPLAY;
    EGLContext egl_ctx_ = EGL_NO_CONTEXT;
    EGLConfig egl_cfg_ = nullptr;

    std::vector<std::unique_ptr<OutputSurface>> surfaces_;
    OutputSurface* pointer_surf_ = nullptr;
    float ptr_norm_x_ = 0.5f;
    float ptr_norm_y_ = 0.5f;
    bool has_wl_pointer_ = false;

    std::string hypr_sock_path_;
};

} // namespace sw
