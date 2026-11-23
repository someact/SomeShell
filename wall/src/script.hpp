#pragma once

#include "json.hpp"

#include <duktape.h>
#include <string>

namespace sw {

// Runs a single Wallpaper Engine SceneScript (e.g. a property's update(value) script)
class PropertyScript {
public:
    PropertyScript() = default;
    ~PropertyScript();

    PropertyScript(const PropertyScript&) = delete;
    PropertyScript& operator=(const PropertyScript&) = delete;

    bool init(const std::string& js_source, const Json& script_props);
    bool valid() const { return ctx_ != nullptr && has_update_; }

    // Update string property (e.g. text object's "text" script)
    std::string update_string(const std::string& current_value, double frametime, double runtime);
    // Update numeric property
    double update_number(double current_value, double frametime, double runtime);
    // Update boolean property
    bool update_bool(bool current_value, double frametime, double runtime);

private:
    static std::string transpile_es_to_duktape(const std::string& src);
    void set_engine_globals(double frametime, double runtime);

    duk_context* ctx_ = nullptr;
    bool has_update_ = false;
};

} // namespace sw
