#include "json.hpp"

#include <cctype>
#include <cstdlib>
#include <sstream>

namespace sw {

namespace {

const Json::Array kEmptyArray{};
const Json::Object kEmptyObject{};
const Json kNullJson{};

struct Parser {
    std::string_view s;
    size_t pos = 0;
    std::string* err = nullptr;

    void set_err(const std::string& m) {
        if (err && err->empty()) {
            *err = m + " at offset " + std::to_string(pos);
        }
    }

    void skip_ws() {
        while (pos < s.size()) {
            unsigned char c = static_cast<unsigned char>(s[pos]);
            if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
                ++pos;
            } else if (c == '/' && pos + 1 < s.size() && s[pos + 1] == '/') {
                pos += 2;
                while (pos < s.size() && s[pos] != '\n') ++pos;
            } else if (c == '/' && pos + 1 < s.size() && s[pos + 1] == '*') {
                pos += 2;
                while (pos + 1 < s.size() && !(s[pos] == '*' && s[pos + 1] == '/')) ++pos;
                if (pos + 1 < s.size()) pos += 2;
            } else {
                break;
            }
        }
    }

    static void append_utf8(std::string& out, uint32_t cp) {
        if (cp <= 0x7F) {
            out.push_back(static_cast<char>(cp));
        } else if (cp <= 0x7FF) {
            out.push_back(static_cast<char>(0xC0 | ((cp >> 6) & 0x1F)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        } else if (cp <= 0xFFFF) {
            out.push_back(static_cast<char>(0xE0 | ((cp >> 12) & 0x0F)));
            out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        } else if (cp <= 0x10FFFF) {
            out.push_back(static_cast<char>(0xF0 | ((cp >> 18) & 0x07)));
            out.push_back(static_cast<char>(0x80 | ((cp >> 12) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | ((cp >> 6) & 0x3F)));
            out.push_back(static_cast<char>(0x80 | (cp & 0x3F)));
        }
    }

    uint32_t parse_hex4() {
        uint32_t v = 0;
        for (int i = 0; i < 4 && pos < s.size(); ++i, ++pos) {
            char c = s[pos];
            v <<= 4;
            if (c >= '0' && c <= '9') v |= (c - '0');
            else if (c >= 'a' && c <= 'f') v |= (c - 'a' + 10);
            else if (c >= 'A' && c <= 'F') v |= (c - 'A' + 10);
        }
        return v;
    }

    std::string parse_string() {
        if (pos >= s.size() || s[pos] != '"') {
            set_err("expected '\"'");
            return {};
        }
        ++pos;
        std::string out;
        while (pos < s.size()) {
            char c = s[pos++];
            if (c == '"') return out;
            if (c == '\\' && pos < s.size()) {
                char e = s[pos++];
                switch (e) {
                    case '"': out.push_back('"'); break;
                    case '\\': out.push_back('\\'); break;
                    case '/': out.push_back('/'); break;
                    case 'b': out.push_back('\b'); break;
                    case 'f': out.push_back('\f'); break;
                    case 'n': out.push_back('\n'); break;
                    case 'r': out.push_back('\r'); break;
                    case 't': out.push_back('\t'); break;
                    case 'u': {
                        uint32_t cp = parse_hex4();
                        if (cp >= 0xD800 && cp <= 0xDBFF && pos + 1 < s.size() && s[pos] == '\\' && s[pos + 1] == 'u') {
                            pos += 2;
                            uint32_t lo = parse_hex4();
                            if (lo >= 0xDC00 && lo <= 0xDFFF) {
                                cp = 0x10000 + (((cp - 0xD800) << 10) | (lo - 0xDC00));
                            }
                        }
                        append_utf8(out, cp);
                        break;
                    }
                    default: out.push_back(e); break;
                }
            } else {
                out.push_back(c);
            }
        }
        set_err("unterminated string");
        return out;
    }

    Json parse_value() {
        skip_ws();
        if (pos >= s.size()) {
            set_err("unexpected EOF");
            return nullptr;
        }
        char c = s[pos];
        if (c == '"') return Json(parse_string());
        if (c == '{') return parse_object();
        if (c == '[') return parse_array();
        if (c == 't' && s.substr(pos, 4) == "true") { pos += 4; return Json(true); }
        if (c == 'f' && s.substr(pos, 5) == "false") { pos += 5; return Json(false); }
        if (c == 'n' && s.substr(pos, 4) == "null") { pos += 4; return Json(nullptr); }
        if (c == '-' || (c >= '0' && c <= '9') || c == '.') {
            size_t start = pos;
            if (s[pos] == '-') ++pos;
            while (pos < s.size() && (std::isdigit(static_cast<unsigned char>(s[pos])) ||
                                      s[pos] == '.' || s[pos] == 'e' || s[pos] == 'E' ||
                                      s[pos] == '+' || s[pos] == '-')) {
                if ((s[pos] == '+' || s[pos] == '-') && pos > start && s[pos - 1] != 'e' && s[pos - 1] != 'E')
                    break;
                ++pos;
            }
            std::string tmp(s.substr(start, pos - start));
            char* endp = nullptr;
            double v = std::strtod(tmp.c_str(), &endp);
            return Json(v);
        }
        set_err(std::string("unexpected char '") + c + "'");
        return nullptr;
    }

    Json parse_array() {
        ++pos; // '['
        Json::Array arr;
        skip_ws();
        if (pos < s.size() && s[pos] == ']') {
            ++pos;
            return Json(std::move(arr));
        }
        while (pos < s.size()) {
            skip_ws();
            if (pos < s.size() && s[pos] == ']') { ++pos; break; }
            arr.push_back(parse_value());
            skip_ws();
            if (pos < s.size() && s[pos] == ',') {
                ++pos;
            } else if (pos < s.size() && s[pos] == ']') {
                ++pos;
                break;
            } else {
                set_err("expected ',' or ']'");
                break;
            }
        }
        return Json(std::move(arr));
    }

    Json parse_object() {
        ++pos; // '{'
        Json::Object obj;
        skip_ws();
        if (pos < s.size() && s[pos] == '}') {
            ++pos;
            return Json(std::move(obj));
        }
        while (pos < s.size()) {
            skip_ws();
            if (pos < s.size() && s[pos] == '}') { ++pos; break; }
            std::string key = parse_string();
            skip_ws();
            if (pos < s.size() && s[pos] == ':') ++pos;
            else { set_err("expected ':'"); break; }
            Json val = parse_value();
            obj.insert_or_assign(std::move(key), std::move(val));
            skip_ws();
            if (pos < s.size() && s[pos] == ',') {
                ++pos;
            } else if (pos < s.size() && s[pos] == '}') {
                ++pos;
                break;
            } else {
                set_err("expected ',' or '}'");
                break;
            }
        }
        return Json(std::move(obj));
    }
};

} // namespace

const Json& Json::null_value() { return kNullJson; }

Json Json::parse(std::string_view src, std::string* err) {
    // Strip UTF-8 BOM if present
    if (src.size() >= 3 &&
        static_cast<unsigned char>(src[0]) == 0xEF &&
        static_cast<unsigned char>(src[1]) == 0xBB &&
        static_cast<unsigned char>(src[2]) == 0xBF) {
        src.remove_prefix(3);
    }
    Parser p{src, 0, err};
    return p.parse_value();
}

bool Json::as_bool(bool def) const {
    if (auto* b = std::get_if<bool>(&data)) return *b;
    if (auto* n = std::get_if<double>(&data)) return *n != 0.0;
    if (auto* s = std::get_if<std::string>(&data)) {
        if (*s == "true" || *s == "1") return true;
        if (*s == "false" || *s == "0") return false;
    }
    return def;
}

double Json::as_double(double def) const {
    if (auto* n = std::get_if<double>(&data)) return *n;
    if (auto* b = std::get_if<bool>(&data)) return *b ? 1.0 : 0.0;
    if (auto* s = std::get_if<std::string>(&data)) {
        char* endp = nullptr;
        double v = std::strtod(s->c_str(), &endp);
        if (endp != s->c_str()) return v;
    }
    return def;
}

std::string Json::as_string(const std::string& def) const {
    if (auto* s = std::get_if<std::string>(&data)) return *s;
    if (auto* n = std::get_if<double>(&data)) {
        std::ostringstream oss;
        oss << *n;
        return oss.str();
    }
    if (auto* b = std::get_if<bool>(&data)) return *b ? "true" : "false";
    return def;
}

const Json::Array& Json::as_array() const {
    if (auto* a = std::get_if<Array>(&data)) return *a;
    return kEmptyArray;
}

const Json::Object& Json::as_object() const {
    if (auto* o = std::get_if<Object>(&data)) return *o;
    return kEmptyObject;
}

bool Json::has(const std::string& key) const {
    if (auto* o = std::get_if<Object>(&data)) {
        return o->find(key) != o->end();
    }
    return false;
}

const Json& Json::get(const std::string& key) const {
    if (auto* o = std::get_if<Object>(&data)) {
        auto it = o->find(key);
        if (it != o->end()) return it->second;
    }
    return kNullJson;
}

std::vector<float> parse_floats(std::string_view s) {
    std::vector<float> out;
    size_t i = 0;
    while (i < s.size()) {
        while (i < s.size() && (std::isspace(static_cast<unsigned char>(s[i])) || s[i] == ',')) ++i;
        if (i >= s.size()) break;
        size_t start = i;
        while (i < s.size() && !std::isspace(static_cast<unsigned char>(s[i])) && s[i] != ',') ++i;
        std::string tmp(s.substr(start, i - start));
        char* endp = nullptr;
        float v = std::strtof(tmp.c_str(), &endp);
        if (endp != tmp.c_str()) out.push_back(v);
    }
    return out;
}

glm::vec2 Json::as_vec2(glm::vec2 def) const {
    if (is_string()) {
        auto f = parse_floats(as_string());
        if (f.size() >= 2) return glm::vec2(f[0], f[1]);
        if (f.size() == 1) return glm::vec2(f[0]);
    } else if (is_number()) {
        return glm::vec2(as_float());
    } else if (is_array()) {
        const auto& a = as_array();
        if (a.size() >= 2) return glm::vec2(a[0].as_float(), a[1].as_float());
    }
    return def;
}

glm::vec3 Json::as_vec3(glm::vec3 def) const {
    if (is_string()) {
        auto f = parse_floats(as_string());
        if (f.size() >= 3) return glm::vec3(f[0], f[1], f[2]);
        if (f.size() == 1) return glm::vec3(f[0]);
    } else if (is_number()) {
        return glm::vec3(as_float());
    } else if (is_array()) {
        const auto& a = as_array();
        if (a.size() >= 3) return glm::vec3(a[0].as_float(), a[1].as_float(), a[2].as_float());
    }
    return def;
}

glm::vec4 Json::as_vec4(glm::vec4 def) const {
    if (is_string()) {
        auto f = parse_floats(as_string());
        if (f.size() >= 4) return glm::vec4(f[0], f[1], f[2], f[3]);
        if (f.size() == 3) return glm::vec4(f[0], f[1], f[2], 1.0f);
        if (f.size() == 1) return glm::vec4(f[0]);
    } else if (is_number()) {
        return glm::vec4(as_float());
    } else if (is_array()) {
        const auto& a = as_array();
        if (a.size() >= 4) return glm::vec4(a[0].as_float(), a[1].as_float(), a[2].as_float(), a[3].as_float());
        if (a.size() == 3) return glm::vec4(a[0].as_float(), a[1].as_float(), a[2].as_float(), 1.0f);
    }
    return def;
}

} // namespace sw
