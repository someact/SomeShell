#pragma once

#include <cstdint>
#include <glm/glm.hpp>
#include <map>
#include <string>
#include <string_view>
#include <variant>
#include <vector>

namespace sw {

struct Json {
    using Array = std::vector<Json>;
    using Object = std::map<std::string, Json>;

    std::variant<std::nullptr_t, bool, double, std::string, Array, Object> data{nullptr};

    Json() = default;
    Json(std::nullptr_t) : data(nullptr) {}
    Json(bool b) : data(b) {}
    Json(int v) : data(static_cast<double>(v)) {}
    Json(double v) : data(v) {}
    Json(std::string s) : data(std::move(s)) {}
    Json(const char* s) : data(std::string(s)) {}
    Json(Array a) : data(std::move(a)) {}
    Json(Object o) : data(std::move(o)) {}

    bool is_null() const { return std::holds_alternative<std::nullptr_t>(data); }
    bool is_bool() const { return std::holds_alternative<bool>(data); }
    bool is_number() const { return std::holds_alternative<double>(data); }
    bool is_string() const { return std::holds_alternative<std::string>(data); }
    bool is_array() const { return std::holds_alternative<Array>(data); }
    bool is_object() const { return std::holds_alternative<Object>(data); }

    bool as_bool(bool def = false) const;
    double as_double(double def = 0.0) const;
    float as_float(float def = 0.0f) const { return static_cast<float>(as_double(def)); }
    int as_int(int def = 0) const { return static_cast<int>(as_double(def)); }
    std::string as_string(const std::string& def = "") const;
    const Array& as_array() const;
    const Object& as_object() const;

    bool has(const std::string& key) const;
    const Json& get(const std::string& key) const;
    const Json& operator[](const std::string& key) const { return get(key); }

    glm::vec2 as_vec2(glm::vec2 def = glm::vec2(0.0f)) const;
    glm::vec3 as_vec3(glm::vec3 def = glm::vec3(0.0f)) const;
    glm::vec4 as_vec4(glm::vec4 def = glm::vec4(0.0f)) const;

    static Json parse(std::string_view src, std::string* err = nullptr);
    static const Json& null_value();
};

// Parse space-separated floats like "1.0 2.0 3.0"
std::vector<float> parse_floats(std::string_view s);

} // namespace sw
