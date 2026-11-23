#pragma once

#include "json.hpp"
#include "shader.hpp"
#include "tex.hpp"
#include "vfs.hpp"

#include <GL/gl.h>
#include <glm/glm.hpp>
#include <map>
#include <string>
#include <vector>

namespace sw {

struct ParticleInstanceOverride {
    glm::vec3 color_mul{1.0f};
    float alpha_mul = 1.0f;
    float size_mul = 1.0f;
    float rate_mul = 1.0f;
    float speed_mul = 1.0f;
    float count_mul = 1.0f;
    float lifetime_mul = 1.0f;
    float brightness_mul = 1.0f;
};

struct ParticleSystem {
    bool load(const Vfs& vfs,
              TextureCache& tex_cache,
              ShaderCache& shader_cache,
              const std::string& particle_path,
              const ParticleInstanceOverride& overrides,
              const std::map<std::string, Json>& user_props);

    void set_user_props(const std::map<std::string, Json>& user_props);

    void update(float dt, const glm::vec3& cursor_local);
    void render(const glm::mat4& model,
                const glm::mat4& view,
                const glm::mat4& proj,
                const glm::vec3& eye_pos,
                float time_sec,
                float alpha_scale);

    // A control point follows the mouse
    bool uses_mouse() const;

    ~ParticleSystem();
    ParticleSystem() = default;
    ParticleSystem(const ParticleSystem&) = delete;
    ParticleSystem& operator=(const ParticleSystem&) = delete;

private:
    struct Particle {
        glm::vec3 pos{0.0f};
        glm::vec3 vel{0.0f};
        glm::vec3 rot{0.0f};
        glm::vec3 ang_vel{0.0f};
        glm::vec3 init_color{1.0f};
        glm::vec3 color{1.0f};
        float init_alpha = 1.0f;
        float alpha = 1.0f;
        float init_size = 20.0f;
        float size = 20.0f;
        float lifetime = 1.0f;
        float age = 0.0f;
        float frame_offset = 0.0f;
        bool alive = false;
    };

    struct ControlPoint {
        int id = 0;
        uint32_t flags = 0; // bit 0 = link to mouse, bit 1 = world space
        glm::vec3 offset{0.0f};
        glm::vec3 pos{0.0f};
    };

    struct Emitter {
        std::string name;
        int control_point = 0;
        float rate = 5.0f;
        int instantaneous = 0;
        float distance_min = 0.0f;
        float distance_max = 0.0f;
        glm::vec3 directions{1.0f, 1.0f, 0.0f};
        glm::vec3 origin{0.0f};
        glm::vec3 area_min{0.0f};
        glm::vec3 area_max{0.0f};
        float speed_min = 0.0f;
        float speed_max = 0.0f;
        float accum = 0.0f;
        bool spawned_instant = false;
    };

    struct Initializer {
        std::string name;
        Json config;
    };

    struct Operator {
        std::string name;
        Json config;
    };

    void spawn_particle(const Emitter& em);
    void init_particle(Particle& p, const Emitter& em);
    void ensure_gl();

    int max_count_ = 100;
    float start_time_ = 0.0f;
    float sequence_mul_ = 1.0f;
    bool random_frame_ = false;
    bool trail_renderer_ = false;
    float trail_length_ = 0.05f;
    float trail_max_len_ = 100.0f;
    float trail_min_len_ = 0.0f;

    ParticleInstanceOverride overrides_;
    std::vector<ControlPoint> control_points_;
    std::vector<Emitter> emitters_;
    std::vector<Initializer> initializers_;
    std::vector<Operator> operators_;
    std::vector<Particle> particles_;

    // Material / shader
    CompiledShader* shader_ = nullptr;
    Texture* texture0_ = nullptr;
    std::string blending_ = "translucent";
    std::map<std::string, Json> constant_uniforms_;
    std::map<std::string, std::string> user_shader_values_; // user_prop_key -> material_key
    bool use_spritesheet_ = false;

    // Dynamic GL buffers
    GLuint vao_ = 0;
    GLuint vbo_ = 0;
    GLuint ebo_ = 0;
    size_t max_quads_alloc_ = 0;
    bool warmed_up_ = false;
};

} // namespace sw
