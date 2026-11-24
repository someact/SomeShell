#include "shader.hpp"

#include <GL/glext.h>
#include <glm/gtc/type_ptr.hpp>

#include <algorithm>
#include <cctype>
#include <iostream>
#include <sstream>

namespace sw {

namespace {

std::string to_upper(std::string s) {
    for (char& c : s) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
    return s;
}

std::string to_lower(std::string s) {
    for (char& c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return s;
}

std::string trim(const std::string& s) {
    size_t a = 0;
    while (a < s.size() && std::isspace(static_cast<unsigned char>(s[a]))) ++a;
    size_t b = s.size();
    while (b > a && std::isspace(static_cast<unsigned char>(s[b - 1]))) --b;
    return s.substr(a, b - a);
}

bool is_ident_char(char c) {
    return std::isalnum(static_cast<unsigned char>(c)) || c == '_';
}

// Replace standalone identifier token outside comments
std::string replace_token(const std::string& line, const std::string& from, const std::string& to) {
    std::string out;
    out.reserve(line.size() + 16);
    size_t i = 0;
    while (i < line.size()) {
        if (i + 1 < line.size() && line[i] == '/' && line[i + 1] == '/') {
            out.append(line.substr(i));
            break;
        }
        if (i + from.size() <= line.size() && line.compare(i, from.size(), from) == 0) {
            bool left_ok = (i == 0 || !is_ident_char(line[i - 1]));
            bool right_ok = (i + from.size() == line.size() || !is_ident_char(line[i + from.size()]));
            if (left_ok && right_ok) {
                out.append(to);
                i += from.size();
                continue;
            }
        }
        out.push_back(line[i++]);
    }
    return out;
}

const char* kCommonPrelude = R"GLSL(
#define GLSL 1
#define HIGHP
#define CAST2(x) vec2(x)
#define CAST3(x) vec3(x)
#define CAST4(x) vec4(x)
#define CAST3X3(x) mat3(x)
#define CASTU(x) uint(x)
#define frac(x) fract(x)
#define saturate(x) clamp((x), 0.0, 1.0)
#define lerp mix
#define atan2(y, x) atan((y), (x))
#define ddx dFdx
#define ddy dFdy
#define texSample2D(s, uv) texture((s), (uv))
#define texSample2DLod(s, uv, lod) textureLod((s), (uv), (lod))
#define texSample2DCompare(s, uv, cmp) texture((s), vec3((uv), (cmp)))
#define sampler2DComparison sampler2DShadow

vec4 mul(vec4 v, mat4 m) { return m * v; }
vec4 mul(mat4 m, vec4 v) { return v * m; }
vec3 mul(vec3 v, mat3 m) { return m * v; }
vec3 mul(mat3 m, vec3 v) { return v * m; }
vec2 mul(vec2 v, mat2 m) { return m * v; }
vec2 mul(mat2 m, vec2 v) { return v * m; }
vec3 mul(vec4 v, mat4x3 m) { return m * v; }
mat4 mul(mat4 a, mat4 b) { return b * a; }
mat3 mul(mat3 a, mat3 b) { return b * a; }
mat2 mul(mat2 a, mat2 b) { return b * a; }

// Lightweight LightingV1 fallback when LIGHTING combo is enabled
vec3 PerformLighting_V1(vec3 worldPos, vec3 albedo, vec3 normal, vec3 viewDir,
                        vec3 specTint, vec3 f0, float roughness, float metallic) {
    return albedo * 0.5;
}
)GLSL";

} // namespace

CompiledShader::~CompiledShader() {
    if (program) {
        glDeleteProgram(program);
        program = 0;
    }
}

GLint CompiledShader::loc(const std::string& name) const {
    auto it = uniform_locs.find(name);
    if (it != uniform_locs.end()) return it->second;
    return -1;
}

void CompiledShader::set_int(const std::string& name, int v) const {
    GLint l = loc(name);
    if (l >= 0) glUniform1i(l, v);
}

void CompiledShader::set_float(const std::string& name, float v) const {
    GLint l = loc(name);
    if (l >= 0) glUniform1f(l, v);
}

void CompiledShader::set_vec2(const std::string& name, const glm::vec2& v) const {
    GLint l = loc(name);
    if (l >= 0) glUniform2fv(l, 1, glm::value_ptr(v));
}

void CompiledShader::set_vec3(const std::string& name, const glm::vec3& v) const {
    GLint l = loc(name);
    if (l >= 0) glUniform3fv(l, 1, glm::value_ptr(v));
}

void CompiledShader::set_vec4(const std::string& name, const glm::vec4& v) const {
    GLint l = loc(name);
    if (l >= 0) glUniform4fv(l, 1, glm::value_ptr(v));
}

void CompiledShader::set_mat3(const std::string& name, const glm::mat3& v) const {
    GLint l = loc(name);
    if (l >= 0) glUniformMatrix3fv(l, 1, GL_FALSE, glm::value_ptr(v));
}

void CompiledShader::set_mat4(const std::string& name, const glm::mat4& v) const {
    GLint l = loc(name);
    if (l >= 0) glUniformMatrix4fv(l, 1, GL_FALSE, glm::value_ptr(v));
}

void CompiledShader::apply_json_uniform(const std::string& glsl_name, const Json& val) const {
    GLint l = loc(glsl_name);
    if (l < 0 || val.is_null()) return;
    auto it = uniforms.find(glsl_name);
    std::string t = (it != uniforms.end()) ? it->second.type : "float";
    if (t == "float") {
        glUniform1f(l, val.as_float());
    } else if (t == "int" || t == "uint") {
        glUniform1i(l, val.as_int());
    } else if (t == "vec2") {
        auto v = val.as_vec2();
        glUniform2fv(l, 1, glm::value_ptr(v));
    } else if (t == "vec3") {
        auto v = val.as_vec3();
        glUniform3fv(l, 1, glm::value_ptr(v));
    } else if (t == "vec4") {
        auto v = val.as_vec4();
        glUniform4fv(l, 1, glm::value_ptr(v));
    }
}

void ShaderCache::clear() {
    cache_.clear();
}

std::string ShaderCache::preprocess(const std::string& src,
                                    const std::string& current_dir,
                                    int depth,
                                    std::map<std::string, int>& combo_defaults,
                                    CompiledShader& meta) {
    if (depth > 16) return {};
    std::istringstream iss(src);
    std::ostringstream oss;
    std::string line;
    while (std::getline(iss, line)) {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        std::string t = trim(line);

        // Parse // [COMBO] {...}
        if (t.rfind("// [COMBO]", 0) == 0 || t.rfind("//[COMBO]", 0) == 0) {
            size_t brace = t.find('{');
            if (brace != std::string::npos) {
                Json cj = Json::parse(t.substr(brace));
                std::string cname = to_upper(cj["combo"].as_string());
                int def = cj["default"].as_int(0);
                if (!cname.empty() && combo_defaults.find(cname) == combo_defaults.end()) {
                    combo_defaults[cname] = def;
                }
            }
            continue;
        }

        // Strip #require directives
        if (t.rfind("#require", 0) == 0) {
            continue;
        }

        // Resolve #include "..."
        if (t.rfind("#include", 0) == 0) {
            size_t q1 = t.find('"');
            size_t q2 = (q1 != std::string::npos) ? t.find('"', q1 + 1) : std::string::npos;
            if (q1 != std::string::npos && q2 != std::string::npos) {
                std::string inc = t.substr(q1 + 1, q2 - q1 - 1);
                std::optional<std::string> content;
                std::string next_dir = "shaders";
                if (!current_dir.empty()) {
                    content = vfs_.read_text(current_dir + "/" + inc);
                    if (content) next_dir = current_dir;
                }
                if (!content) content = vfs_.read_text("shaders/" + inc);
                if (!content) content = vfs_.read_text(inc);
                if (content) {
                    oss << preprocess(*content, next_dir, depth + 1, combo_defaults, meta) << "\n";
                } else {
                    std::cerr << "[shader] missing include: " << inc << "\n";
                }
                continue;
            }
        }

        // Parse uniform declarations and their JSON annotations:
        // uniform <type> <name>; // {"material": ..., "default": ...}
        if (t.rfind("uniform ", 0) == 0) {
            size_t semi = t.find(';');
            if (semi != std::string::npos) {
                std::string decl = trim(t.substr(8, semi - 8));
                // Strip optional precision qualifier
                std::istringstream diss(decl);
                std::string tok1, tok2;
                diss >> tok1 >> tok2;
                if (tok1 == "highp" || tok1 == "mediump" || tok1 == "lowp" || tok1 == "HIGHP") {
                    tok1 = tok2;
                    diss >> tok2;
                }
                // Strip array brackets from name if any
                size_t br = tok2.find('[');
                if (br != std::string::npos) tok2 = tok2.substr(0, br);

                if (!tok1.empty() && !tok2.empty()) {
                    UniformMeta um;
                    um.type = tok1;
                    um.glsl_name = tok2;

                    size_t cmt = t.find("//", semi);
                    if (cmt != std::string::npos) {
                        size_t jb = t.find('{', cmt);
                        if (jb != std::string::npos) {
                            Json mj = Json::parse(t.substr(jb));
                            if (mj.is_object()) {
                                if (mj.has("material")) {
                                    um.material_key = mj["material"].as_string();
                                    meta.material_to_uniform[to_lower(um.material_key)] = um.glsl_name;
                                }
                                if (mj.has("default")) {
                                    um.default_val = mj["default"];
                                }
                                if (tok1 == "sampler2D" && tok2.rfind("g_Texture", 0) == 0) {
                                    int slot = std::atoi(tok2.c_str() + 9);
                                    if (mj.has("default") && mj["default"].is_string()) {
                                        meta.default_textures[slot] = mj["default"].as_string();
                                    }
                                    if (mj.has("combo") && mj["combo"].is_string()) {
                                        meta.texture_combos[slot] = to_upper(mj["combo"].as_string());
                                    }
                                }
                            }
                        }
                    }
                    meta.uniforms[um.glsl_name] = std::move(um);
                }
            }
        }

        oss << line << "\n";
    }
    return oss.str();
}

std::string ShaderCache::transpile_stage(const std::string& body,
                                         bool is_frag,
                                         const std::map<std::string, int>& final_combos) {
    std::ostringstream out;
    out << "#version 330 core\n";
    out << kCommonPrelude << "\n";
    for (const auto& [k, v] : final_combos) {
        out << "#define " << k << " " << v << "\n";
    }
    if (is_frag) {
        out << "out vec4 _we_FragColor;\n";
        out << "#define gl_FragColor _we_FragColor\n";
    }

    std::istringstream iss(body);
    std::string line;
    while (std::getline(iss, line)) {
        if (!is_frag) {
            line = replace_token(line, "attribute", "in");
            line = replace_token(line, "varying", "out");
        } else {
            line = replace_token(line, "varying", "in");
        }
        out << line << "\n";
    }
    return out.str();
}

CompiledShader* ShaderCache::get(const std::string& shader_name, const std::map<std::string, int>& combos,
                                 const std::set<int>& bound) {
    // Normalize combos to uppercase
    std::map<std::string, int> norm_combos;
    for (const auto& [k, v] : combos) {
        norm_combos[to_upper(k)] = v;
    }

    std::ostringstream key_ss;
    key_ss << shader_name;
    for (const auto& [k, v] : norm_combos) {
        key_ss << "|" << k << "=" << v;
    }
    for (int slot : bound) key_ss << "|t" << slot;
    std::string key = key_ss.str();
    if (auto it = cache_.find(key); it != cache_.end()) {
        return it->second.get();
    }

    auto find_shader_file = [&](const std::string& ext) -> std::pair<std::string, std::string> {
        std::vector<std::string> tries = {
            "shaders/" + shader_name + ext,
            shader_name + ext
        };
        for (const auto& p : tries) {
            if (auto txt = vfs_.read_text(p)) {
                size_t slash = p.rfind('/');
                std::string dir = (slash == std::string::npos) ? "shaders" : p.substr(0, slash);
                return {*txt, dir};
            }
        }
        return {{}, {}};
    };

    auto [vs_raw, vs_dir] = find_shader_file(".vert");
    auto [fs_raw, fs_dir] = find_shader_file(".frag");
    if (vs_raw.empty() || fs_raw.empty()) {
        std::cerr << "[shader] missing .vert/.frag for: " << shader_name << "\n";
        return nullptr;
    }

    auto cs = std::make_unique<CompiledShader>();
    std::map<std::string, int> combo_defaults;
    std::string vs_body = preprocess(vs_raw, vs_dir, 0, combo_defaults, *cs);
    std::string fs_body = preprocess(fs_raw, fs_dir, 0, combo_defaults, *cs);

    // Merge defaults + explicit combos (only define non-zero defaults or explicitly provided combos)
    std::map<std::string, int> final_combos;
    for (const auto& [k, v] : combo_defaults) {
        if (v != 0) final_combos[k] = v;
    }
    // Combos switched on by a bound texture (the material's own value wins)
    for (const auto& [slot, name] : cs->texture_combos) {
        if (bound.count(slot) && !norm_combos.count(name)) final_combos[name] = 1;
    }
    for (const auto& [k, v] : norm_combos) {
        if (v == 0) {
            // Explicitly disabled: keep 0 unless it's VERSION/SKINNING_ALPHA checked via #ifdef
            if (k != "VERSION" && k != "SKINNING_ALPHA") final_combos[k] = 0;
            else final_combos.erase(k);
        } else {
            final_combos[k] = v;
        }
    }

    std::string vs_src = transpile_stage(vs_body, false, final_combos);
    std::string fs_src = transpile_stage(fs_body, true, final_combos);

    auto compile = [&](GLenum type, const std::string& src, const char* stage) -> GLuint {
        GLuint s = glCreateShader(type);
        const char* p = src.c_str();
        glShaderSource(s, 1, &p, nullptr);
        glCompileShader(s);
        GLint ok = 0;
        glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
        if (!ok) {
            GLint len = 0;
            glGetShaderiv(s, GL_INFO_LOG_LENGTH, &len);
            std::string log(static_cast<size_t>(std::max(len, 1)), '\0');
            glGetShaderInfoLog(s, len, nullptr, log.data());
            std::cerr << "[shader] compile failed (" << shader_name << " " << stage << "):\n" << log << "\n";
            glDeleteShader(s);
            return 0;
        }
        return s;
    };

    GLuint vs = compile(GL_VERTEX_SHADER, vs_src, "vert");
    GLuint fs = compile(GL_FRAGMENT_SHADER, fs_src, "frag");
    if (!vs || !fs) {
        if (vs) glDeleteShader(vs);
        if (fs) glDeleteShader(fs);
        return nullptr;
    }

    GLuint prog = glCreateProgram();
    glAttachShader(prog, vs);
    glAttachShader(prog, fs);

    // Bind standard Wallpaper Engine attribute locations consistently
    glBindAttribLocation(prog, 0, "a_Position");
    glBindAttribLocation(prog, 0, "a_PositionVec4");
    glBindAttribLocation(prog, 1, "a_TexCoord");
    glBindAttribLocation(prog, 1, "a_TexCoordVec4");
    glBindAttribLocation(prog, 2, "a_Color");
    glBindAttribLocation(prog, 3, "a_TexCoordC2");
    glBindAttribLocation(prog, 4, "a_TexCoordVec4C1");
    glBindAttribLocation(prog, 5, "a_Normal");

    glLinkProgram(prog);
    glDeleteShader(vs);
    glDeleteShader(fs);

    GLint linked = 0;
    glGetProgramiv(prog, GL_LINK_STATUS, &linked);
    if (!linked) {
        GLint len = 0;
        glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &len);
        std::string log(static_cast<size_t>(std::max(len, 1)), '\0');
        glGetProgramInfoLog(prog, len, nullptr, log.data());
        std::cerr << "[shader] link failed (" << shader_name << "):\n" << log << "\n";
        glDeleteProgram(prog);
        return nullptr;
    }

    cs->program = prog;

    // Cache all active uniform locations
    GLint num_u = 0;
    glGetProgramiv(prog, GL_ACTIVE_UNIFORMS, &num_u);
    for (GLint i = 0; i < num_u; ++i) {
        char name[256];
        GLsizei nlen = 0;
        GLint size = 0;
        GLenum type = 0;
        glGetActiveUniform(prog, static_cast<GLuint>(i), sizeof(name), &nlen, &size, &type, name);
        std::string uname(name, static_cast<size_t>(nlen));
        cs->uniform_locs[uname] = glGetUniformLocation(prog, uname.c_str());
    }

    CompiledShader* raw = cs.get();
    cache_[key] = std::move(cs);
    return raw;
}

} // namespace sw
