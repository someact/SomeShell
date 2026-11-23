#include "scene.hpp"

#include <GL/glext.h>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>

#include <algorithm>
#include <cctype>
#include <cmath>
#include <iostream>

namespace sw {

namespace fs = std::filesystem;

namespace {

GLuint compile_glsl(GLenum type, const char* src) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    GLint ok = 0;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[1024];
        glGetShaderInfoLog(s, sizeof(log), nullptr, log);
        std::cerr << "[scene] builtin shader error: " << log << "\n";
        glDeleteShader(s);
        return 0;
    }
    return s;
}

GLuint link_glsl(const char* vs_src, const char* fs_src) {
    GLuint vs = compile_glsl(GL_VERTEX_SHADER, vs_src);
    GLuint fs = compile_glsl(GL_FRAGMENT_SHADER, fs_src);
    if (!vs || !fs) {
        if (vs) glDeleteShader(vs);
        if (fs) glDeleteShader(fs);
        return 0;
    }
    GLuint p = glCreateProgram();
    glAttachShader(p, vs);
    glAttachShader(p, fs);
    glBindAttribLocation(p, 0, "a_Position");
    glBindAttribLocation(p, 1, "a_TexCoord");
    glLinkProgram(p);
    glDeleteShader(vs);
    glDeleteShader(fs);
    return p;
}

void set_gl_blend(const std::string& mode) {
    if (mode == "normal" || mode == "disabled") {
        glDisable(GL_BLEND);
    } else if (mode == "additive") {
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    } else if (mode == "screen") {
        glEnable(GL_BLEND);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_COLOR);
    } else if (mode == "multiply") {
        glEnable(GL_BLEND);
        glBlendFunc(GL_DST_COLOR, GL_ONE_MINUS_SRC_ALPHA);
    } else {
        // translucent (default)
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }
}

std::string to_lower_str(std::string s) {
    for (char& c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return s;
}

void create_fbo_target(GLuint& fbo, GLuint& tex, int w, int h) {
    if (!tex) glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);

    if (!fbo) glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex, 0);
}

glm::mat4 make_euler_xyz(const glm::vec3& angles) {
    glm::mat4 m(1.0f);
    m = glm::rotate(m, angles.z, glm::vec3(0.0f, 0.0f, 1.0f));
    m = glm::rotate(m, angles.y, glm::vec3(0.0f, 1.0f, 0.0f));
    m = glm::rotate(m, angles.x, glm::vec3(1.0f, 0.0f, 0.0f));
    return m;
}

} // namespace

SceneObject::~SceneObject() {
    if (text_tex) {
        glDeleteTextures(1, &text_tex);
        text_tex = 0;
    }
}

Scene::~Scene() {
    unload();
    if (quad_vbo_) glDeleteBuffers(1, &quad_vbo_);
    if (quad_vao_) glDeleteVertexArrays(1, &quad_vao_);
    if (dummy_vao_) glDeleteVertexArrays(1, &dummy_vao_);
    if (blit_prog_) glDeleteProgram(blit_prog_);
    if (cover_prog_) glDeleteProgram(cover_prog_);
    if (text_prog_) glDeleteProgram(text_prog_);
    if (bloom_extract_prog_) glDeleteProgram(bloom_extract_prog_);
    if (bloom_blur_prog_) glDeleteProgram(bloom_blur_prog_);
    if (bloom_add_prog_) glDeleteProgram(bloom_add_prog_);
    if (main_fbo_) glDeleteFramebuffers(1, &main_fbo_);
    if (main_tex_) glDeleteTextures(1, &main_tex_);
    if (copy_fbo_) glDeleteFramebuffers(1, &copy_fbo_);
    if (copy_tex_) glDeleteTextures(1, &copy_tex_);
    for (int i = 0; i < 2; ++i) {
        if (fx_fbo_[i]) glDeleteFramebuffers(1, &fx_fbo_[i]);
        if (fx_tex_[i]) glDeleteTextures(1, &fx_tex_[i]);
        if (bloom_fbo_[i]) glDeleteFramebuffers(1, &bloom_fbo_[i]);
        if (bloom_tex_[i]) glDeleteTextures(1, &bloom_tex_[i]);
    }
}

void Scene::set_assets_dir(const fs::path& assets_dir) {
    assets_dir_ = assets_dir;
    vfs_.set_assets_dir(assets_dir);
}

void Scene::unload() {
    objects_.clear();
    direct_video_.reset();
    direct_image_ = nullptr;
    if (shader_cache_) shader_cache_->clear();
    if (tex_cache_) tex_cache_->clear();
    user_props_.clear();
    mode_ = Mode::None;
    title_.clear();
    type_str_.clear();
    time_sec_ = 0.0;
}

PropBinding Scene::parse_binding(const Json& j) const {
    PropBinding b;
    if (j.is_object() && j.has("user")) {
        const auto& u = j["user"];
        if (u.is_string()) {
            b.user_key = u.as_string();
        } else if (u.is_object()) {
            b.user_key = u["name"].as_string();
            if (u.has("condition")) {
                b.has_condition = true;
                b.condition = u["condition"].as_string();
            }
        }
        b.fallback = j["value"];
    } else if (j.is_object() && j.has("value")) {
        b.fallback = j["value"];
    } else {
        b.fallback = j;
    }
    return b;
}

Json Scene::resolve_binding(const PropBinding& b) const {
    if (!b.user_key.empty()) {
        auto it = user_props_.find(b.user_key);
        if (it != user_props_.end()) {
            if (b.has_condition) {
                return Json(it->second.as_string() == b.condition);
            }
            return it->second;
        }
    }
    return b.fallback;
}

void Scene::set_user_property(const std::string& key, const Json& val) {
    user_props_[key] = val;
    refresh_user_properties();
}

void Scene::refresh_user_properties() {
    for (auto& obj : objects_) {
        if (!obj.visible_bind.user_key.empty()) {
            obj.visible = resolve_binding(obj.visible_bind).as_bool(obj.visible);
        }
        if (!obj.color_bind.user_key.empty()) {
            obj.color = resolve_binding(obj.color_bind).as_vec3(obj.color);
        }
        if (!obj.alpha_bind.user_key.empty()) {
            obj.alpha = resolve_binding(obj.alpha_bind).as_float(obj.alpha);
        }
        if (!obj.scale_bind.user_key.empty()) {
            Json sv = resolve_binding(obj.scale_bind);
            if (sv.is_number()) obj.scale = glm::vec3(sv.as_float(1.0f));
            else obj.scale = sv.as_vec3(obj.scale);
        }
        for (const auto& [upk, mk] : obj.user_shader_values) {
            auto it = user_props_.find(upk);
            if (it != user_props_.end()) obj.material_constants[mk] = it->second;
        }
        if (obj.particle_sys) {
            obj.particle_sys->set_user_props(user_props_);
        }
        for (auto& fx : obj.effects) {
            if (!fx.visible_bind.user_key.empty()) {
                fx.visible = resolve_binding(fx.visible_bind).as_bool(fx.visible);
            }
        }
    }
}

void Scene::set_paused(bool paused) {
    paused_ = paused;
    if (direct_video_) direct_video_->set_paused(paused);
    if (tex_cache_) tex_cache_->set_paused(paused);
}

Scene::Fit Scene::parse_fit(const std::string& s) {
    if (s == "fit") return Fit::Fit;
    if (s == "stretch") return Fit::Stretch;
    if (s == "center" || s == "centre") return Fit::Center;
    return Fit::Fill;
}

void Scene::set_speed(float speed) {
    speed_ = std::clamp(speed, 0.1f, 4.0f);
    if (direct_video_) direct_video_->set_speed(speed_);
    if (tex_cache_) tex_cache_->set_speed(speed_);
}

void Scene::set_cursor(float norm_x, float norm_y) {
    raw_cursor_.x = std::clamp(norm_x, 0.0f, 1.0f);
    raw_cursor_.y = std::clamp(norm_y, 0.0f, 1.0f);
}

bool Scene::load(const fs::path& path) {
    unload();
    std::error_code ec;

    // Direct video or image file
    if (fs::is_regular_file(path, ec)) {
        std::string ext = to_lower_str(path.extension().string());
        if (ext == ".mp4" || ext == ".webm" || ext == ".mkv" || ext == ".mov" || ext == ".avi") {
            return load_video(path);
        }
        if (ext == ".png" || ext == ".jpg" || ext == ".jpeg" || ext == ".webp" || ext == ".bmp") {
            return load_image(path);
        }
        // If user passed path/to/project.json, use parent directory
        if (path.filename() == "project.json") {
            return load(path.parent_path());
        }
        return false;
    }

    if (!fs::is_directory(path, ec)) {
        std::cerr << "[scene] path not found: " << path << "\n";
        return false;
    }

    vfs_.set_assets_dir(assets_dir_);
    vfs_.mount_wallpaper(path);
    tex_cache_ = std::make_unique<TextureCache>(vfs_);
    shader_cache_ = std::make_unique<ShaderCache>(vfs_);

    auto proj_txt = vfs_.read_text("project.json");
    if (!proj_txt) {
        std::cerr << "[scene] missing project.json in " << path << "\n";
        return false;
    }

    Json proj = Json::parse(*proj_txt);
    title_ = proj["title"].as_string(path.filename().string());
    type_str_ = to_lower_str(proj["type"].as_string("scene"));
    std::string main_file = proj["file"].as_string();

    // Load user property defaults from project.json
    const auto& props = proj["general"]["properties"].as_object();
    for (const auto& [k, v] : props) {
        if (v.is_object() && v.has("value")) {
            user_props_[k] = v["value"];
        }
    }

    if (type_str_ == "video") {
        fs::path vpath = path / main_file;
        std::cerr << "[scene] loading video wallpaper '" << title_ << "': " << vpath << "\n";
        return load_video(vpath);
    }

    if (type_str_ == "scene" || main_file.ends_with(".json")) {
        std::string sf = main_file.empty() ? "scene.json" : main_file;
        std::cerr << "[scene] loading scene wallpaper '" << title_ << "' (" << sf << ")\n";
        return load_scene(proj, sf);
    }

    std::cerr << "[scene] unsupported wallpaper type: " << type_str_ << "\n";
    return false;
}

bool Scene::load_video(const fs::path& video_path) {
    std::error_code ec;
    auto sz = fs::file_size(video_path, ec);
    if (ec || sz == 0) {
        std::cerr << "[scene] video file unreadable: " << video_path << "\n";
        return false;
    }
    direct_video_ = std::make_unique<VideoDecoder>();
    if (!direct_video_->open(FileSlice{video_path, 0, sz})) {
        direct_video_.reset();
        return false;
    }
    mode_ = Mode::Video;
    type_str_ = "video";
    return true;
}

bool Scene::load_image(const fs::path& image_path) {
    vfs_.mount_wallpaper(image_path.parent_path());
    tex_cache_ = std::make_unique<TextureCache>(vfs_);
    direct_image_ = tex_cache_->load(image_path.filename().string());
    if (!direct_image_) return false;
    mode_ = Mode::Image;
    type_str_ = "image";
    return true;
}

bool Scene::load_scene(const Json& /*proj_json*/, const std::string& scene_file) {
    auto stxt = vfs_.read_text(scene_file);
    if (!stxt) {
        std::cerr << "[scene] missing " << scene_file << "\n";
        return false;
    }
    Json sj = Json::parse(*stxt);
    if (!sj.is_object()) return false;

    // Camera
    const auto& cam = sj["camera"];
    cam_eye_ = cam["eye"].as_vec3(glm::vec3(0.0f, 0.0f, 1.0f));
    cam_center_ = cam["center"].as_vec3(glm::vec3(0.0f, 0.0f, 0.0f));
    cam_up_ = cam["up"].as_vec3(glm::vec3(0.0f, 1.0f, 0.0f));

    // General
    const auto& gen = sj["general"];
    clear_color_ = gen["clearcolor"].as_vec3(glm::vec3(0.0f));
    clear_enabled_ = gen["clearenabled"].as_bool(true);
    cam_fov_ = gen["fov"].as_float(50.0f);
    cam_near_ = gen["nearz"].as_float(0.01f);
    cam_far_ = gen["farz"].as_float(10000.0f);
    cam_zoom_ = gen["zoom"].as_float(1.0f);

    if (gen.has("orthogonalprojection") && gen["orthogonalprojection"].is_object()) {
        is_ortho_ = true;
        ortho_w_ = gen["orthogonalprojection"]["width"].as_float(1920.0f);
        ortho_h_ = gen["orthogonalprojection"]["height"].as_float(1080.0f);
    } else {
        is_ortho_ = false;
        ortho_w_ = 1920.0f;
        ortho_h_ = 1080.0f;
    }

    parallax_enabled_ = gen["cameraparallax"].as_bool(false);
    parallax_amount_ = gen["cameraparallaxamount"].as_float(0.5f);
    parallax_delay_ = std::max(0.01f, gen["cameraparallaxdelay"].as_float(0.1f));
    parallax_mouse_inf_ = gen["cameraparallaxmouseinfluence"].as_float(0.5f);

    shake_enabled_ = gen["camerashake"].as_bool(false);
    shake_amp_ = gen["camerashakeamplitude"].as_float(0.0f);
    shake_speed_ = gen["camerashakespeed"].as_float(1.0f);

    bloom_enabled_ = gen["bloom"].as_bool(false);
    bloom_threshold_ = gen["bloomthreshold"].as_float(0.65f);
    bloom_strength_ = resolve_binding(parse_binding(gen["bloomstrength"])).as_float(1.0f);

    // Objects
    for (const auto& oj : sj["objects"].as_array()) {
        if (!oj.is_object()) continue;

        SceneObject obj;
        obj.id = oj["id"].as_int(0);
        obj.name = oj["name"].as_string();

        obj.visible_bind = parse_binding(oj["visible"]);
        obj.visible = oj.has("visible") ? resolve_binding(obj.visible_bind).as_bool(true) : true;

        obj.origin = oj["origin"].as_vec3(glm::vec3(0.0f));
        obj.angles = oj["angles"].as_vec3(glm::vec3(0.0f));
        obj.size = oj["size"].as_vec2(glm::vec2(0.0f));
        obj.parallax_depth = oj["parallaxDepth"].as_vec2(glm::vec2(0.0f));
        obj.alignment = oj["alignment"].as_string("center");
        obj.brightness = oj["brightness"].as_float(1.0f);
        obj.color_blend_mode = oj["colorBlendMode"].as_int(0);
        obj.copy_background = oj["copybackground"].as_bool(false);

        obj.color_bind = parse_binding(oj["color"]);
        obj.color = oj.has("color") ? resolve_binding(obj.color_bind).as_vec3(glm::vec3(1.0f)) : glm::vec3(1.0f);

        obj.alpha_bind = parse_binding(oj["alpha"]);
        obj.alpha = oj.has("alpha") ? resolve_binding(obj.alpha_bind).as_float(1.0f) : 1.0f;

        obj.scale_bind = parse_binding(oj["scale"]);
        if (oj.has("scale")) {
            Json sv = resolve_binding(obj.scale_bind);
            if (sv.is_number()) obj.scale = glm::vec3(sv.as_float(1.0f));
            else obj.scale = sv.as_vec3(glm::vec3(1.0f));
        }

        // Determine object kind: particle / image / text
        if (oj.has("particle") && oj["particle"].is_string() && !oj["particle"].as_string().empty()) {
            obj.kind = SceneObject::Kind::Particle;
            ParticleInstanceOverride ov;
            if (oj.has("instanceoverride") && oj["instanceoverride"].is_object()) {
                const auto& io = oj["instanceoverride"];
                if (io.has("colorn")) ov.color_mul = resolve_binding(parse_binding(io["colorn"])).as_vec3(glm::vec3(1.0f));
                else if (io.has("color")) ov.color_mul = resolve_binding(parse_binding(io["color"])).as_vec3(glm::vec3(255.0f)) / 255.0f;
                if (io.has("alpha")) ov.alpha_mul = resolve_binding(parse_binding(io["alpha"])).as_float(1.0f);
                if (io.has("size")) ov.size_mul = resolve_binding(parse_binding(io["size"])).as_float(1.0f);
                if (io.has("rate")) ov.rate_mul = resolve_binding(parse_binding(io["rate"])).as_float(1.0f);
                if (io.has("speed")) ov.speed_mul = resolve_binding(parse_binding(io["speed"])).as_float(1.0f);
                if (io.has("count")) ov.count_mul = resolve_binding(parse_binding(io["count"])).as_float(1.0f);
                if (io.has("lifetime")) ov.lifetime_mul = resolve_binding(parse_binding(io["lifetime"])).as_float(1.0f);
                if (io.has("brightness")) ov.brightness_mul = resolve_binding(parse_binding(io["brightness"])).as_float(1.0f);
            }
            obj.particle_sys = std::make_unique<ParticleSystem>();
            if (obj.particle_sys->load(vfs_, *tex_cache_, *shader_cache_, oj["particle"].as_string(), ov, user_props_)) {
                objects_.push_back(std::move(obj));
            }
        } else if (oj.has("text")) {
            obj.kind = SceneObject::Kind::Text;
            obj.font = oj["font"].as_string("systemfont_consolas");
            obj.point_size = oj["pointsize"].as_float(32.0f);
            obj.halign = oj["horizontalalign"].as_string("center");
            obj.valign = oj["verticalalign"].as_string("center");
            const auto& tj = oj["text"];
            if (tj.is_string()) {
                obj.text_value = tj.as_string();
            } else if (tj.is_object()) {
                obj.text_value = tj["value"].as_string();
                if (tj.has("script") && tj["script"].is_string()) {
                    obj.text_script = std::make_unique<PropertyScript>();
                    obj.text_script->init(tj["script"].as_string(), tj["scriptproperties"]);
                }
            }
            objects_.push_back(std::move(obj));
        } else if (oj.has("image") && oj["image"].is_string() && !oj["image"].as_string().empty()) {
            obj.kind = SceneObject::Kind::Image;
            std::string model_path = oj["image"].as_string();
            auto mtxt = vfs_.read_text(model_path);
            if (!mtxt) continue;
            Json model_j = Json::parse(*mtxt);
            if (model_j["fullscreen"].as_bool(false)) obj.fullscreen = true;

            std::string mat_path = model_j["material"].as_string();
            auto mat_txt = vfs_.read_text(mat_path);
            if (!mat_txt) continue;
            Json mat_j = Json::parse(*mat_txt);
            const auto& passes = mat_j["passes"].as_array();
            if (passes.empty()) continue;

            const auto& pass0 = passes[0];
            std::string shader_name = pass0["shader"].as_string("genericimage4");
            obj.blending = pass0["blending"].as_string("translucent");

            std::map<std::string, int> combos;
            for (const auto& [ck, cv] : pass0["combos"].as_object()) {
                combos[ck] = cv.as_int(0);
            }
            if (obj.color_blend_mode > 0) {
                combos["BLENDMODE"] = obj.color_blend_mode;
            }
            if (is_ortho_) combos["SCENE_ORTHO"] = 1;

            for (const auto& tj : pass0["textures"].as_array()) {
                if (tj.is_string() && !tj.as_string().empty()) {
                    obj.textures.push_back(tex_cache_->load(tj.as_string()));
                } else {
                    obj.textures.push_back(nullptr);
                }
            }

            for (const auto& [uk, uv] : pass0["constantshadervalues"].as_object()) {
                obj.material_constants[uk] = uv;
            }
            for (const auto& [upk, mk] : pass0["usershadervalues"].as_object()) {
                if (mk.is_string()) {
                    obj.user_shader_values[upk] = mk.as_string();
                    auto it = user_props_.find(upk);
                    if (it != user_props_.end()) obj.material_constants[mk.as_string()] = it->second;
                }
            }

            if (!obj.textures.empty() && obj.textures[0]) {
                Texture* t0 = obj.textures[0];
                combos["TEX0FORMAT"] = static_cast<int>(t0->format);
                if (t0->is_spritesheet && !t0->frames.empty()) {
                    combos["SPRITESHEET"] = 1;
                    obj.animated_sprite = true;
                }
                if (obj.size.x <= 0.0f || obj.size.y <= 0.0f) {
                    obj.size = glm::vec2(model_j["width"].as_float(static_cast<float>(t0->img_width)),
                                         model_j["height"].as_float(static_cast<float>(t0->img_height)));
                }
            }

            obj.shader = shader_cache_->get(shader_name, combos);
            if (!obj.shader) continue;

            // Parse optional multi-pass effects chain on this image object
            for (const auto& fxj : oj["effects"].as_array()) {
                if (!fxj.is_object()) continue;
                ImageEffect fx;
                fx.visible_bind = parse_binding(fxj["visible"]);
                fx.visible = fxj.has("visible") ? resolve_binding(fx.visible_bind).as_bool(true) : true;

                std::string fx_file = fxj["file"].as_string();
                auto fx_txt = vfs_.read_text(fx_file);
                if (!fx_txt) continue;
                // Register the effect's directory so its materials/ and shaders/ resolve via VFS
                if (auto fx_loc = vfs_.locate(fx_file); fx_loc && fx_loc->offset == 0) {
                    vfs_.add_extra_dir(fx_loc->disk_path.parent_path());
                }
                Json fx_def = Json::parse(*fx_txt);
                const auto& def_passes = fx_def["passes"].as_array();
                const auto& ov_passes = fxj["passes"].as_array();

                for (size_t pi = 0; pi < def_passes.size(); ++pi) {
                    std::string pmat_path = def_passes[pi]["material"].as_string();
                    auto pm_txt = vfs_.read_text(pmat_path);
                    if (!pm_txt) continue;
                    Json pm_j = Json::parse(*pm_txt);
                    const auto& pm_passes = pm_j["passes"].as_array();
                    if (pm_passes.empty()) continue;

                    const auto& base_p = pm_passes[0];
                    EffectPass ep;
                    std::string pshader = base_p["shader"].as_string();
                    ep.blending = base_p["blending"].as_string("normal");

                    std::map<std::string, int> pcombos;
                    for (const auto& [ck, cv] : base_p["combos"].as_object()) pcombos[ck] = cv.as_int(0);
                    for (const auto& [uk, uv] : base_p["constantshadervalues"].as_object()) ep.constants[uk] = uv;

                    std::vector<std::string> tex_names;
                    for (const auto& t : base_p["textures"].as_array()) {
                        tex_names.push_back(t.is_string() ? t.as_string() : "");
                    }

                    // Apply scene-level overrides for this effect pass
                    if (pi < ov_passes.size() && ov_passes[pi].is_object()) {
                        const auto& ovp = ov_passes[pi];
                        for (const auto& [ck, cv] : ovp["combos"].as_object()) pcombos[ck] = cv.as_int(0);
                        for (const auto& [uk, uv] : ovp["constantshadervalues"].as_object()) {
                            ep.constants[uk] = resolve_binding(parse_binding(uv));
                        }
                        const auto& ovt = ovp["textures"].as_array();
                        if (ovt.size() > tex_names.size()) tex_names.resize(ovt.size());
                        for (size_t ti = 0; ti < ovt.size(); ++ti) {
                            if (ovt[ti].is_string() && !ovt[ti].as_string().empty()) {
                                tex_names[ti] = ovt[ti].as_string();
                            }
                        }
                    }

                    ep.textures.resize(tex_names.size(), nullptr);
                    ep.slot_is_fb.resize(tex_names.size(), false);
                    for (size_t ti = 0; ti < tex_names.size(); ++ti) {
                        if (tex_names[ti] == "_rt_FullFrameBuffer") {
                            ep.slot_is_fb[ti] = true;
                        } else if (!tex_names[ti].empty()) {
                            ep.textures[ti] = tex_cache_->load(tex_names[ti]);
                        }
                    }

                    ep.shader = shader_cache_->get(pshader, pcombos);
                    if (ep.shader) fx.passes.push_back(std::move(ep));
                }

                if (!fx.passes.empty()) obj.effects.push_back(std::move(fx));
            }

            objects_.push_back(std::move(obj));
        }
    }

    mode_ = Mode::Scene;
    std::cerr << "[scene] loaded " << objects_.size() << " scene objects ("
              << ortho_w_ << "x" << ortho_h_ << ", ortho=" << is_ortho_ << ")\n";
    return true;
}

void Scene::ensure_common_gl() {
    if (quad_vao_ != 0) return;

    // Unit centered quad (-0.5..+0.5) with top-left UV (0,0) and bottom-right UV (1,1)
    // Dynamic UVs per object are handled via VBO subdata or scaled in shader
    static const float kQuadVerts[] = {
        // x,     y,     z,    u,    v
        -0.5f,  0.5f, 0.0f, 0.0f, 0.0f,
         0.5f,  0.5f, 0.0f, 1.0f, 0.0f,
         0.5f, -0.5f, 0.0f, 1.0f, 1.0f,
        -0.5f,  0.5f, 0.0f, 0.0f, 0.0f,
         0.5f, -0.5f, 0.0f, 1.0f, 1.0f,
        -0.5f, -0.5f, 0.0f, 0.0f, 1.0f,
    };

    glGenVertexArrays(1, &quad_vao_);
    glGenBuffers(1, &quad_vbo_);
    glBindVertexArray(quad_vao_);
    glBindBuffer(GL_ARRAY_BUFFER, quad_vbo_);
    glBufferData(GL_ARRAY_BUFFER, sizeof(kQuadVerts), kQuadVerts, GL_DYNAMIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), reinterpret_cast<void*>(0));
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), reinterpret_cast<void*>(3 * sizeof(float)));
    glBindVertexArray(0);

    glGenVertexArrays(1, &dummy_vao_);

    // Fullscreen triangle vertex shader
    static const char* kFullVS = R"GLSL(
#version 330 core
out vec2 v_uv;
void main() {
    vec2 pos[3] = vec2[3](vec2(-1.0, -1.0), vec2(3.0, -1.0), vec2(-1.0, 3.0));
    vec2 uv[3]  = vec2[3](vec2(0.0, 0.0),   vec2(2.0, 0.0),  vec2(0.0, 2.0));
    gl_Position = vec4(pos[gl_VertexID], 0.0, 1.0);
    v_uv = uv[gl_VertexID];
}
)GLSL";

    static const char* kBlitFS = R"GLSL(
#version 330 core
in vec2 v_uv;
out vec4 fragColor;
uniform sampler2D u_tex;
void main() {
    fragColor = texture(u_tex, v_uv);
}
)GLSL";

    // Aspect-preserving PreserveAspectCrop blit for direct video/image mode
    static const char* kCoverFS = R"GLSL(
#version 330 core
in vec2 v_uv;
out vec4 fragColor;
uniform sampler2D u_tex;
uniform vec2 u_scale;
uniform vec2 u_offset;
void main() {
    // Flip Y because video/image row 0 is top while v_uv.y=0 is bottom
    vec2 uv = vec2(v_uv.x, 1.0 - v_uv.y);
    uv = uv * u_scale + u_offset;
    fragColor = texture(u_tex, uv);
}
)GLSL";

    static const char* kTextVS = R"GLSL(
#version 330 core
in vec3 a_Position;
in vec2 a_TexCoord;
out vec2 v_uv;
uniform mat4 u_mvp;
void main() {
    gl_Position = u_mvp * vec4(a_Position, 1.0);
    v_uv = a_TexCoord;
}
)GLSL";

    static const char* kTextFS = R"GLSL(
#version 330 core
in vec2 v_uv;
out vec4 fragColor;
uniform sampler2D u_tex;
uniform vec4 u_color;
void main() {
    vec4 t = texture(u_tex, v_uv);
    fragColor = vec4(t.rgb * u_color.rgb, t.a * u_color.a);
}
)GLSL";

    static const char* kBloomExtractFS = R"GLSL(
#version 330 core
in vec2 v_uv;
out vec4 fragColor;
uniform sampler2D u_tex;
uniform float u_threshold;
void main() {
    vec3 c = texture(u_tex, v_uv).rgb;
    float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
    float k = max(0.0, lum - u_threshold) / max(lum, 0.001);
    fragColor = vec4(c * k, 1.0);
}
)GLSL";

    static const char* kBloomBlurFS = R"GLSL(
#version 330 core
in vec2 v_uv;
out vec4 fragColor;
uniform sampler2D u_tex;
uniform vec2 u_dir;
void main() {
    float w[5] = float[5](0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);
    vec3 sum = texture(u_tex, v_uv).rgb * w[0];
    for (int i = 1; i < 5; ++i) {
        vec2 off = u_dir * float(i);
        sum += texture(u_tex, v_uv + off).rgb * w[i];
        sum += texture(u_tex, v_uv - off).rgb * w[i];
    }
    fragColor = vec4(sum, 1.0);
}
)GLSL";

    static const char* kBloomAddFS = R"GLSL(
#version 330 core
in vec2 v_uv;
out vec4 fragColor;
uniform sampler2D u_scene;
uniform sampler2D u_bloom;
uniform float u_strength;
void main() {
    vec3 s = texture(u_scene, v_uv).rgb;
    vec3 b = texture(u_bloom, v_uv).rgb;
    fragColor = vec4(s + b * u_strength, 1.0);
}
)GLSL";

    blit_prog_ = link_glsl(kFullVS, kBlitFS);
    cover_prog_ = link_glsl(kFullVS, kCoverFS);
    text_prog_ = link_glsl(kTextVS, kTextFS);
    bloom_extract_prog_ = link_glsl(kFullVS, kBloomExtractFS);
    bloom_blur_prog_ = link_glsl(kFullVS, kBloomBlurFS);
    bloom_add_prog_ = link_glsl(kFullVS, kBloomAddFS);
}

void Scene::ensure_fbos(int w, int h) {
    if (fbo_w_ == w && fbo_h_ == h && main_fbo_ != 0) return;
    fbo_w_ = w;
    fbo_h_ = h;
    create_fbo_target(main_fbo_, main_tex_, w, h);
    create_fbo_target(copy_fbo_, copy_tex_, w, h);
    create_fbo_target(fx_fbo_[0], fx_tex_[0], w, h);
    create_fbo_target(fx_fbo_[1], fx_tex_[1], w, h);
    int bw = std::max(1, w / 4);
    int bh = std::max(1, h / 4);
    create_fbo_target(bloom_fbo_[0], bloom_tex_[0], bw, bh);
    create_fbo_target(bloom_fbo_[1], bloom_tex_[1], bw, bh);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

bool Scene::uses_cursor() const {
    if (mode_ != Mode::Scene) return false;
    if (parallax_enabled_) return true;
    for (const auto& obj : objects_) {
        if (obj.particle_sys && obj.particle_sys->uses_mouse()) return true;
    }
    return false;
}

std::string Scene::video_decoders() const {
    if (direct_video_) return direct_video_->decoder_name();
    return tex_cache_ ? tex_cache_->video_decoders() : std::string();
}

int Scene::wake_fd() const {
    return (mode_ == Mode::Video && direct_video_) ? direct_video_->frame_fd() : -1;
}

bool Scene::update(float dt) {
    if (paused_ || mode_ == Mode::None) return false;
    dt = std::clamp(dt, 0.0f, 0.1f) * speed_;
    time_sec_ += dt;

    if (mode_ == Mode::Video) {
        return direct_video_ && direct_video_->update_gl();
    }
    if (mode_ != Mode::Scene) return false;

    // Update any embedded video-in-TEX decoders
    if (tex_cache_) tex_cache_->update_videos();

    // Smooth parallax cursor (convert top-left [0,1] -> bottom-left [-0.5, +0.5])
    glm::vec2 target(raw_cursor_.x - 0.5f, (1.0f - raw_cursor_.y) - 0.5f);
    float smooth_k = 1.0f - std::exp(-dt / std::max(0.01f, parallax_delay_));
    smooth_cursor_ += (target - smooth_cursor_) * smooth_k;

    // Cursor in scene world space (bottom-left origin [0..ortho_w, 0..ortho_h])
    glm::vec3 cursor_world(raw_cursor_.x * ortho_w_, (1.0f - raw_cursor_.y) * ortho_h_, 0.0f);

    for (auto& obj : objects_) {
        if (!obj.visible) continue;

        if (obj.kind == SceneObject::Kind::Image && obj.animated_sprite) {
            obj.sprite_time += dt;
        } else if (obj.kind == SceneObject::Kind::Particle && obj.particle_sys) {
            // Convert world cursor to particle local space
            glm::vec3 local_cursor = cursor_world - obj.origin;
            if (std::abs(obj.scale.x) > 1e-4f) local_cursor.x /= obj.scale.x;
            if (std::abs(obj.scale.y) > 1e-4f) local_cursor.y /= obj.scale.y;
            obj.particle_sys->update(dt, local_cursor);
        } else if (obj.kind == SceneObject::Kind::Text && obj.text_script && obj.text_script->valid()) {
            obj.text_value = obj.text_script->update_string(obj.text_value, dt, time_sec_);
        }
    }
    return true;
}

void Scene::render(int fb_width, int fb_height) {
    if (fb_width <= 0 || fb_height <= 0 || mode_ == Mode::None) return;
    ensure_common_gl();

    if (mode_ == Mode::Video) {
        if (direct_video_) {
            // The frame was uploaded in update(): every monitor draws the same one
            if (direct_video_->texture() == 0) direct_video_->update_gl();
            if (direct_video_->texture() != 0) {
                render_video_or_image(fb_width, fb_height, direct_video_->texture(),
                                      direct_video_->width(), direct_video_->height());
                return;
            }
        }
        glViewport(0, 0, fb_width, fb_height);
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        return;
    }

    if (mode_ == Mode::Image) {
        if (direct_image_) {
            render_video_or_image(fb_width, fb_height, direct_image_->gl_id(),
                                  direct_image_->img_width, direct_image_->img_height);
        }
        return;
    }

    render_scene(fb_width, fb_height);
}

void Scene::render_video_or_image(int fb_w, int fb_h, GLuint tex_id, int tex_w, int tex_h) {
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, fb_w, fb_h);
    glDisable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);

    // Where the picture lands (may be larger than the screen), then the part
    // of it that shows: that part of the texture, drawn into that viewport
    const float fw = static_cast<float>(fb_w), fh = static_cast<float>(fb_h);
    const float tw = static_cast<float>(std::max(1, tex_w)), th = static_cast<float>(std::max(1, tex_h));
    float dw = fw, dh = fh;
    if (fit_ == Fit::Fill || fit_ == Fit::Fit) {
        float s = fit_ == Fit::Fill ? std::max(fw / tw, fh / th) : std::min(fw / tw, fh / th);
        dw = tw * s;
        dh = th * s;
    } else if (fit_ == Fit::Center) {
        dw = tw;
        dh = th;
    }
    const float dx = (fw - dw) * 0.5f, dy = (fh - dh) * 0.5f;
    const float vx0 = std::max(0.0f, dx), vx1 = std::min(fw, dx + dw);
    const float vy0 = std::max(0.0f, dy), vy1 = std::min(fh, dy + dh);
    glm::vec2 uv_scale((vx1 - vx0) / dw, (vy1 - vy0) / dh);
    glm::vec2 uv_off((vx0 - dx) / dw, (vy0 - dy) / dh);

    if (vx0 > 0.0f || vy0 > 0.0f) {
        // Bars around a picture smaller than the screen
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
    }
    glViewport(static_cast<GLint>(vx0 + 0.5f), static_cast<GLint>(vy0 + 0.5f),
               static_cast<GLsizei>(vx1 - vx0 + 0.5f), static_cast<GLsizei>(vy1 - vy0 + 0.5f));

    glUseProgram(cover_prog_);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, tex_id);
    glUniform1i(glGetUniformLocation(cover_prog_, "u_tex"), 0);
    glUniform2fv(glGetUniformLocation(cover_prog_, "u_scale"), 1, glm::value_ptr(uv_scale));
    glUniform2fv(glGetUniformLocation(cover_prog_, "u_offset"), 1, glm::value_ptr(uv_off));

    glBindVertexArray(dummy_vao_);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glBindVertexArray(0);
}

void Scene::render_scene(int fb_w, int fb_h) {
    ensure_fbos(fb_w, fb_h);

    glBindFramebuffer(GL_FRAMEBUFFER, main_fbo_);
    glViewport(0, 0, fb_w, fb_h);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);

    if (clear_enabled_) {
        glClearColor(clear_color_.r, clear_color_.g, clear_color_.b, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
    }

    // Build camera matrices
    glm::mat4 proj(1.0f);
    glm::mat4 view(1.0f);
    glm::vec3 eye_pos(ortho_w_ * 0.5f, ortho_h_ * 0.5f, 1.0f);

    float screen_aspect = static_cast<float>(fb_w) / static_cast<float>(fb_h);
    if (is_ortho_) {
        float scene_aspect = ortho_w_ / std::max(1.0f, ortho_h_);
        float vis_w = ortho_w_;
        float vis_h = ortho_h_;
        // Fill crops the scene to the screen, fit shows all of it (the
        // clear color around it), stretch shows all of it squeezed
        if (fit_ == Fit::Fit) {
            if (screen_aspect > scene_aspect) vis_w = ortho_h_ * screen_aspect;
            else vis_h = ortho_w_ / screen_aspect;
        } else if (fit_ != Fit::Stretch) {
            if (screen_aspect > scene_aspect) vis_h = ortho_w_ / screen_aspect;
            else vis_w = ortho_h_ * screen_aspect;
        }
        vis_w /= std::max(0.01f, cam_zoom_);
        vis_h /= std::max(0.01f, cam_zoom_);

        glm::vec2 shake_off(0.0f);
        if (shake_enabled_ && shake_amp_ > 0.0f) {
            float t = static_cast<float>(time_sec_) * shake_speed_;
            shake_off.x = std::sin(t * 1.3f) * shake_amp_ * ortho_w_ * 0.01f;
            shake_off.y = std::cos(t * 1.7f) * shake_amp_ * ortho_h_ * 0.01f;
        }

        proj = glm::ortho(-vis_w * 0.5f, vis_w * 0.5f, -vis_h * 0.5f, vis_h * 0.5f, -10000.0f, 10000.0f);
        view = glm::translate(glm::mat4(1.0f),
                              glm::vec3(-ortho_w_ * 0.5f + shake_off.x, -ortho_h_ * 0.5f + shake_off.y, 0.0f));
    } else {
        proj = glm::perspective(glm::radians(cam_fov_), screen_aspect, cam_near_, cam_far_);
        view = glm::lookAt(cam_eye_, cam_center_, cam_up_);
        eye_pos = cam_eye_;
    }

    // Draw objects in scene order
    for (auto& obj : objects_) {
        if (!obj.visible) continue;

        if (obj.kind == SceneObject::Kind::Image) {
            draw_image_object(obj, view, proj, fb_w, fb_h);
        } else if (obj.kind == SceneObject::Kind::Particle && obj.particle_sys) {
            glm::vec3 pos = obj.origin;
            if (parallax_enabled_) {
                pos.x += smooth_cursor_.x * ortho_w_ * 0.15f * parallax_amount_ * parallax_mouse_inf_ * obj.parallax_depth.x;
                pos.y += smooth_cursor_.y * ortho_h_ * 0.15f * parallax_amount_ * parallax_mouse_inf_ * obj.parallax_depth.y;
            }
            glm::mat4 model = glm::translate(glm::mat4(1.0f), pos)
                            * make_euler_xyz(obj.angles)
                            * glm::scale(glm::mat4(1.0f), obj.scale);
            obj.particle_sys->render(model, view, proj, eye_pos, static_cast<float>(time_sec_), obj.alpha);
        } else if (obj.kind == SceneObject::Kind::Text) {
            draw_text_object(obj, view, proj);
        }
    }

    if (bloom_enabled_ && bloom_strength_ > 0.001f) {
        apply_bloom(fb_w, fb_h);
    } else {
        blit_tex_to_screen(main_tex_, fb_w, fb_h);
    }
}

void Scene::draw_image_object(SceneObject& obj, const glm::mat4& view, const glm::mat4& proj, int fb_w, int fb_h) {
    if (!obj.shader) return;

    // Copy current framebuffer when shader uses BLENDMODE or copybackground
    if (obj.color_blend_mode > 0 || obj.copy_background) {
        glBindFramebuffer(GL_READ_FRAMEBUFFER, main_fbo_);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, copy_fbo_);
        glBlitFramebuffer(0, 0, fb_w, fb_h, 0, 0, fb_w, fb_h, GL_COLOR_BUFFER_BIT, GL_NEAREST);
        glBindFramebuffer(GL_FRAMEBUFFER, main_fbo_);
    }

    // Check if object has active multi-pass effects
    bool has_fx = false;
    for (const auto& fx : obj.effects) {
        if (fx.visible && !fx.passes.empty()) { has_fx = true; break; }
    }

    // If fullscreen with effects & copybackground (like filmgrain), start from copy_tex_!
    if (obj.fullscreen && has_fx && obj.copy_background) {
        GLuint src_tex = copy_tex_;
        int dst_idx = 0;
        for (const auto& fx : obj.effects) {
            if (!fx.visible) continue;
            for (const auto& pass : fx.passes) {
                if (!pass.shader) continue;
                glBindFramebuffer(GL_FRAMEBUFFER, fx_fbo_[dst_idx]);
                glViewport(0, 0, fb_w, fb_h);
                glDisable(GL_BLEND);
                glUseProgram(pass.shader->program);

                // Identity fullscreen quad
                glm::mat4 mvp = glm::ortho(-0.5f, 0.5f, -0.5f, 0.5f, -1.0f, 1.0f);
                pass.shader->set_mat4("g_ModelViewProjectionMatrix", mvp);
                pass.shader->set_float("g_Time", static_cast<float>(time_sec_));
                pass.shader->set_vec3("g_Screen", glm::vec3(fb_w, fb_h, static_cast<float>(fb_w) / fb_h));
                pass.shader->set_vec4("g_Texture0Resolution", glm::vec4(fb_w, fb_h, fb_w, fb_h));
                pass.shader->set_vec4("g_Texture0Rotation", glm::vec4(1, 0, 0, 1));
                pass.shader->set_vec2("g_Texture0Translation", glm::vec2(0, 0));

                for (const auto& [un, um] : pass.shader->uniforms) {
                    if (!um.default_val.is_null() && um.type != "sampler2D") {
                        pass.shader->apply_json_uniform(un, um.default_val);
                    }
                }
                for (const auto& [mk, val] : pass.constants) {
                    auto it = pass.shader->material_to_uniform.find(to_lower_str(mk));
                    if (it != pass.shader->material_to_uniform.end()) {
                        pass.shader->apply_json_uniform(it->second, val);
                    }
                }

                // Bind slot 0 = src_tex (note: flip UV Y for FBO texture)
                glActiveTexture(GL_TEXTURE0);
                glBindTexture(GL_TEXTURE_2D, src_tex);
                pass.shader->set_int("g_Texture0", 0);

                for (size_t ti = 1; ti < pass.textures.size(); ++ti) {
                    glActiveTexture(GL_TEXTURE0 + static_cast<GLenum>(ti));
                    GLuint tid = tex_cache_->white()->gl_id();
                    int tw = 1, th = 1, iw = 1, ih = 1;
                    if (pass.slot_is_fb[ti]) {
                        tid = copy_tex_;
                        tw = iw = fb_w; th = ih = fb_h;
                    } else if (pass.textures[ti]) {
                        tid = pass.textures[ti]->gl_id();
                        tw = pass.textures[ti]->tex_width; th = pass.textures[ti]->tex_height;
                        iw = pass.textures[ti]->img_width; ih = pass.textures[ti]->img_height;
                    }
                    glBindTexture(GL_TEXTURE_2D, tid);
                    std::string sname = "g_Texture" + std::to_string(ti);
                    pass.shader->set_int(sname, static_cast<int>(ti));
                    pass.shader->set_vec4(sname + "Resolution", glm::vec4(tw, th, iw, ih));
                }

                // Fullscreen quad with FBO UVs (bottom-left 0,0 -> top-right 1,1)
                const float fbo_verts[] = {
                    -0.5f,  0.5f, 0.0f, 0.0f, 1.0f,
                     0.5f,  0.5f, 0.0f, 1.0f, 1.0f,
                     0.5f, -0.5f, 0.0f, 1.0f, 0.0f,
                    -0.5f,  0.5f, 0.0f, 0.0f, 1.0f,
                     0.5f, -0.5f, 0.0f, 1.0f, 0.0f,
                    -0.5f, -0.5f, 0.0f, 0.0f, 0.0f,
                };
                glBindBuffer(GL_ARRAY_BUFFER, quad_vbo_);
                glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(fbo_verts), fbo_verts);
                glBindVertexArray(quad_vao_);
                glDrawArrays(GL_TRIANGLES, 0, 6);
                glBindVertexArray(0);

                src_tex = fx_tex_[dst_idx];
                dst_idx = 1 - dst_idx;
            }
        }
        // Copy result back into main_fbo_
        glBindFramebuffer(GL_READ_FRAMEBUFFER, fx_fbo_[1 - dst_idx]);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, main_fbo_);
        glBlitFramebuffer(0, 0, fb_w, fb_h, 0, 0, fb_w, fb_h, GL_COLOR_BUFFER_BIT, GL_NEAREST);
        glBindFramebuffer(GL_FRAMEBUFFER, main_fbo_);
        return;
    }

    // Normal image object rendering
    glm::vec3 pos = obj.origin;
    if (parallax_enabled_) {
        pos.x += smooth_cursor_.x * ortho_w_ * 0.15f * parallax_amount_ * parallax_mouse_inf_ * obj.parallax_depth.x;
        pos.y += smooth_cursor_.y * ortho_h_ * 0.15f * parallax_amount_ * parallax_mouse_inf_ * obj.parallax_depth.y;
    }

    glm::vec2 sz = obj.size;
    if (obj.fullscreen) {
        pos = glm::vec3(ortho_w_ * 0.5f, ortho_h_ * 0.5f, 0.0f);
        sz = glm::vec2(ortho_w_, ortho_h_);
    }

    glm::mat4 model = glm::translate(glm::mat4(1.0f), pos)
                    * make_euler_xyz(obj.angles)
                    * glm::scale(glm::mat4(1.0f), glm::vec3(sz.x * obj.scale.x, sz.y * obj.scale.y, obj.scale.z));
    glm::mat4 mvp = proj * view * model;

    // Texture padding UV ratio (e.g. 411x326 inside 512x512 POT texture)
    float u_max = 1.0f, v_max = 1.0f;
    Texture* t0 = (!obj.textures.empty() && obj.textures[0]) ? obj.textures[0] : tex_cache_->white();
    GLuint active_tex0 = t0 ? t0->gl_id() : 0;
    bool active_tex0_is_fbo = false;

    if (t0 && t0->tex_width > 0 && t0->tex_height > 0 && !obj.animated_sprite) {
        u_max = static_cast<float>(t0->img_width) / static_cast<float>(t0->tex_width);
        v_max = static_cast<float>(t0->img_height) / static_cast<float>(t0->tex_height);
    }

    // Run per-object multi-pass effects chain into fx_fbo_[0/1]
    if (has_fx) {
        GLuint src_tex = active_tex0;
        bool src_is_fbo = false;
        int dst_idx = 0;
        glm::mat4 fx_mvp = glm::ortho(-0.5f, 0.5f, -0.5f, 0.5f, -1.0f, 1.0f);

        for (const auto& fx : obj.effects) {
            if (!fx.visible) continue;
            for (const auto& pass : fx.passes) {
                if (!pass.shader) continue;
                glBindFramebuffer(GL_FRAMEBUFFER, fx_fbo_[dst_idx]);
                glViewport(0, 0, fb_w, fb_h);
                glDisable(GL_BLEND);
                glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
                glClear(GL_COLOR_BUFFER_BIT);
                glUseProgram(pass.shader->program);

                pass.shader->set_mat4("g_ModelViewProjectionMatrix", fx_mvp);
                pass.shader->set_float("g_Time", static_cast<float>(time_sec_));
                pass.shader->set_vec3("g_Screen", glm::vec3(fb_w, fb_h, static_cast<float>(fb_w) / fb_h));
                pass.shader->set_vec4("g_Texture0Resolution",
                                      glm::vec4(t0 ? t0->tex_width : fb_w, t0 ? t0->tex_height : fb_h,
                                                t0 ? t0->img_width : fb_w, t0 ? t0->img_height : fb_h));
                pass.shader->set_vec4("g_Texture0Rotation", glm::vec4(1, 0, 0, 1));
                pass.shader->set_vec2("g_Texture0Translation", glm::vec2(0, 0));

                for (const auto& [un, um] : pass.shader->uniforms) {
                    if (!um.default_val.is_null() && um.type != "sampler2D") {
                        pass.shader->apply_json_uniform(un, um.default_val);
                    }
                }
                for (const auto& [mk, val] : pass.constants) {
                    auto it = pass.shader->material_to_uniform.find(to_lower_str(mk));
                    if (it != pass.shader->material_to_uniform.end()) {
                        pass.shader->apply_json_uniform(it->second, val);
                    }
                }

                glActiveTexture(GL_TEXTURE0);
                glBindTexture(GL_TEXTURE_2D, src_tex);
                pass.shader->set_int("g_Texture0", 0);

                for (size_t ti = 1; ti < pass.textures.size(); ++ti) {
                    glActiveTexture(GL_TEXTURE0 + static_cast<GLenum>(ti));
                    GLuint tid = tex_cache_->white()->gl_id();
                    int tw = 1, th = 1, iw = 1, ih = 1;
                    if (pass.slot_is_fb[ti]) {
                        tid = copy_tex_;
                        tw = iw = fb_w; th = ih = fb_h;
                    } else if (pass.textures[ti]) {
                        tid = pass.textures[ti]->gl_id();
                        tw = pass.textures[ti]->tex_width; th = pass.textures[ti]->tex_height;
                        iw = pass.textures[ti]->img_width; ih = pass.textures[ti]->img_height;
                    }
                    glBindTexture(GL_TEXTURE_2D, tid);
                    std::string sname = "g_Texture" + std::to_string(ti);
                    pass.shader->set_int(sname, static_cast<int>(ti));
                    pass.shader->set_vec4(sname + "Resolution", glm::vec4(tw, th, iw, ih));
                }

                float v_top = src_is_fbo ? 1.0f : 0.0f;
                float v_bot = src_is_fbo ? 0.0f : v_max;
                float u_rgt = src_is_fbo ? 1.0f : u_max;
                const float fx_verts[] = {
                    -0.5f,  0.5f, 0.0f, 0.0f,  v_top,
                     0.5f,  0.5f, 0.0f, u_rgt, v_top,
                     0.5f, -0.5f, 0.0f, u_rgt, v_bot,
                    -0.5f,  0.5f, 0.0f, 0.0f,  v_top,
                     0.5f, -0.5f, 0.0f, u_rgt, v_bot,
                    -0.5f, -0.5f, 0.0f, 0.0f,  v_bot,
                };
                glBindBuffer(GL_ARRAY_BUFFER, quad_vbo_);
                glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(fx_verts), fx_verts);
                glBindVertexArray(quad_vao_);
                glDrawArrays(GL_TRIANGLES, 0, 6);
                glBindVertexArray(0);

                src_tex = fx_tex_[dst_idx];
                src_is_fbo = true;
                dst_idx = 1 - dst_idx;
            }
        }
        glBindFramebuffer(GL_FRAMEBUFFER, main_fbo_);
        glViewport(0, 0, fb_w, fb_h);
        if (src_is_fbo) {
            active_tex0 = src_tex;
            active_tex0_is_fbo = true;
        }
    }

    float q_v_top = active_tex0_is_fbo ? 1.0f : 0.0f;
    float q_v_bot = active_tex0_is_fbo ? 0.0f : v_max;
    float q_u_rgt = active_tex0_is_fbo ? 1.0f : u_max;
    const float verts[] = {
        -0.5f,  0.5f, 0.0f, 0.0f,    q_v_top,
         0.5f,  0.5f, 0.0f, q_u_rgt, q_v_top,
         0.5f, -0.5f, 0.0f, q_u_rgt, q_v_bot,
        -0.5f,  0.5f, 0.0f, 0.0f,    q_v_top,
         0.5f, -0.5f, 0.0f, q_u_rgt, q_v_bot,
        -0.5f, -0.5f, 0.0f, 0.0f,    q_v_bot,
    };
    glBindBuffer(GL_ARRAY_BUFFER, quad_vbo_);
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(verts), verts);

    // If BLENDMODE is active, shader already outputs blended RGB with screen.a -> disable GL blend
    if (obj.color_blend_mode > 0) {
        glDisable(GL_BLEND);
    } else {
        set_gl_blend(obj.blending);
    }

    glUseProgram(obj.shader->program);
    obj.shader->set_mat4("g_ModelViewProjectionMatrix", mvp);
    obj.shader->set_mat4("g_ModelMatrix", model);
    obj.shader->set_mat4("g_ViewProjectionMatrix", proj * view);
    obj.shader->set_vec4("g_Color4", glm::vec4(obj.color * obj.brightness, obj.alpha));
    obj.shader->set_float("g_Brightness", obj.brightness);
    obj.shader->set_float("g_UserAlpha", obj.alpha);
    obj.shader->set_float("g_Time", static_cast<float>(time_sec_));
    obj.shader->set_vec3("g_Screen", glm::vec3(fb_w, fb_h, static_cast<float>(fb_w) / fb_h));

    // Spritesheet UV transform for animated image layers
    if (obj.animated_sprite && t0 && !t0->frames.empty()) {
        float total_dur = 0.0f;
        for (const auto& fr : t0->frames) total_dur += std::max(0.01f, fr.frametime);
        float tmod = std::fmod(obj.sprite_time, std::max(0.01f, total_dur));
        size_t fi = 0;
        float acc = 0.0f;
        for (size_t i = 0; i < t0->frames.size(); ++i) {
            acc += std::max(0.01f, t0->frames[i].frametime);
            if (tmod < acc) { fi = i; break; }
        }
        const auto& fr = t0->frames[fi];
        float tw = static_cast<float>(std::max(1, t0->tex_width));
        float th = static_cast<float>(std::max(1, t0->tex_height));
        obj.shader->set_vec2("g_Texture0Translation", glm::vec2(fr.x / tw, fr.y / th));
        obj.shader->set_vec4("g_Texture0Rotation", glm::vec4(fr.width / tw, fr.width_y / th, fr.height_x / tw, fr.height / th));
    } else {
        obj.shader->set_vec2("g_Texture0Translation", glm::vec2(0.0f, 0.0f));
        obj.shader->set_vec4("g_Texture0Rotation", glm::vec4(1.0f, 0.0f, 0.0f, 1.0f));
    }

    // Uniform defaults & material constantshadervalues
    for (const auto& [un, um] : obj.shader->uniforms) {
        if (!um.default_val.is_null() && um.type != "sampler2D") {
            obj.shader->apply_json_uniform(un, um.default_val);
        }
    }
    for (const auto& [mk, val] : obj.material_constants) {
        auto it = obj.shader->material_to_uniform.find(to_lower_str(mk));
        if (it != obj.shader->material_to_uniform.end()) {
            obj.shader->apply_json_uniform(it->second, val);
        }
    }

    // Bind textures
    for (size_t i = 0; i < obj.textures.size(); ++i) {
        Texture* tex = obj.textures[i] ? obj.textures[i] : tex_cache_->white();
        glActiveTexture(GL_TEXTURE0 + static_cast<GLenum>(i));
        glBindTexture(GL_TEXTURE_2D, (i == 0 && active_tex0_is_fbo) ? active_tex0 : tex->gl_id());
        std::string sn = "g_Texture" + std::to_string(i);
        obj.shader->set_int(sn, static_cast<int>(i));
        obj.shader->set_vec4(sn + "Resolution",
                             glm::vec4(tex->tex_width, tex->tex_height, tex->img_width, tex->img_height));
    }

    // Bind _rt_FullFrameBuffer to g_Texture4 when BLENDMODE > 0
    if (obj.color_blend_mode > 0) {
        glActiveTexture(GL_TEXTURE4);
        glBindTexture(GL_TEXTURE_2D, copy_tex_);
        obj.shader->set_int("g_Texture4", 4);
    }

    glBindVertexArray(quad_vao_);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    glBindVertexArray(0);
}

void Scene::draw_text_object(SceneObject& obj, const glm::mat4& view, const glm::mat4& proj) {
    if (obj.text_value != obj.rendered_text || obj.text_tex == 0) {
        int bw = static_cast<int>(std::max(64.0f, obj.size.x));
        int bh = static_cast<int>(std::max(32.0f, obj.size.y));
        if (text_renderer_.render_to_texture(vfs_, obj.font, obj.point_size, obj.text_value,
                                             bw, bh, obj.halign, obj.valign,
                                             obj.text_tex, obj.text_tex_w, obj.text_tex_h)) {
            obj.rendered_text = obj.text_value;
        }
    }
    if (!obj.text_tex) return;

    glm::vec3 pos = obj.origin;
    if (parallax_enabled_) {
        pos.x += smooth_cursor_.x * ortho_w_ * 0.15f * parallax_amount_ * parallax_mouse_inf_ * obj.parallax_depth.x;
        pos.y += smooth_cursor_.y * ortho_h_ * 0.15f * parallax_amount_ * parallax_mouse_inf_ * obj.parallax_depth.y;
    }

    float w = static_cast<float>(obj.text_tex_w);
    float h = static_cast<float>(obj.text_tex_h);
    glm::mat4 model = glm::translate(glm::mat4(1.0f), pos)
                    * make_euler_xyz(obj.angles)
                    * glm::scale(glm::mat4(1.0f), glm::vec3(w * obj.scale.x, h * obj.scale.y, 1.0f));
    glm::mat4 mvp = proj * view * model;

    const float verts[] = {
        -0.5f,  0.5f, 0.0f, 0.0f, 0.0f,
         0.5f,  0.5f, 0.0f, 1.0f, 0.0f,
         0.5f, -0.5f, 0.0f, 1.0f, 1.0f,
        -0.5f,  0.5f, 0.0f, 0.0f, 0.0f,
         0.5f, -0.5f, 0.0f, 1.0f, 1.0f,
        -0.5f, -0.5f, 0.0f, 0.0f, 1.0f,
    };
    glBindBuffer(GL_ARRAY_BUFFER, quad_vbo_);
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(verts), verts);

    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glUseProgram(text_prog_);
    glUniformMatrix4fv(glGetUniformLocation(text_prog_, "u_mvp"), 1, GL_FALSE, glm::value_ptr(mvp));
    glUniform4f(glGetUniformLocation(text_prog_, "u_color"), obj.color.r, obj.color.g, obj.color.b, obj.alpha);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, obj.text_tex);
    glUniform1i(glGetUniformLocation(text_prog_, "u_tex"), 0);

    glBindVertexArray(quad_vao_);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    glBindVertexArray(0);
}

void Scene::apply_bloom(int fb_w, int fb_h) {
    int bw = std::max(1, fb_w / 4);
    int bh = std::max(1, fb_h / 4);
    glDisable(GL_BLEND);

    // 1. Bright extract -> bloom_fbo_[0]
    glBindFramebuffer(GL_FRAMEBUFFER, bloom_fbo_[0]);
    glViewport(0, 0, bw, bh);
    glUseProgram(bloom_extract_prog_);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, main_tex_);
    glUniform1i(glGetUniformLocation(bloom_extract_prog_, "u_tex"), 0);
    glUniform1f(glGetUniformLocation(bloom_extract_prog_, "u_threshold"), bloom_threshold_);
    glBindVertexArray(dummy_vao_);
    glDrawArrays(GL_TRIANGLES, 0, 3);

    // 2. Separable blur (2 iterations)
    glUseProgram(bloom_blur_prog_);
    glUniform1i(glGetUniformLocation(bloom_blur_prog_, "u_tex"), 0);
    for (int it = 0; it < 2; ++it) {
        glBindFramebuffer(GL_FRAMEBUFFER, bloom_fbo_[1]);
        glBindTexture(GL_TEXTURE_2D, bloom_tex_[0]);
        glUniform2f(glGetUniformLocation(bloom_blur_prog_, "u_dir"), 1.5f / bw, 0.0f);
        glDrawArrays(GL_TRIANGLES, 0, 3);

        glBindFramebuffer(GL_FRAMEBUFFER, bloom_fbo_[0]);
        glBindTexture(GL_TEXTURE_2D, bloom_tex_[1]);
        glUniform2f(glGetUniformLocation(bloom_blur_prog_, "u_dir"), 0.0f, 1.5f / bh);
        glDrawArrays(GL_TRIANGLES, 0, 3);
    }

    // 3. Combine main_tex_ + bloom_tex_[0] -> screen FBO 0
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, fb_w, fb_h);
    glUseProgram(bloom_add_prog_);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, main_tex_);
    glUniform1i(glGetUniformLocation(bloom_add_prog_, "u_scene"), 0);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, bloom_tex_[0]);
    glUniform1i(glGetUniformLocation(bloom_add_prog_, "u_bloom"), 1);
    glUniform1f(glGetUniformLocation(bloom_add_prog_, "u_strength"), bloom_strength_ * 0.5f);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glBindVertexArray(0);
}

void Scene::blit_tex_to_screen(GLuint tex_id, int fb_w, int fb_h) {
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, fb_w, fb_h);
    glDisable(GL_BLEND);
    glUseProgram(blit_prog_);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, tex_id);
    glUniform1i(glGetUniformLocation(blit_prog_, "u_tex"), 0);
    glBindVertexArray(dummy_vao_);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glBindVertexArray(0);
}

} // namespace sw
