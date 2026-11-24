#pragma once

#include "json.hpp"
#include "particles.hpp"
#include "script.hpp"
#include "shader.hpp"
#include "tex.hpp"
#include "text.hpp"
#include "vfs.hpp"
#include "video.hpp"

#include <GL/gl.h>
#include <filesystem>
#include <glm/glm.hpp>
#include <map>
#include <memory>
#include <string>
#include <vector>

namespace sw {

struct PropBinding {
    std::string user_key;
    std::string condition;
    bool has_condition = false;
    Json fallback;
};

struct EffectPass {
    CompiledShader* shader = nullptr;
    std::string blending = "normal";
    std::vector<Texture*> textures; // slot 0 is usually previous pass output (nullptr)
    std::vector<bool> slot_is_fb;   // true if slot should bind _rt_FullFrameBuffer
    std::map<std::string, Json> constants;
};

struct ImageEffect {
    bool visible = true;
    PropBinding visible_bind;
    std::vector<EffectPass> passes;
};

struct SceneObject {
    enum class Kind { Image, Particle, Text };
    Kind kind = Kind::Image;

    int id = 0;
    std::string name;
    bool visible = true;
    PropBinding visible_bind;

    glm::vec3 origin{0.0f};
    glm::vec3 scale{1.0f};
    glm::vec3 angles{0.0f}; // radians (pitch, yaw, roll)
    glm::vec2 size{100.0f, 100.0f};
    glm::vec2 parallax_depth{0.0f, 0.0f};
    glm::vec3 color{1.0f};
    float alpha = 1.0f;
    float brightness = 1.0f;
    int color_blend_mode = 0;
    bool copy_background = false;
    bool fullscreen = false;
    std::string alignment = "center";

    PropBinding color_bind;
    PropBinding alpha_bind;
    PropBinding scale_bind;

    // Image-specific
    CompiledShader* shader = nullptr;
    std::string blending = "translucent";
    std::vector<Texture*> textures;
    std::map<std::string, Json> material_constants;
    std::map<std::string, std::string> user_shader_values;
    std::vector<ImageEffect> effects;
    bool animated_sprite = false;
    float sprite_time = 0.0f;

    // Particle-specific
    std::unique_ptr<ParticleSystem> particle_sys;

    // Text-specific
    std::string font;
    float point_size = 32.0f;
    std::string halign = "center";
    std::string valign = "center";
    std::string text_value;
    std::string rendered_text;
    std::unique_ptr<PropertyScript> text_script;
    GLuint text_tex = 0;
    int text_tex_w = 0;
    int text_tex_h = 0;

    ~SceneObject();
    SceneObject() = default;
    SceneObject(SceneObject&&) = default;
    SceneObject& operator=(SceneObject&&) = default;
};

class Scene {
public:
    Scene() = default;
    ~Scene();

    void set_assets_dir(const std::filesystem::path& assets_dir);

    // Load a Wallpaper Engine wallpaper directory (containing project.json),
    // or directly a video/image file.
    bool load(const std::filesystem::path& path);
    void unload();

    // Runtime controls
    void set_user_property(const std::string& key, const Json& val);
    void set_paused(bool paused);
    void set_cursor(float norm_x, float norm_y); // [0..1] top-left origin

    // How the picture meets the screen: fill (crop, default), fit (whole,
    // bars), stretch, center (native size; scenes treat it as fill)
    enum class Fit { Fill, Fit, Stretch, Center };
    static Fit parse_fit(const std::string& s);
    void set_fit(Fit f) { fit_ = f; }
    // Playback speed (0.1..4): scene time and video frame pacing
    void set_speed(float speed);

    // Steps the wallpaper. True when the picture changed and must be drawn
    // again: always for a scene, only on a new frame for a video, never for an image
    bool update(float dt);
    void render(int fb_width, int fb_height);

    // Whether anything reads the cursor (camera parallax, particles linked to
    // the mouse): without it, the cursor is never asked for
    bool uses_cursor() const;
    // For a plain video: readable when its next frame is ready (else -1)
    int wake_fd() const;
    // A plain video or image: drawn only when it changes, not on a timer
    // Which decoders play its videos ("" without video)
    std::string video_decoders() const;
    bool is_static_paced() const { return mode_ == Mode::Video || mode_ == Mode::Image; }

    bool is_loaded() const { return mode_ != Mode::None; }
    std::string title() const { return title_; }
    std::string type() const { return type_str_; }
    // Why the last load failed, in words for the user ("" when it did not fail
    // or there is nothing more to say)
    std::string error() const { return error_; }

private:
    enum class Mode { None, Scene, Video, Image };

    bool load_scene(const Json& proj_json, const std::string& scene_file);
    bool load_video(const std::filesystem::path& video_path);
    bool load_image(const std::filesystem::path& image_path);

    Json resolve_binding(const PropBinding& b) const;
    PropBinding parse_binding(const Json& j) const;
    void refresh_user_properties();

    void ensure_common_gl();
    void ensure_fbos(int w, int h);
    void render_scene(int fb_w, int fb_h);
    void render_video_or_image(int fb_w, int fb_h, GLuint tex_id, int tex_w, int tex_h);
    void draw_image_object(SceneObject& obj, const glm::mat4& view, const glm::mat4& proj, int fb_w, int fb_h);
    void draw_text_object(SceneObject& obj, const glm::mat4& view, const glm::mat4& proj);
    void apply_bloom(int fb_w, int fb_h);
    void blit_tex_to_screen(GLuint tex_id, int fb_w, int fb_h);

    Vfs vfs_;
    std::unique_ptr<TextureCache> tex_cache_;
    std::unique_ptr<ShaderCache> shader_cache_;
    TextRenderer text_renderer_;

    Mode mode_ = Mode::None;
    std::string title_;
    std::string type_str_;
    std::string error_;
    std::filesystem::path assets_dir_;

    // User properties from project.json + runtime overrides
    std::map<std::string, Json> user_props_;

    // Video / Static image mode
    std::unique_ptr<VideoDecoder> direct_video_;
    Texture* direct_image_ = nullptr;

    // Scene general parameters
    bool is_ortho_ = true;
    float ortho_w_ = 1920.0f;
    float ortho_h_ = 1080.0f;
    glm::vec3 clear_color_{0.0f};
    bool clear_enabled_ = true;
    glm::vec3 cam_eye_{0.0f, 0.0f, 1.0f};
    glm::vec3 cam_center_{0.0f, 0.0f, 0.0f};
    glm::vec3 cam_up_{0.0f, 1.0f, 0.0f};
    float cam_fov_ = 50.0f;
    float cam_near_ = 0.01f;
    float cam_far_ = 10000.0f;
    float cam_zoom_ = 1.0f;

    bool parallax_enabled_ = false;
    float parallax_amount_ = 0.5f;
    float parallax_delay_ = 0.1f;
    float parallax_mouse_inf_ = 0.5f;

    bool shake_enabled_ = false;
    float shake_amp_ = 0.0f;
    float shake_speed_ = 1.0f;

    bool bloom_enabled_ = false;
    float bloom_threshold_ = 0.65f;
    float bloom_strength_ = 1.0f;

    std::vector<SceneObject> objects_;

    // Runtime state
    Fit fit_ = Fit::Fill;
    float speed_ = 1.0f;
    double time_sec_ = 0.0;
    bool paused_ = false;
    glm::vec2 raw_cursor_{0.5f, 0.5f};     // normalized [0,1] top-left
    glm::vec2 smooth_cursor_{0.0f, 0.0f};  // [-0.5, +0.5] bottom-left

    // Common GL resources
    GLuint quad_vao_ = 0;
    GLuint quad_vbo_ = 0;
    GLuint dummy_vao_ = 0;
    GLuint blit_prog_ = 0;
    GLuint cover_prog_ = 0;
    GLuint text_prog_ = 0;
    GLuint bloom_extract_prog_ = 0;
    GLuint bloom_blur_prog_ = 0;
    GLuint bloom_add_prog_ = 0;

    // Scene FBOs (main render target + copy for _rt_FullFrameBuffer + effect ping-pong + bloom)
    int fbo_w_ = 0;
    int fbo_h_ = 0;
    GLuint main_fbo_ = 0, main_tex_ = 0;
    GLuint copy_fbo_ = 0, copy_tex_ = 0;
    GLuint fx_fbo_[2] = {0, 0};
    GLuint fx_tex_[2] = {0, 0};
    GLuint bloom_fbo_[2] = {0, 0};
    GLuint bloom_tex_[2] = {0, 0};
};

} // namespace sw
