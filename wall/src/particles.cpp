#include "particles.hpp"

#include <GL/glext.h>
#include <glm/gtc/constants.hpp>

#include <algorithm>
#include <cmath>
#include <iostream>
#include <random>

namespace sw {

namespace {

thread_local std::mt19937 g_rng(std::random_device{}());

float rand01() {
    static thread_local std::uniform_real_distribution<float> dist(0.0f, 1.0f);
    return dist(g_rng);
}

float rand_range(float a, float b) {
    if (a > b) std::swap(a, b);
    return a + (b - a) * rand01();
}

glm::vec3 rand_vec3(const glm::vec3& a, const glm::vec3& b) {
    return glm::vec3(rand_range(a.x, b.x), rand_range(a.y, b.y), rand_range(a.z, b.z));
}

float lerp_f(float a, float b, float t) {
    return a + (b - a) * std::clamp(t, 0.0f, 1.0f);
}

// Lightweight smooth 3D hash-noise for turbulence operator
float hash3(int x, int y, int z) {
    int n = x * 374761393 + y * 668265263 + z * 1274126177;
    n = (n ^ (n >> 13)) * 1274126177;
    return static_cast<float>((n ^ (n >> 16)) & 0x7fffffff) / 2147483647.0f * 2.0f - 1.0f;
}

float vnoise3(const glm::vec3& p) {
    int ix = static_cast<int>(std::floor(p.x));
    int iy = static_cast<int>(std::floor(p.y));
    int iz = static_cast<int>(std::floor(p.z));
    float fx = p.x - ix; fx = fx * fx * (3.0f - 2.0f * fx);
    float fy = p.y - iy; fy = fy * fy * (3.0f - 2.0f * fy);
    float fz = p.z - iz; fz = fz * fz * (3.0f - 2.0f * fz);
    float c000 = hash3(ix, iy, iz),     c100 = hash3(ix+1, iy, iz);
    float c010 = hash3(ix, iy+1, iz),   c110 = hash3(ix+1, iy+1, iz);
    float c001 = hash3(ix, iy, iz+1),   c101 = hash3(ix+1, iy, iz+1);
    float c011 = hash3(ix, iy+1, iz+1), c111 = hash3(ix+1, iy+1, iz+1);
    float x00 = lerp_f(c000, c100, fx), x10 = lerp_f(c010, c110, fx);
    float x01 = lerp_f(c001, c101, fx), x11 = lerp_f(c011, c111, fx);
    return lerp_f(lerp_f(x00, x10, fy), lerp_f(x01, x11, fy), fz);
}

struct ParticleVertex {
    float px, py, pz;       // loc 0: a_Position
    float u, v, rotz, size; // loc 1: a_TexCoordVec4
    float r, g, b, a;       // loc 2: a_Color
    float rotx, roty;       // loc 3: a_TexCoordC2
    float vx, vy, vz, life; // loc 4: a_TexCoordVec4C1
};

} // namespace

ParticleSystem::~ParticleSystem() {
    if (ebo_) glDeleteBuffers(1, &ebo_);
    if (vbo_) glDeleteBuffers(1, &vbo_);
    if (vao_) glDeleteVertexArrays(1, &vao_);
}

bool ParticleSystem::load(const Vfs& vfs,
                          TextureCache& tex_cache,
                          ShaderCache& shader_cache,
                          const std::string& particle_path,
                          const ParticleInstanceOverride& overrides,
                          const std::map<std::string, Json>& user_props) {
    overrides_ = overrides;
    auto text = vfs.read_text(particle_path);
    if (!text) {
        std::cerr << "[particles] missing: " << particle_path << "\n";
        return false;
    }

    Json pj = Json::parse(*text);
    if (!pj.is_object()) return false;

    max_count_ = std::max(1, static_cast<int>(pj["maxcount"].as_int(100) * overrides_.count_mul));
    start_time_ = pj["starttime"].as_float(0.0f);
    sequence_mul_ = pj["sequencemultiplier"].as_float(1.0f);
    random_frame_ = (pj["flags"].as_int(0) & 2) != 0;

    // Control points
    control_points_.clear();
    for (const auto& cpj : pj["controlpoint"].as_array()) {
        ControlPoint cp;
        cp.id = cpj["id"].as_int(0);
        cp.flags = static_cast<uint32_t>(cpj["flags"].as_int(0));
        cp.offset = cpj["offset"].as_vec3(glm::vec3(0.0f));
        cp.pos = cp.offset;
        control_points_.push_back(cp);
    }
    if (control_points_.empty()) {
        control_points_.push_back(ControlPoint{});
    }

    // Emitters
    emitters_.clear();
    for (const auto& ej : pj["emitter"].as_array()) {
        Emitter em;
        em.name = ej["name"].as_string("sphererandom");
        em.control_point = ej["controlpoint"].as_int(0);
        em.rate = ej["rate"].as_float(5.0f) * overrides_.rate_mul;
        em.instantaneous = static_cast<int>(ej["instantaneous"].as_int(0) * overrides_.count_mul);
        em.distance_min = ej["distancemin"].as_float(0.0f);
        em.distance_max = ej["distancemax"].as_float(0.0f);
        em.directions = ej["directions"].as_vec3(glm::vec3(1.0f, 1.0f, 0.0f));
        em.origin = ej["origin"].as_vec3(glm::vec3(0.0f));
        em.area_min = ej["distancemin"].as_vec3(glm::vec3(0.0f));
        em.area_max = ej["distancemax"].as_vec3(glm::vec3(0.0f));
        em.speed_min = ej["speedmin"].as_float(0.0f);
        em.speed_max = ej["speedmax"].as_float(0.0f);
        emitters_.push_back(em);
    }

    // Initializers
    initializers_.clear();
    for (const auto& ij : pj["initializer"].as_array()) {
        initializers_.push_back({ij["name"].as_string(), ij});
    }

    // Operators
    operators_.clear();
    for (const auto& oj : pj["operator"].as_array()) {
        operators_.push_back({oj["name"].as_string(), oj});
    }

    // Renderer
    for (const auto& rj : pj["renderer"].as_array()) {
        std::string rname = rj["name"].as_string("sprite");
        if (rname == "spritetrail") {
            trail_renderer_ = true;
            trail_length_ = rj["length"].as_float(0.05f);
            trail_max_len_ = rj["maxlength"].as_float(100.0f);
            trail_min_len_ = rj["minlength"].as_float(0.0f);
        }
    }

    // Material
    std::string mat_path = pj["material"].as_string();
    std::string shader_name = "genericparticle";
    std::map<std::string, int> combos;
    std::string tex0_name;

    if (!mat_path.empty()) {
        if (auto mtxt = vfs.read_text(mat_path)) {
            Json mj = Json::parse(*mtxt);
            const auto& passes = mj["passes"].as_array();
            if (!passes.empty()) {
                const auto& pass = passes[0];
                shader_name = pass["shader"].as_string("genericparticle");
                blending_ = pass["blending"].as_string("translucent");
                const auto& textures = pass["textures"].as_array();
                if (!textures.empty() && textures[0].is_string()) {
                    tex0_name = textures[0].as_string();
                }
                for (const auto& [ck, cv] : pass["combos"].as_object()) {
                    combos[ck] = cv.as_int(0);
                }
                for (const auto& [uk, uv] : pass["constantshadervalues"].as_object()) {
                    constant_uniforms_[uk] = uv;
                }
                for (const auto& [uk, mk] : pass["usershadervalues"].as_object()) {
                    if (mk.is_string()) user_shader_values_[uk] = mk.as_string();
                }
            }
        }
    }

    set_user_props(user_props);

    texture0_ = tex_cache.load(tex0_name);
    use_spritesheet_ = (texture0_ && texture0_->is_spritesheet && !texture0_->frames.empty());

    // Always use non-GS quad path (works everywhere including GLES/Adreno)
    combos["GS_ENABLED"] = 0;
    if (texture0_) {
        combos["TEX0FORMAT"] = static_cast<int>(texture0_->format);
    }
    if (use_spritesheet_) {
        combos["SPRITESHEET"] = 1;
        combos["SPRITESHEETBLEND"] = 1;
        combos["THICKFORMAT"] = 1;
    }
    if (trail_renderer_) {
        combos["TRAILRENDERER"] = 1;
        combos["THICKFORMAT"] = 1;
    }

    shader_ = shader_cache.get(shader_name, combos);
    particles_.assign(static_cast<size_t>(max_count_), Particle{});
    return shader_ != nullptr;
}

void ParticleSystem::set_user_props(const std::map<std::string, Json>& user_props) {
    for (const auto& [up_key, mat_key] : user_shader_values_) {
        auto it = user_props.find(up_key);
        if (it != user_props.end()) {
            constant_uniforms_[mat_key] = it->second;
        }
    }
}

void ParticleSystem::init_particle(Particle& p, const Emitter& em) {
    p = Particle{};
    p.alive = true;
    p.age = 0.0f;
    p.lifetime = 1.0f;
    p.init_size = 20.0f;
    p.init_alpha = 1.0f;
    p.init_color = glm::vec3(1.0f);
    p.frame_offset = random_frame_ ? rand01() : 0.0f;

    glm::vec3 base_pos = em.origin;
    if (em.control_point >= 0 && em.control_point < static_cast<int>(control_points_.size())) {
        base_pos += control_points_[em.control_point].pos;
    }

    if (em.name == "boxrandom") {
        glm::vec3 off = rand_vec3(em.area_min, em.area_max);
        p.pos = base_pos + off;
    } else {
        // sphererandom: random unit vector scaled by ellipsoid directions and radius
        glm::vec3 dir(rand_range(-1.0f, 1.0f), rand_range(-1.0f, 1.0f), rand_range(-1.0f, 1.0f));
        float len = glm::length(dir);
        if (len > 1e-5f) dir /= len;
        else dir = glm::vec3(1.0f, 0.0f, 0.0f);
        glm::vec3 scaled_dir = dir * em.directions;
        float dist = rand_range(em.distance_min, em.distance_max);
        p.pos = base_pos + scaled_dir * dist;
        if (em.speed_max > 0.0f || em.speed_min > 0.0f) {
            p.vel += scaled_dir * rand_range(em.speed_min, em.speed_max);
        }
    }

    for (const auto& init : initializers_) {
        const auto& c = init.config;
        if (init.name == "lifetimerandom") {
            p.lifetime = std::max(0.05f, rand_range(c["min"].as_float(1.0f), c["max"].as_float(1.0f)));
        } else if (init.name == "sizerandom") {
            p.init_size = rand_range(c["min"].as_float(20.0f), c["max"].as_float(20.0f));
        } else if (init.name == "velocityrandom") {
            p.vel += rand_vec3(c["min"].as_vec3(glm::vec3(0.0f)), c["max"].as_vec3(glm::vec3(0.0f)));
        } else if (init.name == "turbulentvelocityrandom") {
            float spd = rand_range(c["speedmin"].as_float(10.0f), c["speedmax"].as_float(50.0f));
            glm::vec3 d(rand_range(-1.0f, 1.0f), rand_range(-1.0f, 1.0f), 0.0f);
            float l = glm::length(d);
            if (l > 1e-4f) d /= l;
            p.vel += d * spd;
        } else if (init.name == "colorrandom") {
            glm::vec3 mn = c["min"].as_vec3(glm::vec3(255.0f)) / 255.0f;
            glm::vec3 mx = c["max"].as_vec3(glm::vec3(255.0f)) / 255.0f;
            float t = rand01();
            p.init_color = glm::mix(mn, mx, t);
        } else if (init.name == "alpharandom") {
            p.init_alpha = rand_range(c["min"].as_float(1.0f), c["max"].as_float(1.0f));
        } else if (init.name == "rotationrandom") {
            glm::vec3 mn = c["min"].as_vec3(glm::vec3(0.0f, 0.0f, 0.0f));
            glm::vec3 mx = c["max"].as_vec3(glm::vec3(0.0f, 0.0f, glm::two_pi<float>()));
            p.rot = rand_vec3(mn, mx);
        } else if (init.name == "angularvelocityrandom") {
            glm::vec3 mn = c["min"].as_vec3(glm::vec3(0.0f, 0.0f, -1.0f));
            glm::vec3 mx = c["max"].as_vec3(glm::vec3(0.0f, 0.0f, 1.0f));
            p.ang_vel = rand_vec3(mn, mx);
        } else if (init.name == "positionoffsetrandom") {
            p.pos += rand_vec3(c["min"].as_vec3(glm::vec3(0.0f)), c["max"].as_vec3(glm::vec3(0.0f)));
        }
    }

    // Apply instance overrides
    p.lifetime *= overrides_.lifetime_mul;
    p.init_size *= overrides_.size_mul;
    p.init_alpha *= overrides_.alpha_mul;
    p.init_color *= overrides_.color_mul * overrides_.brightness_mul;
    p.vel *= overrides_.speed_mul;

    p.size = p.init_size;
    p.alpha = p.init_alpha;
    p.color = p.init_color;
}

void ParticleSystem::spawn_particle(const Emitter& em) {
    for (auto& p : particles_) {
        if (!p.alive) {
            init_particle(p, em);
            return;
        }
    }
}

void ParticleSystem::update(float dt, const glm::vec3& cursor_local) {
    // Update mouse-linked control points
    for (auto& cp : control_points_) {
        if (cp.flags & 1u) {
            cp.pos = cursor_local + cp.offset;
        } else {
            cp.pos = cp.offset;
        }
    }

    // Optional warm-up for starttime > 0
    if (!warmed_up_) {
        warmed_up_ = true;
        if (start_time_ > 0.0f) {
            float rem = std::min(start_time_, 10.0f);
            while (rem > 0.0f) {
                float step = std::min(rem, 0.05f);
                rem -= step;
                update(step, cursor_local);
            }
        }
    }

    float sim_dt = std::clamp(dt, 0.0f, 0.1f) * overrides_.speed_mul;
    if (sim_dt <= 0.0f) return;

    // Emit new particles
    for (auto& em : emitters_) {
        if (em.instantaneous > 0 && !em.spawned_instant) {
            em.spawned_instant = true;
            for (int i = 0; i < em.instantaneous; ++i) spawn_particle(em);
        }
        if (em.rate > 0.0f) {
            em.accum += em.rate * sim_dt;
            int n = static_cast<int>(em.accum);
            em.accum -= static_cast<float>(n);
            n = std::min(n, max_count_);
            for (int i = 0; i < n; ++i) spawn_particle(em);
        }
    }

    // Step active particles
    for (auto& p : particles_) {
        if (!p.alive) continue;
        p.age += sim_dt;
        if (p.age >= p.lifetime) {
            p.alive = false;
            continue;
        }
        float life_frac = std::clamp(p.age / p.lifetime, 0.0f, 1.0f);
        p.size = p.init_size;
        p.alpha = p.init_alpha;
        p.color = p.init_color;

        for (const auto& op : operators_) {
            const auto& c = op.config;
            if (op.name == "movement") {
                float drag = c["drag"].as_float(0.0f);
                glm::vec3 grav = c["gravity"].as_vec3(glm::vec3(0.0f));
                p.vel += grav * sim_dt;
                if (drag > 0.0f) {
                    p.vel *= std::max(0.0f, 1.0f - drag * sim_dt);
                }
                p.pos += p.vel * sim_dt;
            } else if (op.name == "angularmovement") {
                float drag = c["drag"].as_float(0.0f);
                glm::vec3 force = c["force"].as_vec3(glm::vec3(0.0f));
                p.ang_vel += force * sim_dt;
                if (drag > 0.0f) p.ang_vel *= std::max(0.0f, 1.0f - drag * sim_dt);
                p.rot += p.ang_vel * sim_dt;
            } else if (op.name == "alphafade") {
                float fin = c["fadeintime"].as_float(0.5f);
                float fout = c["fadeouttime"].as_float(0.5f);
                float mul = 1.0f;
                if (fin > 0.0f && life_frac < fin) mul *= life_frac / fin;
                if (fout < 1.0f && life_frac > fout) mul *= (1.0f - life_frac) / std::max(1e-4f, 1.0f - fout);
                p.alpha *= std::clamp(mul, 0.0f, 1.0f);
            } else if (op.name == "alphachange") {
                float st = c["starttime"].as_float(0.0f);
                float et = c["endtime"].as_float(1.0f);
                float sv = c["startvalue"].as_float(1.0f);
                float ev = c["endvalue"].as_float(0.0f);
                float t = (et > st) ? (life_frac - st) / (et - st) : 1.0f;
                p.alpha *= lerp_f(sv, ev, t);
            } else if (op.name == "sizechange") {
                float st = c["starttime"].as_float(0.0f);
                float et = c["endtime"].as_float(1.0f);
                float sv = c["startvalue"].as_float(1.0f);
                float ev = c["endvalue"].as_float(0.0f);
                float t = (et > st) ? (life_frac - st) / (et - st) : 1.0f;
                p.size *= lerp_f(sv, ev, t);
            } else if (op.name == "colorchange") {
                float st = c["starttime"].as_float(0.0f);
                float et = c["endtime"].as_float(1.0f);
                glm::vec3 sv = c["startvalue"].as_vec3(glm::vec3(255.0f)) / 255.0f;
                glm::vec3 ev = c["endvalue"].as_vec3(glm::vec3(255.0f)) / 255.0f;
                float t = std::clamp((et > st) ? (life_frac - st) / (et - st) : 1.0f, 0.0f, 1.0f);
                p.color = p.init_color * glm::mix(sv, ev, t);
            } else if (op.name == "turbulence") {
                float scale = c["scale"].as_float(0.01f);
                float speed = c["speedmax"].as_float(c["speedmin"].as_float(50.0f));
                float tscale = c["timescale"].as_float(1.0f);
                glm::vec3 sp = p.pos * scale + glm::vec3(p.age * tscale * 0.5f);
                glm::vec3 accel(vnoise3(sp), vnoise3(sp + glm::vec3(17.3f, 31.7f, 5.1f)), 0.0f);
                p.vel += accel * speed * sim_dt;
            } else if (op.name == "vortex") {
                int cp_id = c["controlpoint"].as_int(0);
                glm::vec3 center = (cp_id >= 0 && cp_id < static_cast<int>(control_points_.size()))
                                       ? control_points_[cp_id].pos
                                       : glm::vec3(0.0f);
                glm::vec3 axis = c["axis"].as_vec3(glm::vec3(0.0f, 0.0f, 1.0f));
                float speed = c["speedinner"].as_float(50.0f);
                glm::vec3 d = p.pos - center;
                float dist = glm::length(d);
                if (dist > 1e-3f) {
                    glm::vec3 tang = glm::normalize(glm::cross(axis, d));
                    p.vel += tang * speed * sim_dt;
                }
            } else if (op.name == "oscillatesize") {
                float freq = c["frequencymin"].as_float(2.0f);
                float mn = c["scalemin"].as_float(0.5f);
                float mx = c["scalemax"].as_float(1.5f);
                float s = 0.5f + 0.5f * std::sin(p.age * freq * glm::two_pi<float>());
                p.size *= lerp_f(mn, mx, s);
            } else if (op.name == "oscillatealpha") {
                float freq = c["frequencymin"].as_float(2.0f);
                float mn = c["scalemin"].as_float(0.2f);
                float mx = c["scalemax"].as_float(1.0f);
                float s = 0.5f + 0.5f * std::sin(p.age * freq * glm::two_pi<float>());
                p.alpha *= lerp_f(mn, mx, s);
            } else if (op.name == "oscillateposition") {
                float freq = c["frequencymin"].as_float(0.5f);
                float amp = c["scalemin"].as_float(10.0f);
                glm::vec3 mask = c["mask"].as_vec3(glm::vec3(1.0f, 1.0f, 0.0f));
                float s = std::cos(p.age * freq * glm::two_pi<float>()) * amp * sim_dt;
                p.pos += mask * s;
            }
        }
    }
}

void ParticleSystem::ensure_gl() {
    if (vao_ != 0 && max_quads_alloc_ >= static_cast<size_t>(max_count_)) return;

    if (!vao_) glGenVertexArrays(1, &vao_);
    if (!vbo_) glGenBuffers(1, &vbo_);
    if (!ebo_) glGenBuffers(1, &ebo_);

    max_quads_alloc_ = static_cast<size_t>(max_count_);
    std::vector<uint32_t> indices(max_quads_alloc_ * 6);
    for (size_t i = 0; i < max_quads_alloc_; ++i) {
        uint32_t b = static_cast<uint32_t>(i * 4);
        indices[i * 6 + 0] = b + 0;
        indices[i * 6 + 1] = b + 1;
        indices[i * 6 + 2] = b + 2;
        indices[i * 6 + 3] = b + 0;
        indices[i * 6 + 4] = b + 2;
        indices[i * 6 + 5] = b + 3;
    }

    glBindVertexArray(vao_);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_);
    glBufferData(GL_ARRAY_BUFFER, static_cast<GLsizeiptr>(max_quads_alloc_ * 4 * sizeof(ParticleVertex)),
                 nullptr, GL_STREAM_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo_);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, static_cast<GLsizeiptr>(indices.size() * sizeof(uint32_t)),
                 indices.data(), GL_STATIC_DRAW);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(ParticleVertex),
                          reinterpret_cast<void*>(offsetof(ParticleVertex, px)));
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, sizeof(ParticleVertex),
                          reinterpret_cast<void*>(offsetof(ParticleVertex, u)));
    glEnableVertexAttribArray(2);
    glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, sizeof(ParticleVertex),
                          reinterpret_cast<void*>(offsetof(ParticleVertex, r)));
    glEnableVertexAttribArray(3);
    glVertexAttribPointer(3, 2, GL_FLOAT, GL_FALSE, sizeof(ParticleVertex),
                          reinterpret_cast<void*>(offsetof(ParticleVertex, rotx)));
    glEnableVertexAttribArray(4);
    glVertexAttribPointer(4, 4, GL_FLOAT, GL_FALSE, sizeof(ParticleVertex),
                          reinterpret_cast<void*>(offsetof(ParticleVertex, vx)));

    glBindVertexArray(0);
}

void ParticleSystem::render(const glm::mat4& model,
                            const glm::mat4& view,
                            const glm::mat4& proj,
                            const glm::vec3& eye_pos,
                            float time_sec,
                            float alpha_scale) {
    if (!shader_ || !texture0_) return;

    std::vector<ParticleVertex> verts;
    verts.reserve(particles_.size() * 4);

    static const float kU[4] = {0.0f, 1.0f, 1.0f, 0.0f};
    static const float kV[4] = {0.0f, 0.0f, 1.0f, 1.0f};

    for (const auto& p : particles_) {
        if (!p.alive || p.size <= 0.001f || p.alpha <= 0.001f) continue;
        float life_phase = std::fmod(p.frame_offset + (p.age / std::max(0.001f, p.lifetime)) * sequence_mul_, 1.0f);
        float a = std::clamp(p.alpha * alpha_scale, 0.0f, 1.0f);

        for (int c = 0; c < 4; ++c) {
            verts.push_back(ParticleVertex{
                p.pos.x, p.pos.y, p.pos.z,
                kU[c], kV[c], p.rot.z, p.size,
                p.color.r, p.color.g, p.color.b, a,
                p.rot.x, p.rot.y,
                p.vel.x, p.vel.y, p.vel.z, life_phase
            });
        }
    }

    if (verts.empty()) return;
    ensure_gl();

    glBindBuffer(GL_ARRAY_BUFFER, vbo_);
    glBufferSubData(GL_ARRAY_BUFFER, 0, static_cast<GLsizeiptr>(verts.size() * sizeof(ParticleVertex)), verts.data());

    // Blend mode
    glEnable(GL_BLEND);
    if (blending_ == "additive") {
        glBlendFunc(GL_SRC_ALPHA, GL_ONE);
    } else if (blending_ == "screen") {
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_COLOR);
    } else {
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);

    glUseProgram(shader_->program);

    glm::mat4 mvp = proj * view * model;
    shader_->set_mat4("g_ModelViewProjectionMatrix", mvp);
    shader_->set_mat4("g_ModelMatrix", model);
    shader_->set_mat4("g_ModelMatrixInverse", glm::inverse(model));
    shader_->set_vec3("g_EyePosition", eye_pos);
    shader_->set_vec3("g_OrientationRight", glm::vec3(1.0f, 0.0f, 0.0f));
    shader_->set_vec3("g_OrientationUp", glm::vec3(0.0f, 1.0f, 0.0f));
    shader_->set_vec3("g_OrientationForward", glm::vec3(0.0f, 0.0f, 1.0f));
    shader_->set_vec3("g_ViewRight", glm::vec3(1.0f, 0.0f, 0.0f));
    shader_->set_vec3("g_ViewUp", glm::vec3(0.0f, 1.0f, 0.0f));
    shader_->set_float("g_Time", time_sec);

    // Defaults first, then material constantshadervalues
    for (const auto& [uname, um] : shader_->uniforms) {
        if (!um.default_val.is_null() && um.type != "sampler2D") {
            shader_->apply_json_uniform(uname, um.default_val);
        }
    }
    for (const auto& [mk, val] : constant_uniforms_) {
        std::string lk = mk;
        for (char& ch : lk) ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
        auto it = shader_->material_to_uniform.find(lk);
        if (it != shader_->material_to_uniform.end()) {
            shader_->apply_json_uniform(it->second, val);
        }
    }

    // Texture 0 & spritesheet vars
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texture0_->gl_id());
    shader_->set_int("g_Texture0", 0);
    shader_->set_vec4("g_Texture0Resolution",
                      glm::vec4(static_cast<float>(texture0_->tex_width),
                                static_cast<float>(texture0_->tex_height),
                                static_cast<float>(texture0_->img_width),
                                static_cast<float>(texture0_->img_height)));

    shader_->set_vec4("g_RenderVar0", glm::vec4(trail_length_, trail_max_len_, trail_min_len_, 0.0f));
    if (use_spritesheet_) {
        float fw = std::abs(texture0_->frames[0].width);
        float fh = std::abs(texture0_->frames[0].height);
        float tw = static_cast<float>(std::max(1, texture0_->tex_width));
        float th = static_cast<float>(std::max(1, texture0_->tex_height));
        float nframes = static_cast<float>(texture0_->frames.size());
        float ratio = (fw > 0.0f) ? (fh / fw) : 1.0f;
        shader_->set_vec4("g_RenderVar1", glm::vec4(fw / tw, fh / th, nframes, ratio));
    }

    glBindVertexArray(vao_);
    GLsizei quad_count = static_cast<GLsizei>(verts.size() / 4);
    glDrawElements(GL_TRIANGLES, quad_count * 6, GL_UNSIGNED_INT, nullptr);
    glBindVertexArray(0);
}

} // namespace sw
