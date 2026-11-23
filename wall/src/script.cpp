#include "script.hpp"

#include <cctype>
#include <iostream>
#include <sstream>

namespace sw {

namespace {

const char* kScriptPrelude = R"JS(
var __exports = {};
var engine = {
    frametime: 0.016,
    runtime: 0.0,
    userProperties: {},
    canvasSize: { x: 1920, y: 1080 },
    cursorScreenPosition: { x: 0.5, y: 0.5 },
    isDesktopDevice: function() { return true; },
    isPortrait: function() { return false; }
};
var thisObject = {};
var thisLayer = thisObject;
var thisScene = {
    getLayer: function() { return null; }
};
function Vec2(x, y) {
    if (typeof x === 'object' && x !== null) { this.x = x.x || 0; this.y = x.y || 0; }
    else { this.x = x || 0; this.y = (y === undefined ? this.x : y); }
}
Vec2.prototype.toString = function() { return this.x + ' ' + this.y; };
function Vec3(x, y, z) {
    if (typeof x === 'object' && x !== null) { this.x = x.x || 0; this.y = x.y || 0; this.z = x.z || 0; }
    else { this.x = x || 0; this.y = (y === undefined ? this.x : y); this.z = (z === undefined ? this.x : z); }
}
Vec3.prototype.toString = function() { return this.x + ' ' + this.y + ' ' + this.z; };
function createScriptProperties() {
    var props = {};
    var b = {
        addCheckbox: function(o) { if (o && o.name) props[o.name] = !!o.value; return b; },
        addSlider:   function(o) { if (o && o.name) props[o.name] = +o.value || 0; return b; },
        addText:     function(o) { if (o && o.name) props[o.name] = (o.value !== undefined ? '' + o.value : ''); return b; },
        addColor:    function(o) { if (o && o.name) props[o.name] = o.value || new Vec3(1,1,1); return b; },
        addCombo:    function(o) { if (o && o.name) props[o.name] = o.value; return b; },
        finish:      function()  { return props; }
    };
    return b;
}
)JS";

bool is_id(char c) {
    return std::isalnum(static_cast<unsigned char>(c)) || c == '_' || c == '$';
}

} // namespace

PropertyScript::~PropertyScript() {
    if (ctx_) {
        duk_destroy_heap(ctx_);
        ctx_ = nullptr;
    }
}

// Convert Wallpaper Engine ES module syntax (export function/let/var/const, let/const)
// into ES5-compatible JS that Duktape executes cleanly.
std::string PropertyScript::transpile_es_to_duktape(const std::string& src) {
    std::string out;
    out.reserve(src.size() + 128);
    size_t i = 0;
    size_t n = src.size();

    while (i < n) {
        char c = src[i];

        // Strip top-level 'use strict' / "use strict" so eval declarations bind in global scope
        if ((c == '\'' || c == '"') &&
            (src.compare(i, 12, "'use strict'") == 0 || src.compare(i, 12, "\"use strict\"") == 0)) {
            i += 12;
            while (i < n && (src[i] == ';' || src[i] == ' ')) ++i;
            continue;
        }

        // Preserve string literals untouched
        if (c == '\'' || c == '"' || c == '`') {
            char q = c;
            out.push_back(c == '`' ? '"' : c);
            ++i;
            while (i < n) {
                char sc = src[i++];
                if (sc == '\\' && i < n) {
                    out.push_back(sc);
                    out.push_back(src[i++]);
                    continue;
                }
                if (sc == q) {
                    out.push_back(q == '`' ? '"' : sc);
                    break;
                }
                out.push_back(sc);
            }
            continue;
        }

        // Preserve line comments
        if (c == '/' && i + 1 < n && src[i + 1] == '/') {
            while (i < n && src[i] != '\n') out.push_back(src[i++]);
            continue;
        }

        // Preserve block comments
        if (c == '/' && i + 1 < n && src[i + 1] == '*') {
            out.push_back(src[i++]);
            out.push_back(src[i++]);
            while (i + 1 < n && !(src[i] == '*' && src[i + 1] == '/')) out.push_back(src[i++]);
            if (i + 1 < n) { out.push_back(src[i++]); out.push_back(src[i++]); }
            continue;
        }

        // Check keyword tokens
        if (is_id(c) && (i == 0 || !is_id(src[i - 1]))) {
            size_t j = i;
            while (j < n && is_id(src[j])) ++j;
            std::string tok = src.substr(i, j - i);
            if (tok == "export") {
                // Skip 'export' keyword (declarations stay in global scope)
                i = j;
                continue;
            }
            if (tok == "let" || tok == "const") {
                out.append("var");
                i = j;
                continue;
            }
            out.append(tok);
            i = j;
            continue;
        }

        out.push_back(c);
        ++i;
    }
    return out;
}

bool PropertyScript::init(const std::string& js_source, const Json& script_props) {
    if (ctx_) {
        duk_destroy_heap(ctx_);
        ctx_ = nullptr;
    }
    has_update_ = false;
    if (js_source.empty()) return false;

    ctx_ = duk_create_heap_default();
    if (!ctx_) return false;

    if (duk_peval_string(ctx_, kScriptPrelude) != 0) {
        std::cerr << "[script] prelude error: " << duk_safe_to_string(ctx_, -1) << "\n";
        duk_destroy_heap(ctx_);
        ctx_ = nullptr;
        return false;
    }
    duk_pop(ctx_);

    std::string code = transpile_es_to_duktape(js_source);
    if (duk_peval_string(ctx_, code.c_str()) != 0) {
        std::cerr << "[script] eval error: " << duk_safe_to_string(ctx_, -1) << "\n";
        duk_destroy_heap(ctx_);
        ctx_ = nullptr;
        return false;
    }
    duk_pop(ctx_);

    // Apply scriptproperties overrides from scene.json onto scriptProperties global
    if (script_props.is_object()) {
        duk_get_global_string(ctx_, "scriptProperties");
        if (duk_is_object(ctx_, -1)) {
            for (const auto& [k, v] : script_props.as_object()) {
                if (v.is_bool()) duk_push_boolean(ctx_, v.as_bool() ? 1 : 0);
                else if (v.is_number()) duk_push_number(ctx_, v.as_double());
                else if (v.is_string()) duk_push_string(ctx_, v.as_string().c_str());
                else continue;
                duk_put_prop_string(ctx_, -2, k.c_str());
            }
        }
        duk_pop(ctx_);
    }

    // Call init() if present
    duk_get_global_string(ctx_, "init");
    if (duk_is_function(ctx_, -1)) {
        if (duk_pcall(ctx_, 0) != 0) {
            std::cerr << "[script] init() error: " << duk_safe_to_string(ctx_, -1) << "\n";
        }
    }
    duk_pop(ctx_);

    duk_get_global_string(ctx_, "update");
    has_update_ = duk_is_function(ctx_, -1);
    duk_pop(ctx_);

    return has_update_;
}

void PropertyScript::set_engine_globals(double frametime, double runtime) {
    duk_get_global_string(ctx_, "engine");
    if (duk_is_object(ctx_, -1)) {
        duk_push_number(ctx_, frametime);
        duk_put_prop_string(ctx_, -2, "frametime");
        duk_push_number(ctx_, runtime);
        duk_put_prop_string(ctx_, -2, "runtime");
    }
    duk_pop(ctx_);
}

std::string PropertyScript::update_string(const std::string& current_value, double frametime, double runtime) {
    if (!valid()) return current_value;
    set_engine_globals(frametime, runtime);
    duk_get_global_string(ctx_, "update");
    duk_push_string(ctx_, current_value.c_str());
    std::string result = current_value;
    if (duk_pcall(ctx_, 1) == 0) {
        if (!duk_is_undefined(ctx_, -1) && !duk_is_null(ctx_, -1)) {
            result = duk_safe_to_string(ctx_, -1);
        }
    }
    duk_pop(ctx_);
    return result;
}

double PropertyScript::update_number(double current_value, double frametime, double runtime) {
    if (!valid()) return current_value;
    set_engine_globals(frametime, runtime);
    duk_get_global_string(ctx_, "update");
    duk_push_number(ctx_, current_value);
    double result = current_value;
    if (duk_pcall(ctx_, 1) == 0 && duk_is_number(ctx_, -1)) {
        result = duk_get_number(ctx_, -1);
    }
    duk_pop(ctx_);
    return result;
}

bool PropertyScript::update_bool(bool current_value, double frametime, double runtime) {
    if (!valid()) return current_value;
    set_engine_globals(frametime, runtime);
    duk_get_global_string(ctx_, "update");
    duk_push_boolean(ctx_, current_value ? 1 : 0);
    bool result = current_value;
    if (duk_pcall(ctx_, 1) == 0 && !duk_is_undefined(ctx_, -1)) {
        result = duk_to_boolean(ctx_, -1) != 0;
    }
    duk_pop(ctx_);
    return result;
}

} // namespace sw
