#pragma once

#include "vfs.hpp"

#include <GL/gl.h>
#include <string>

namespace sw {

// Rasterizes a Wallpaper Engine text object into a GL_RGBA8 texture using FreeType2 + Fontconfig.
class TextRenderer {
public:
    TextRenderer();
    ~TextRenderer();

    TextRenderer(const TextRenderer&) = delete;
    TextRenderer& operator=(const TextRenderer&) = delete;

    bool render_to_texture(const Vfs& vfs,
                           const std::string& font_spec,
                           float point_size,
                           const std::string& text,
                           int box_w,
                           int box_h,
                           const std::string& halign,
                           const std::string& valign,
                           GLuint& tex_id,
                           int& out_w,
                           int& out_h);

private:
    std::string resolve_font_path(const Vfs& vfs, const std::string& font_spec);

    void* ft_lib_ = nullptr; // FT_Library
};

} // namespace sw
