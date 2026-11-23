#include "json.hpp"
#include "scene.hpp"
#include "video.hpp"
#include "wayland.hpp"

#include <GL/glext.h>
#include <chrono>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <poll.h>
#include <string>
#include <thread>
#include <unistd.h>
#include <wayland-client.h>

namespace fs = std::filesystem;

namespace {

volatile sig_atomic_t g_stop = 0;
void handle_sig(int) { g_stop = 1; }

void print_usage(const char* argv0) {
    std::cerr << "Usage: " << argv0 << " [options] <wallpaper-dir-or-file>\n"
              << "Options:\n"
              << "  --assets <dir>       Wallpaper Engine assets/ directory\n"
              << "  --output <name>      Target a single Wayland output (e.g. DP-1)\n"
              << "  --fps <n>            Frame rate cap for scenes (default: 60; videos play at their own rate)\n"
              << "  --scale <f>          Render scale 0.25..1 (the compositor stretches the picture)\n"
              << "  --hwdec <name>       Video decoding: auto (default), none, cuda, vaapi, vulkan, v4l2m2m\n"
              << "  --windowed [WxH]     Run in an xdg-shell preview window\n"
              << "  --prop <k=v>         Override a Wallpaper Engine user property (repeatable)\n"
              << "  --no-hypr-cursor     Disable Hyprland IPC cursor tracking\n"
              << "  --stdin-ipc          Read JSON-line control commands from stdin\n"
              << "  --headless-shot <p>  Render offscreen and save a PPM screenshot, then exit\n"
              << "  --size <WxH>         Size for --headless-shot or --windowed (default: 1280x720)\n"
              << "  --frames <n>         Number of frames to simulate before --headless-shot (default: 30)\n";
}

fs::path find_default_assets(const char* argv0) {
    if (const char* env = std::getenv("SOMEWALL_ASSETS"); env && fs::is_directory(env)) {
        return env;
    }
    // The shell passes --assets from shell.json; without it, the usual Steam
    // installs (native, ~/.steam link, Flatpak)
    if (const char* home = std::getenv("HOME")) {
        fs::path h(home);
        for (const auto& cand : {
                 h / ".local/share/Steam/steamapps/common/wallpaper_engine/assets",
                 h / ".steam/steam/steamapps/common/wallpaper_engine/assets",
                 h / ".var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/wallpaper_engine/assets",
             }) {
            std::error_code ec;
            if (fs::is_directory(cand, ec)) return cand;
        }
    }
    (void)argv0;
    return {};
}

sw::Json parse_prop_value(const std::string& val) {
    if (val == "true") return sw::Json(true);
    if (val == "false") return sw::Json(false);
    // Try number if pure numeric
    char* endp = nullptr;
    double d = std::strtod(val.c_str(), &endp);
    if (endp && *endp == '\0' && !val.empty()) return sw::Json(d);
    return sw::Json(val);
}

bool save_ppm(const std::string& path, int w, int h) {
    std::vector<uint8_t> rgba(static_cast<size_t>(w) * h * 4);
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, rgba.data());

    std::ofstream f(path, std::ios::binary);
    if (!f) return false;
    f << "P6\n" << w << " " << h << "\n255\n";
    std::vector<uint8_t> row(static_cast<size_t>(w) * 3);
    for (int y = h - 1; y >= 0; --y) {
        const uint8_t* src = rgba.data() + static_cast<size_t>(y) * w * 4;
        for (int x = 0; x < w; ++x) {
            row[x * 3 + 0] = src[x * 4 + 0];
            row[x * 3 + 1] = src[x * 4 + 1];
            row[x * 3 + 2] = src[x * 4 + 2];
        }
        f.write(reinterpret_cast<const char*>(row.data()), static_cast<std::streamsize>(row.size()));
    }
    return true;
}

} // namespace

int main(int argc, char** argv) {
    std::signal(SIGINT, handle_sig);
    std::signal(SIGTERM, handle_sig);
    std::signal(SIGPIPE, SIG_IGN);

    std::string wallpaper_path;
    fs::path assets_dir;
    std::string target_output;
    int target_fps = 60;
    bool windowed = false;
    bool use_hypr_cursor = true;
    bool stdin_ipc = false;
    std::string headless_shot;
    int win_w = 1280, win_h = 720;
    int shot_frames = 30;
    std::vector<std::pair<std::string, sw::Json>> prop_overrides;
    float render_scale = 1.0f;
    std::string hwdec = std::getenv("SOMEWALL_HWDEC") ? std::getenv("SOMEWALL_HWDEC") : "auto";

    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        if (a == "-h" || a == "--help") {
            print_usage(argv[0]);
            return 0;
        } else if (a == "--assets" && i + 1 < argc) {
            assets_dir = argv[++i];
        } else if (a == "--output" && i + 1 < argc) {
            target_output = argv[++i];
        } else if (a == "--fps" && i + 1 < argc) {
            target_fps = std::clamp(std::atoi(argv[++i]), 1, 240);
        } else if (a == "--scale" && i + 1 < argc) {
            render_scale = static_cast<float>(std::atof(argv[++i]));
        } else if (a == "--hwdec" && i + 1 < argc) {
            hwdec = argv[++i];
        } else if (a == "--windowed") {
            windowed = true;
        } else if (a == "--size" && i + 1 < argc) {
            std::sscanf(argv[++i], "%dx%d", &win_w, &win_h);
        } else if (a == "--no-hypr-cursor") {
            use_hypr_cursor = false;
        } else if (a == "--stdin-ipc") {
            stdin_ipc = true;
        } else if (a == "--headless-shot" && i + 1 < argc) {
            headless_shot = argv[++i];
        } else if (a == "--frames" && i + 1 < argc) {
            shot_frames = std::max(1, std::atoi(argv[++i]));
        } else if (a == "--prop" && i + 1 < argc) {
            std::string kv = argv[++i];
            size_t eq = kv.find('=');
            if (eq != std::string::npos) {
                prop_overrides.emplace_back(kv.substr(0, eq), parse_prop_value(kv.substr(eq + 1)));
            }
        } else if (!a.empty() && a[0] != '-') {
            wallpaper_path = a;
        }
    }

    if (wallpaper_path.empty() && !stdin_ipc) {
        print_usage(argv[0]);
        return 1;
    }

    if (assets_dir.empty()) {
        assets_dir = find_default_assets(argv[0]);
    }
    if (!assets_dir.empty()) {
        std::cerr << "[somewall] assets dir: " << assets_dir << "\n";
    } else {
        std::cerr << "[somewall] warning: no Wallpaper Engine assets/ dir found (pass --assets)\n";
    }

    sw::WaylandApp app;
    if (!headless_shot.empty()) {
        if (!app.init_headless(win_w, win_h)) return 1;
    } else {
        if (!app.init(windowed, target_output, win_w, win_h)) return 1;
    }

    {
        const char* vendor = reinterpret_cast<const char*>(glGetString(GL_VENDOR));
        sw::set_hwdec_preference(hwdec, vendor ? vendor : "");
        if (vendor) std::cerr << "[somewall] GL vendor: " << vendor << ", video decoding: " << hwdec << "\n";
    }
    if (headless_shot.empty()) app.set_render_scale(render_scale);

    sw::Scene scene;
    scene.set_assets_dir(assets_dir);

    if (!wallpaper_path.empty()) {
        if (!scene.load(wallpaper_path)) {
            std::cerr << "[somewall] failed to load wallpaper: " << wallpaper_path << "\n";
            return 1;
        }
        for (const auto& [k, v] : prop_overrides) {
            scene.set_user_property(k, v);
        }
    }

    // Offscreen screenshot mode (for automated visual verification!)
    if (!headless_shot.empty()) {
        GLuint shot_fbo = 0, shot_tex = 0;
        glGenTextures(1, &shot_tex);
        glBindTexture(GL_TEXTURE_2D, shot_tex);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, win_w, win_h, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
        glGenFramebuffers(1, &shot_fbo);
        glBindFramebuffer(GL_FRAMEBUFFER, shot_fbo);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, shot_tex, 0);

        for (int f = 0; f < shot_frames; ++f) {
            // Sweep cursor slightly so parallax and mouse-trail particles visibly activate
            float t = static_cast<float>(f) / std::max(1, shot_frames - 1);
            scene.set_cursor(0.35f + 0.30f * t, 0.45f + 0.10f * std::sin(t * 6.283f));
            scene.update(1.0f / 30.0f);
            glBindFramebuffer(GL_FRAMEBUFFER, 0);
            scene.render(win_w, win_h);
            // Give background video decoder a brief slice on early frames so first video frame is ready
            if (f < 10) std::this_thread::sleep_for(std::chrono::milliseconds(25));
        }

        // Render final frame into shot_fbo? Note: Scene::render binds FBO 0 at the end,
        // which is our EGL pbuffer surface! So glReadPixels reads directly from FBO 0!
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        scene.render(win_w, win_h);
        glFinish();

        bool ok = save_ppm(headless_shot, win_w, win_h);
        std::cerr << "[somewall] saved screenshot: " << headless_shot << " (" << (ok ? "ok" : "failed") << ")\n";
        glDeleteFramebuffers(1, &shot_fbo);
        glDeleteTextures(1, &shot_tex);
        return ok ? 0 : 1;
    }

    // Set stdin non-blocking if IPC is enabled
    std::string stdin_buf;
    if (stdin_ipc) {
        int fl = ::fcntl(STDIN_FILENO, F_GETFL, 0);
        ::fcntl(STDIN_FILENO, F_SETFL, fl | O_NONBLOCK);
    }

    bool global_paused = false;
    auto mark_dirty = [&]() {
        for (auto& s : app.surfaces()) s->dirty = true;
    };
    auto json_str = [](const std::string& v) {
        std::string o = "\"";
        for (char c : v) {
            if (c == '"' || c == '\\') o += '\\';
            o += c;
        }
        return o + "\"";
    };
    auto report = [&](const char* event, const char* extra) {
        std::cout << "{\"event\":\"" << event << "\",\"type\":" << json_str(scene.type())
                  << ",\"decoder\":" << json_str(scene.video_decoders())
                  << ",\"cursor\":" << (scene.uses_cursor() ? "true" : "false")
                  << ",\"fps\":" << target_fps << ",\"scale\":" << app.render_scale()
                  << ",\"paused\":" << (global_paused ? "true" : "false") << extra << "}\n" << std::flush;
    };

    auto handle_ipc_line = [&](const std::string& line) {
        if (line.empty()) return;
        sw::Json msg = sw::Json::parse(line);
        if (!msg.is_object()) return;
        std::string cmd = msg["cmd"].as_string();
        if (cmd == "quit") {
            app.request_quit();
        } else if (cmd == "pause" || cmd == "resume") {
            const bool on = cmd == "pause";
            std::string mon = msg["monitor"].as_string();
            if (mon.empty()) {
                global_paused = on;
                for (auto& s : app.surfaces()) s->paused = on;
            } else {
                for (auto& s : app.surfaces()) {
                    if (s->name == mon) s->paused = on;
                }
            }
            bool all_p = true;
            for (auto& s : app.surfaces()) {
                if (!s->paused) all_p = false;
                // Drawn again once it shows: an image or a paused video has no next frame
                if (!on) s->dirty = true;
            }
            global_paused = all_p;
            scene.set_paused(all_p);
        } else if (cmd == "load") {
            std::string p = msg["path"].as_string();
            if (!p.empty()) {
                for (auto& s : app.surfaces()) {
                    if (s->egl_surface != EGL_NO_SURFACE) { app.make_current(*s); break; }
                }
                bool ok = scene.load(p);
                if (ok && global_paused) scene.set_paused(true);
                mark_dirty();
                report("loaded", ok ? ",\"ok\":true" : ",\"ok\":false");
            }
        } else if (cmd == "set_prop") {
            std::string k = msg["key"].as_string();
            if (!k.empty()) scene.set_user_property(k, msg["value"]);
            mark_dirty();
        } else if (cmd == "fps") {
            target_fps = std::clamp(msg["value"].as_int(60), 1, 240);
        } else if (cmd == "scale") {
            app.set_render_scale(msg["value"].as_float(1.0f));
        } else if (cmd == "status") {
            report("status", "");
        }
    };

    using clock = std::chrono::steady_clock;
    auto prev_time = clock::now();
    auto next_frame = clock::now();
    auto next_cursor = clock::now();
    const auto cursor_every = std::chrono::milliseconds(33);

    report("ready", "");

    while (!g_stop && !app.should_quit()) {
        bool any_active = false;
        bool any_dirty = false;
        if (!global_paused) {
            for (const auto& s : app.surfaces()) {
                if (s->configured && !s->closed && !s->paused) {
                    any_active = true;
                    if (s->dirty) any_dirty = true;
                }
            }
        }
        const bool event_paced = scene.is_static_paced();
        const int wake = (any_active && event_paced) ? scene.wake_fd() : -1;

        // How long to sleep: paused or a still picture → until something
        // happens (Wayland, IPC, the next video frame); a scene → until its next frame
        int poll_ms = -1;
        auto now = clock::now();
        if (any_active && scene.is_loaded()) {
            if (any_dirty) {
                poll_ms = 0;
            } else if (!event_paced) {
                auto wait = std::chrono::duration_cast<std::chrono::milliseconds>(next_frame - now).count();
                poll_ms = static_cast<int>(std::max<long long>(0, wait));
            }
        }

        pollfd fds[3]{};
        int nfds = 0;
        int wfd = app.wl_fd();
        int wl_idx = -1, in_idx = -1;
        if (wfd >= 0) { wl_idx = nfds; fds[nfds++] = {wfd, POLLIN, 0}; }
        if (stdin_ipc) { in_idx = nfds; fds[nfds++] = {STDIN_FILENO, POLLIN, 0}; }
        if (wake >= 0) { fds[nfds++] = {wake, POLLIN, 0}; }

        app.poll_events(); // flush requests before sleeping
        if (nfds > 0 && ::poll(fds, static_cast<nfds_t>(nfds), poll_ms) > 0) {
            if (wl_idx >= 0 && (fds[wl_idx].revents & (POLLIN | POLLHUP | POLLERR))) {
                if (!app.poll_events(true)) break;
            }
            if (in_idx >= 0 && (fds[in_idx].revents & (POLLIN | POLLHUP))) {
                char buf[4096];
                ssize_t n = ::read(STDIN_FILENO, buf, sizeof(buf));
                if (n > 0) {
                    stdin_buf.append(buf, static_cast<size_t>(n));
                    size_t nl = 0;
                    while ((nl = stdin_buf.find('\n')) != std::string::npos) {
                        std::string line = stdin_buf.substr(0, nl);
                        stdin_buf.erase(0, nl + 1);
                        handle_ipc_line(line);
                    }
                } else if (n == 0) {
                    // Parent shell closed stdin -> exit cleanly
                    app.request_quit();
                    break;
                }
            }
        }
        if (!app.poll_events()) break;

        // Recount after events and IPC (a pause or a configure may have come in)
        any_active = false;
        if (!global_paused) {
            for (const auto& s : app.surfaces()) {
                if (s->configured && !s->closed && !s->paused) { any_active = true; break; }
            }
        }
        if (!any_active || !scene.is_loaded()) {
            prev_time = clock::now();
            continue;
        }

        now = clock::now();
        if (!event_paced) {
            if (now < next_frame) continue;
            auto frame_dur = std::chrono::microseconds(1000000 / std::max(1, target_fps));
            next_frame += frame_dur;
            if (next_frame < now) next_frame = now + frame_dur; // fell behind: no catch-up burst
        }
        float dt = std::chrono::duration<float>(now - prev_time).count();
        prev_time = now;

        // The cursor, only when the scene reads it
        if (scene.uses_cursor()) {
            if (windowed && app.has_pointer()) {
                scene.set_cursor(app.pointer_x(), app.pointer_y());
            } else if (use_hypr_cursor && now >= next_cursor) {
                next_cursor = now + cursor_every;
                float cx = 0.5f, cy = 0.5f;
                if (app.query_hypr_cursor(cx, cy)) scene.set_cursor(cx, cy);
            }
        }

        bool changed = false;
        bool updated = false;
        for (auto& s : app.surfaces()) {
            if (!s->configured || s->closed || s->paused || s->egl_surface == EGL_NO_SURFACE) continue;
            if (!app.make_current(*s)) continue;
            if (!updated) {
                changed = scene.update(dt);
                updated = true;
            }
            if (!changed && !s->dirty) continue;
            scene.render(s->width, s->height);
            app.swap_buffers(*s);
            s->dirty = false;
        }
    }

    scene.unload();
    app.shutdown();
    return 0;
}
