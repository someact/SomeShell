#include "tex.hpp"

#include <GL/glext.h>
#include <lz4.h>

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iostream>

namespace sw {

namespace {

constexpr uint32_t kFlagNoInterpolation = 1u << 0;
constexpr uint32_t kFlagClampUVs        = 1u << 1;
constexpr uint32_t kFlagIsGif           = 1u << 2;
constexpr uint32_t kFlagIsVideoTexture  = 1u << 5;

// Wallpaper Engine TEXI format field values -> TexFormat
TexFormat map_we_format(uint32_t fmt) {
    switch (fmt) {
        case 0: return TexFormat::RGBA8888;
        case 4: return TexFormat::DXT5;
        case 6: return TexFormat::DXT3;
        case 7: return TexFormat::DXT1;
        case 8: return TexFormat::RG88;
        case 9: return TexFormat::R8;
        case 10: return TexFormat::RG1616F;
        case 11: return TexFormat::R16F;
        case 12: return TexFormat::BC7;
        default: return TexFormat::RGBA8888;
    }
}

void apply_tex_params(GLuint id, uint32_t flags, bool has_mips) {
    glBindTexture(GL_TEXTURE_2D, id);
    bool nearest = (flags & kFlagNoInterpolation) != 0;
    bool clamp = (flags & kFlagClampUVs) != 0;
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, nearest ? GL_NEAREST : GL_LINEAR);
    if (has_mips) {
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,
                        nearest ? GL_NEAREST_MIPMAP_NEAREST : GL_LINEAR_MIPMAP_LINEAR);
    } else {
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, nearest ? GL_NEAREST : GL_LINEAR);
    }
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, clamp ? GL_CLAMP_TO_EDGE : GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, clamp ? GL_CLAMP_TO_EDGE : GL_REPEAT);
}

void upload_mip_raw(int level, int w, int h, TexFormat fmt, const uint8_t* data, size_t size) {
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    switch (fmt) {
        case TexFormat::RGBA8888:
            glTexImage2D(GL_TEXTURE_2D, level, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
            break;
        case TexFormat::RG88:
            glTexImage2D(GL_TEXTURE_2D, level, GL_RG8, w, h, 0, GL_RG, GL_UNSIGNED_BYTE, data);
            break;
        case TexFormat::R8:
            glTexImage2D(GL_TEXTURE_2D, level, GL_R8, w, h, 0, GL_RED, GL_UNSIGNED_BYTE, data);
            break;
        case TexFormat::DXT1:
            glCompressedTexImage2D(GL_TEXTURE_2D, level, GL_COMPRESSED_RGBA_S3TC_DXT1_EXT, w, h, 0,
                                   static_cast<GLsizei>(size), data);
            break;
        case TexFormat::DXT3:
            glCompressedTexImage2D(GL_TEXTURE_2D, level, GL_COMPRESSED_RGBA_S3TC_DXT3_EXT, w, h, 0,
                                   static_cast<GLsizei>(size), data);
            break;
        case TexFormat::DXT5:
            glCompressedTexImage2D(GL_TEXTURE_2D, level, GL_COMPRESSED_RGBA_S3TC_DXT5_EXT, w, h, 0,
                                   static_cast<GLsizei>(size), data);
            break;
        case TexFormat::BC7:
            glCompressedTexImage2D(GL_TEXTURE_2D, level, GL_COMPRESSED_RGBA_BPTC_UNORM, w, h, 0,
                                   static_cast<GLsizei>(size), data);
            break;
        case TexFormat::RG1616F:
            glTexImage2D(GL_TEXTURE_2D, level, GL_RG16F, w, h, 0, GL_RG, GL_HALF_FLOAT, data);
            break;
        case TexFormat::R16F:
            glTexImage2D(GL_TEXTURE_2D, level, GL_R16F, w, h, 0, GL_RED, GL_HALF_FLOAT, data);
            break;
        default:
            glTexImage2D(GL_TEXTURE_2D, level, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
            break;
    }
}

struct BinReader {
    const uint8_t* data = nullptr;
    size_t size = 0;
    size_t pos = 0;

    bool read(void* dst, size_t n) {
        if (pos + n > size) return false;
        std::memcpy(dst, data + pos, n);
        pos += n;
        return true;
    }
    bool read_u32(uint32_t& v) { return read(&v, 4); }
    bool read_i32(int32_t& v) { return read(&v, 4); }
    bool read_f32(float& v) { return read(&v, 4); }
    std::string read_cstr9() {
        if (pos + 9 > size) return {};
        std::string s(reinterpret_cast<const char*>(data + pos), 8);
        pos += 9; // 8 chars + null terminator
        return s;
    }
};

} // namespace

Texture::~Texture() {
    video.reset();
    if (id != 0) {
        glDeleteTextures(1, &id);
        id = 0;
    }
}

std::unique_ptr<Texture> TextureCache::make_solid(uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
    auto t = std::make_unique<Texture>();
    t->tex_width = t->img_width = 1;
    t->tex_height = t->img_height = 1;
    glGenTextures(1, &t->id);
    apply_tex_params(t->id, kFlagClampUVs, false);
    uint8_t px[4] = {r, g, b, a};
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, px);
    return t;
}

Texture* TextureCache::white() {
    if (!white_) white_ = make_solid(255, 255, 255, 255);
    return white_.get();
}

Texture* TextureCache::black() {
    if (!black_) black_ = make_solid(0, 0, 0, 255);
    return black_.get();
}

void TextureCache::update_videos() {
    for (auto& [k, t] : cache_) {
        if (t && t->video) t->video->update_gl();
    }
}

void TextureCache::set_paused(bool paused) {
    for (auto& [k, t] : cache_) {
        if (t && t->video) t->video->set_paused(paused);
    }
}

void TextureCache::clear() {
    cache_.clear();
    white_.reset();
    black_.reset();
}

Texture* TextureCache::load(const std::string& name) {
    if (name.empty()) return white();
    if (auto it = cache_.find(name); it != cache_.end()) return it->second.get();

    // Candidate paths for a Wallpaper Engine texture reference
    std::vector<std::string> candidates;
    if (name.size() > 4 && name.substr(name.size() - 4) == ".tex") {
        candidates.push_back(name);
        candidates.push_back("materials/" + name);
    } else {
        candidates.push_back("materials/" + name + ".tex");
        candidates.push_back(name + ".tex");
        candidates.push_back(name);
        candidates.push_back("materials/" + name);
        candidates.push_back("materials/" + name + ".png");
        candidates.push_back("materials/" + name + ".jpg");
    }

    for (const auto& c : candidates) {
        if (auto slice = vfs_.locate(c)) {
            std::unique_ptr<Texture> tex;
            if (c.size() >= 4 && c.substr(c.size() - 4) == ".tex") {
                tex = load_tex_file(*slice, c);
            } else {
                tex = load_regular_image(*slice);
            }
            if (tex) {
                Texture* raw = tex.get();
                cache_[name] = std::move(tex);
                return raw;
            }
        }
    }

    std::cerr << "[tex] missing texture: " << name << "\n";
    return white();
}

std::unique_ptr<Texture> TextureCache::load_regular_image(const FileSlice& slice) {
    std::ifstream f(slice.disk_path, std::ios::binary);
    if (!f) return nullptr;
    f.seekg(static_cast<std::streamoff>(slice.offset));
    std::vector<uint8_t> buf(slice.size);
    f.read(reinterpret_cast<char*>(buf.data()), static_cast<std::streamsize>(slice.size));

    DecodedImage img;
    if (!decode_image_memory(buf.data(), buf.size(), img)) return nullptr;

    auto t = std::make_unique<Texture>();
    t->tex_width = t->img_width = img.width;
    t->tex_height = t->img_height = img.height;
    t->format = TexFormat::RGBA8888;
    glGenTextures(1, &t->id);
    apply_tex_params(t->id, kFlagClampUVs, false);
    upload_mip_raw(0, img.width, img.height, TexFormat::RGBA8888, img.rgba.data(), img.rgba.size());
    return t;
}

std::unique_ptr<Texture> TextureCache::load_tex_file(const FileSlice& slice, const std::string& debug_name) {
    // First read only a 256-byte header to check whether this is a huge video-in-TEX!
    // That way we NEVER allocate 188 MB in RAM for a 4K video texture.
    std::ifstream f(slice.disk_path, std::ios::binary);
    if (!f) return nullptr;
    f.seekg(static_cast<std::streamoff>(slice.offset));

    uint8_t hdr[256] = {};
    size_t hdr_read = std::min<size_t>(sizeof(hdr), slice.size);
    f.read(reinterpret_cast<char*>(hdr), static_cast<std::streamsize>(hdr_read));
    if (!f) return nullptr;

    BinReader hr{hdr, hdr_read, 0};
    std::string magic_v = hr.read_cstr9();
    std::string magic_i = hr.read_cstr9();
    if (magic_v.rfind("TEXV", 0) != 0 || magic_i.rfind("TEXI", 0) != 0) {
        std::cerr << "[tex] invalid TEX magic in " << debug_name << "\n";
        return nullptr;
    }

    uint32_t fmt_raw = 0, flags = 0, tex_w = 0, tex_h = 0, img_w = 0, img_h = 0, unk = 0;
    hr.read_u32(fmt_raw);
    hr.read_u32(flags);
    hr.read_u32(tex_w);
    hr.read_u32(tex_h);
    hr.read_u32(img_w);
    hr.read_u32(img_h);
    hr.read_u32(unk);

    std::string magic_b = hr.read_cstr9();
    if (magic_b.rfind("TEXB", 0) != 0) {
        std::cerr << "[tex] invalid TEXB magic in " << debug_name << "\n";
        return nullptr;
    }
    int texb_ver = std::atoi(magic_b.c_str() + 4);

    uint32_t img_count = 0;
    hr.read_u32(img_count);
    int32_t free_img_fmt = -1;
    if (texb_ver >= 3) hr.read_i32(free_img_fmt);
    uint32_t is_video_mp4 = 0;
    if (texb_ver >= 4) hr.read_u32(is_video_mp4);

    uint32_t mip_count = 0;
    hr.read_u32(mip_count);

    // Peek first mipmap header to detect MP4 video texture without reading the whole file
    uint32_t m0_w = 0, m0_h = 0, m0_lz4 = 0, m0_decomp = 0, m0_sz = 0;
    hr.read_u32(m0_w);
    hr.read_u32(m0_h);
    if (texb_ver >= 2) {
        hr.read_u32(m0_lz4);
        hr.read_u32(m0_decomp);
    }
    hr.read_u32(m0_sz);
    size_t m0_offset_in_tex = hr.pos;

    bool looks_like_mp4 = ((flags & kFlagIsVideoTexture) != 0) || (is_video_mp4 == 1) || (free_img_fmt == 35);
    if (!looks_like_mp4 && m0_offset_in_tex + 12 <= hdr_read) {
        if (std::memcmp(hdr + m0_offset_in_tex + 4, "ftyp", 4) == 0) {
            looks_like_mp4 = true;
        }
    }

    if (looks_like_mp4 && m0_lz4 == 0 && m0_sz > 0) {
        auto t = std::make_unique<Texture>();
        t->tex_width = static_cast<int>(tex_w);
        t->tex_height = static_cast<int>(tex_h);
        t->img_width = static_cast<int>(img_w ? img_w : tex_w);
        t->img_height = static_cast<int>(img_h ? img_h : tex_h);
        t->format = TexFormat::RGBA8888;
        t->flags = flags;

        FileSlice vid_slice{slice.disk_path, slice.offset + m0_offset_in_tex, m0_sz};
        t->video = std::make_unique<VideoDecoder>();
        if (!t->video->open(vid_slice)) {
            std::cerr << "[tex] failed to open embedded video in " << debug_name << "\n";
            return nullptr;
        }
        // Fallback 1x1 black texture until first video frame arrives
        glGenTextures(1, &t->id);
        apply_tex_params(t->id, flags, false);
        uint8_t blk[4] = {0, 0, 0, 255};
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, blk);
        std::cerr << "[tex] streaming video-in-TEX: " << debug_name
                  << " (" << t->img_width << "x" << t->img_height << ", " << t->video->fps() << " fps)\n";
        return t;
    }

    // Normal image/spritesheet TEX: read the full entry
    std::vector<uint8_t> raw(slice.size);
    f.seekg(static_cast<std::streamoff>(slice.offset));
    f.read(reinterpret_cast<char*>(raw.data()), static_cast<std::streamsize>(slice.size));
    if (!f) return nullptr;

    BinReader r{raw.data(), raw.size(), 0};
    r.read_cstr9(); // TEXV
    r.read_cstr9(); // TEXI
    r.pos += 28;    // fmt, flags, texW, texH, imgW, imgH, unk
    r.read_cstr9(); // TEXB
    r.read_u32(img_count);
    if (texb_ver >= 3) r.read_i32(free_img_fmt);
    if (texb_ver >= 4) r.read_u32(is_video_mp4);

    auto t = std::make_unique<Texture>();
    t->tex_width = static_cast<int>(tex_w);
    t->tex_height = static_cast<int>(tex_h);
    t->img_width = static_cast<int>(img_w ? img_w : tex_w);
    t->img_height = static_cast<int>(img_h ? img_h : tex_h);
    t->format = map_we_format(fmt_raw);
    t->flags = flags;

    glGenTextures(1, &t->id);
    glBindTexture(GL_TEXTURE_2D, t->id);

    int uploaded_mips = 0;
    for (uint32_t img_i = 0; img_i < img_count; ++img_i) {
        uint32_t mcount = 0;
        if (!r.read_u32(mcount)) break;
        for (uint32_t m = 0; m < mcount; ++m) {
            uint32_t mw = 0, mh = 0, lz4 = 0, decomp_sz = 0, data_sz = 0;
            if (!r.read_u32(mw) || !r.read_u32(mh)) break;
            if (texb_ver >= 2) {
                r.read_u32(lz4);
                r.read_u32(decomp_sz);
            }
            if (!r.read_u32(data_sz) || r.pos + data_sz > r.size) break;
            const uint8_t* payload = r.data + r.pos;
            r.pos += data_sz;

            // Upload only image 0 into our GL_TEXTURE_2D (still consume remaining images so TEXS parses cleanly)
            if (img_i != 0) continue;

            std::vector<uint8_t> decomp;
            const uint8_t* src_ptr = payload;
            size_t src_sz = data_sz;
            if (lz4 != 0 && decomp_sz > 0) {
                decomp.resize(decomp_sz);
                int res = LZ4_decompress_safe(reinterpret_cast<const char*>(payload),
                                              reinterpret_cast<char*>(decomp.data()),
                                              static_cast<int>(data_sz),
                                              static_cast<int>(decomp_sz));
                if (res < 0) {
                    std::cerr << "[tex] LZ4 decompress failed in " << debug_name << "\n";
                    continue;
                }
                src_ptr = decomp.data();
                src_sz = static_cast<size_t>(res);
            }

            if (free_img_fmt >= 0) {
                // Embedded PNG/JPG/BMP/TGA/etc.
                if (m == 0) {
                    DecodedImage dec;
                    if (decode_image_memory(src_ptr, src_sz, dec)) {
                        t->format = TexFormat::RGBA8888;
                        t->tex_width = dec.width;
                        t->tex_height = dec.height;
                        upload_mip_raw(0, dec.width, dec.height, TexFormat::RGBA8888, dec.rgba.data(), dec.rgba.size());
                        uploaded_mips = 1;
                    }
                }
            } else {
                upload_mip_raw(static_cast<int>(m), static_cast<int>(mw), static_cast<int>(mh),
                               t->format, src_ptr, src_sz);
                uploaded_mips++;
            }
        }
    }

    apply_tex_params(t->id, flags, uploaded_mips > 1);
    if (uploaded_mips > 0) {
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, uploaded_mips - 1);
    }

    // Parse optional TEXS spritesheet metadata trailer
    if (r.pos + 9 <= r.size && std::memcmp(r.data + r.pos, "TEXS", 4) == 0) {
        std::string magic_s = r.read_cstr9();
        int texs_ver = std::atoi(magic_s.c_str() + 4);
        uint32_t frame_count = 0;
        r.read_u32(frame_count);
        if (texs_ver >= 3) {
            uint32_t gw = 0, gh = 0;
            r.read_u32(gw);
            r.read_u32(gh);
            t->sprite_width = static_cast<int>(gw);
            t->sprite_height = static_cast<int>(gh);
        }
        t->frames.reserve(frame_count);
        for (uint32_t fi = 0; fi < frame_count; ++fi) {
            SpriteFrame sf;
            r.read_u32(sf.image_id);
            r.read_f32(sf.frametime);
            if (texs_ver == 1) {
                int32_t x = 0, y = 0, w = 0, wy = 0, hx = 0, h = 0;
                r.read_i32(x); r.read_i32(y);
                r.read_i32(w); r.read_i32(wy);
                r.read_i32(hx); r.read_i32(h);
                sf.x = static_cast<float>(x);
                sf.y = static_cast<float>(y);
                sf.width = static_cast<float>(w);
                sf.width_y = static_cast<float>(wy);
                sf.height_x = static_cast<float>(hx);
                sf.height = static_cast<float>(h);
            } else {
                r.read_f32(sf.x); r.read_f32(sf.y);
                r.read_f32(sf.width); r.read_f32(sf.width_y);
                r.read_f32(sf.height_x); r.read_f32(sf.height);
            }
            t->frames.push_back(sf);
        }
        if (!t->frames.empty()) {
            t->is_spritesheet = true;
            if (t->sprite_width == 0) t->sprite_width = static_cast<int>(std::abs(t->frames[0].width));
            if (t->sprite_height == 0) t->sprite_height = static_cast<int>(std::abs(t->frames[0].height));
        }
    }

    return t;
}

} // namespace sw
