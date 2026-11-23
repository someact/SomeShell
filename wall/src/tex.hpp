#pragma once

#include "vfs.hpp"
#include "video.hpp"

#include <GL/gl.h>
#include <cstdint>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

namespace sw {

struct SpriteFrame {
    uint32_t image_id = 0;
    float frametime = 0.1f;
    float x = 0.0f;
    float y = 0.0f;
    float width = 0.0f;
    float width_y = 0.0f;
    float height_x = 0.0f;
    float height = 0.0f;
};

// Matches Wallpaper Engine's FORMAT_* constants in common_fragment.h
enum class TexFormat : int {
    RGBA8888 = 0,
    RGB888 = 1,
    RGB565 = 2,
    ETC1 = 3,
    DXT5 = 4,
    ETC2 = 5,
    DXT3 = 6,
    DXT1 = 7,
    RG88 = 8,
    R8 = 9,
    RG1616F = 10,
    R16F = 11,
    BC7 = 12,
};

struct Texture {
    GLuint id = 0;
    int tex_width = 1;
    int tex_height = 1;
    int img_width = 1;
    int img_height = 1;
    TexFormat format = TexFormat::RGBA8888;
    uint32_t flags = 0;

    // Spritesheet metadata (TEXS0001..0003)
    bool is_spritesheet = false;
    int sprite_width = 0;
    int sprite_height = 0;
    std::vector<SpriteFrame> frames;

    // Optional streaming video-in-TEX
    std::unique_ptr<VideoDecoder> video;

    GLuint gl_id() const {
        if (video && video->texture() != 0) return video->texture();
        return id;
    }

    ~Texture();
    Texture() = default;
    Texture(const Texture&) = delete;
    Texture& operator=(const Texture&) = delete;
};

class TextureCache {
public:
    explicit TextureCache(const Vfs& vfs) : vfs_(vfs) {}
    ~TextureCache() { clear(); }

    // Load a texture by WE material texture name (e.g. "particle/nature/rosepetals"
    // -> looks up "materials/particle/nature/rosepetals.tex", or direct path).
    Texture* load(const std::string& name);
    Texture* white();
    Texture* black();

    void update_videos();
    // The decoders of the videos inside the scene, e.g. "h264 (cuda)"
    std::string video_decoders() const;
    void set_paused(bool paused);
    void set_speed(float speed);
    void clear();

private:
    std::unique_ptr<Texture> load_tex_file(const FileSlice& slice, const std::string& debug_name);
    std::unique_ptr<Texture> load_regular_image(const FileSlice& slice);
    std::unique_ptr<Texture> make_solid(uint8_t r, uint8_t g, uint8_t b, uint8_t a);

    const Vfs& vfs_;
    std::unordered_map<std::string, std::unique_ptr<Texture>> cache_;
    std::unique_ptr<Texture> white_;
    std::unique_ptr<Texture> black_;
};

} // namespace sw
