#pragma once

#include "json.hpp"
#include "vfs.hpp"

#include <GL/gl.h>
#include <glm/glm.hpp>
#include <map>
#include <memory>
#include <set>
#include <string>
#include <unordered_map>

namespace sw {

struct UniformMeta {
    std::string glsl_name;
    std::string type;
    std::string material_key;
    Json default_val;
};

struct CompiledShader {
    GLuint program = 0;
    std::unordered_map<std::string, GLint> uniform_locs;
    std::unordered_map<std::string, std::string> material_to_uniform; // lowercased material key -> glsl uniform
    std::unordered_map<std::string, UniformMeta> uniforms;
    std::map<int, std::string> default_textures; // slot -> default texture name
    std::map<int, std::string> texture_combos;   // slot -> combo name if texture bound

    ~CompiledShader();
    CompiledShader() = default;
    CompiledShader(const CompiledShader&) = delete;
    CompiledShader& operator=(const CompiledShader&) = delete;

    GLint loc(const std::string& name) const;
    void set_int(const std::string& name, int v) const;
    void set_float(const std::string& name, float v) const;
    void set_vec2(const std::string& name, const glm::vec2& v) const;
    void set_vec3(const std::string& name, const glm::vec3& v) const;
    void set_vec4(const std::string& name, const glm::vec4& v) const;
    void set_mat3(const std::string& name, const glm::mat3& v) const;
    void set_mat4(const std::string& name, const glm::mat4& v) const;
    void apply_json_uniform(const std::string& glsl_name, const Json& val) const;
};

class ShaderCache {
public:
    explicit ShaderCache(const Vfs& vfs) : vfs_(vfs) {}
    ~ShaderCache() { clear(); }

    // `bound`: texture slots the material fills. A slot whose sampler comment
    // names a combo (e.g. an opacity mask: "combo":"MASK") turns it on when
    // bound, as Wallpaper Engine does, unless the material sets that combo itself
    CompiledShader* get(const std::string& shader_name, const std::map<std::string, int>& combos,
                        const std::set<int>& bound = {});
    void clear();

private:
    std::string preprocess(const std::string& src,
                           const std::string& current_dir,
                           int depth,
                           std::map<std::string, int>& combo_defaults,
                           CompiledShader& meta);
    std::string transpile_stage(const std::string& body,
                                bool is_frag,
                                const std::map<std::string, int>& final_combos);

    const Vfs& vfs_;
    std::unordered_map<std::string, std::unique_ptr<CompiledShader>> cache_;
};

} // namespace sw
