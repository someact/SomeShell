#include "text.hpp"

#include <fontconfig/fontconfig.h>
#include <ft2build.h>
#include FT_FREETYPE_H

#include <algorithm>
#include <cstring>
#include <iostream>
#include <vector>

namespace sw {

namespace {

// Decode one UTF-8 codepoint
uint32_t next_utf8(const std::string& s, size_t& i) {
    unsigned char c = static_cast<unsigned char>(s[i++]);
    if (c < 0x80) return c;
    if ((c & 0xE0) == 0xC0 && i < s.size()) {
        uint32_t cp = (c & 0x1F) << 6;
        cp |= (static_cast<unsigned char>(s[i++]) & 0x3F);
        return cp;
    }
    if ((c & 0xF0) == 0xE0 && i + 1 < s.size()) {
        uint32_t cp = (c & 0x0F) << 12;
        cp |= (static_cast<unsigned char>(s[i++]) & 0x3F) << 6;
        cp |= (static_cast<unsigned char>(s[i++]) & 0x3F);
        return cp;
    }
    if ((c & 0xF8) == 0xF0 && i + 2 < s.size()) {
        uint32_t cp = (c & 0x07) << 18;
        cp |= (static_cast<unsigned char>(s[i++]) & 0x3F) << 12;
        cp |= (static_cast<unsigned char>(s[i++]) & 0x3F) << 6;
        cp |= (static_cast<unsigned char>(s[i++]) & 0x3F);
        return cp;
    }
    return '?';
}

} // namespace

TextRenderer::TextRenderer() {
    FT_Library lib = nullptr;
    if (FT_Init_FreeType(&lib) == 0) {
        ft_lib_ = lib;
    }
    FcInit();
}

TextRenderer::~TextRenderer() {
    if (ft_lib_) {
        FT_Done_FreeType(static_cast<FT_Library>(ft_lib_));
        ft_lib_ = nullptr;
    }
}

std::string TextRenderer::resolve_font_path(const Vfs& vfs, const std::string& font_spec) {
    // Try VFS first (e.g. "fonts/foo.ttf" or assets/fonts/...)
    if (!font_spec.empty() && font_spec.rfind("systemfont_", 0) != 0) {
        if (auto sl = vfs.locate(font_spec); sl && sl->offset == 0) {
            return sl->disk_path.string();
        }
        if (auto sl = vfs.locate("fonts/" + font_spec); sl && sl->offset == 0) {
            return sl->disk_path.string();
        }
    }

    // Resolve systemfont_<name> via Fontconfig
    std::string family = "sans-serif";
    if (font_spec.rfind("systemfont_", 0) == 0) {
        family = font_spec.substr(11);
        if (family == "consolas" || family == "courier" || family == "couriernew") {
            family = "monospace";
        }
    } else if (!font_spec.empty()) {
        family = font_spec;
    }

    FcPattern* pat = FcNameParse(reinterpret_cast<const FcChar8*>(family.c_str()));
    FcConfigSubstitute(nullptr, pat, FcMatchPattern);
    FcDefaultSubstitute(pat);
    FcResult res;
    FcPattern* match = FcFontMatch(nullptr, pat, &res);
    std::string path;
    if (match) {
        FcChar8* file = nullptr;
        if (FcPatternGetString(match, FC_FILE, 0, &file) == FcResultMatch && file) {
            path = reinterpret_cast<const char*>(file);
        }
        FcPatternDestroy(match);
    }
    FcPatternDestroy(pat);
    return path;
}

bool TextRenderer::render_to_texture(const Vfs& vfs,
                                     const std::string& font_spec,
                                     float point_size,
                                     const std::string& text,
                                     int box_w,
                                     int box_h,
                                     const std::string& halign,
                                     const std::string& valign,
                                     GLuint& tex_id,
                                     int& out_w,
                                     int& out_h) {
    if (!ft_lib_) return false;
    std::string font_path = resolve_font_path(vfs, font_spec);
    if (font_path.empty()) return false;

    FT_Face face = nullptr;
    if (FT_New_Face(static_cast<FT_Library>(ft_lib_), font_path.c_str(), 0, &face) != 0) {
        return false;
    }

    // Wallpaper Engine pointsize maps roughly to 96 DPI (pt * 96 / 72 * 1.5 for crispness)
    int px_h = std::max(12, static_cast<int>(point_size * 2.0f));
    FT_Set_Pixel_Sizes(face, 0, static_cast<FT_UInt>(px_h));

    // Split text into lines
    std::vector<std::string> lines;
    {
        std::string cur;
        for (char c : text) {
            if (c == '\r') continue;
            if (c == '\n') { lines.push_back(cur); cur.clear(); }
            else cur.push_back(c);
        }
        lines.push_back(cur);
    }

    int line_h = static_cast<int>(face->size->metrics.height >> 6);
    if (line_h <= 0) line_h = px_h;
    int ascender = static_cast<int>(face->size->metrics.ascender >> 6);

    // Measure lines
    std::vector<int> line_widths(lines.size(), 0);
    int max_w = 1;
    for (size_t li = 0; li < lines.size(); ++li) {
        int pen = 0;
        size_t i = 0;
        while (i < lines[li].size()) {
            uint32_t cp = next_utf8(lines[li], i);
            if (FT_Load_Char(face, cp, FT_LOAD_DEFAULT) == 0) {
                pen += static_cast<int>(face->glyph->advance.x >> 6);
            }
        }
        line_widths[li] = pen;
        max_w = std::max(max_w, pen);
    }

    int total_h = std::max(1, static_cast<int>(lines.size()) * line_h);
    int w = std::max(box_w, max_w + 16);
    int h = std::max(box_h, total_h + 16);
    out_w = w;
    out_h = h;

    std::vector<uint8_t> rgba(static_cast<size_t>(w) * h * 4, 0);

    int start_y = 0;
    if (valign == "center") start_y = (h - total_h) / 2;
    else if (valign == "bottom") start_y = h - total_h;
    else start_y = 4;

    for (size_t li = 0; li < lines.size(); ++li) {
        int pen_x = 4;
        if (halign == "center") pen_x = (w - line_widths[li]) / 2;
        else if (halign == "right") pen_x = w - line_widths[li] - 4;
        int baseline_y = start_y + static_cast<int>(li) * line_h + ascender;

        size_t i = 0;
        while (i < lines[li].size()) {
            uint32_t cp = next_utf8(lines[li], i);
            if (FT_Load_Char(face, cp, FT_LOAD_RENDER) == 0) {
                FT_GlyphSlot g = face->glyph;
                const FT_Bitmap& bm = g->bitmap;
                int gx = pen_x + g->bitmap_left;
                int gy = baseline_y - g->bitmap_top;

                for (unsigned int row = 0; row < bm.rows; ++row) {
                    int dy = gy + static_cast<int>(row);
                    if (dy < 0 || dy >= h) continue;
                    for (unsigned int col = 0; col < bm.width; ++col) {
                        int dx = gx + static_cast<int>(col);
                        if (dx < 0 || dx >= w) continue;
                        uint8_t a = bm.buffer[row * bm.pitch + col];
                        if (a == 0) continue;
                        size_t idx = (static_cast<size_t>(dy) * w + dx) * 4;
                        rgba[idx + 0] = 255;
                        rgba[idx + 1] = 255;
                        rgba[idx + 2] = 255;
                        rgba[idx + 3] = std::max(rgba[idx + 3], a);
                    }
                }
                pen_x += static_cast<int>(g->advance.x >> 6);
            }
        }
    }

    FT_Done_Face(face);

    if (!tex_id) glGenTextures(1, &tex_id);
    glBindTexture(GL_TEXTURE_2D, tex_id);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, rgba.data());
    return true;
}

} // namespace sw
