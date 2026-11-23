#pragma once

#include "vfs.hpp"

#include <GL/gl.h>
#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>

namespace sw {

struct DecodedImage {
    int width = 0;
    int height = 0;
    std::vector<uint8_t> rgba;
};

// Decode a compressed image (PNG, JPEG, BMP, TGA, WebP, GIF, etc.) from memory using FFmpeg
bool decode_image_memory(const uint8_t* data, size_t size, DecodedImage& out);

// Streaming hardware-friendly video decoder with GPU YUV420P -> RGBA conversion.
// Streams directly from a FileSlice (works for both standalone .mp4/.webm files
// and MP4 payloads embedded inside scene.pkg .tex entries with minimal RAM).
class VideoDecoder {
public:
    VideoDecoder();
    ~VideoDecoder();

    VideoDecoder(const VideoDecoder&) = delete;
    VideoDecoder& operator=(const VideoDecoder&) = delete;

    bool open(const FileSlice& slice);
    void close();

    void set_paused(bool paused);
    bool is_paused() const { return paused_.load(); }

    // Upload the latest decoded frame (if ready) and convert YUV->RGB into the output GL texture.
    // Call from the OpenGL thread each frame.
    void update_gl();

    GLuint texture() const { return rgba_tex_; }
    int width() const { return width_; }
    int height() const { return height_; }
    double fps() const { return fps_; }

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;

    void decode_loop();
    void ensure_gl_resources();

    std::thread thread_;
    std::atomic<bool> running_{false};
    std::atomic<bool> paused_{false};
    std::mutex pause_mtx_;
    std::condition_variable pause_cv_;

    // Latest decoded planar YUV420P frame waiting for GL upload
    std::mutex frame_mtx_;
    std::vector<uint8_t> y_plane_;
    std::vector<uint8_t> u_plane_;
    std::vector<uint8_t> v_plane_;
    int frame_w_ = 0;
    int frame_h_ = 0;
    bool color_bt709_ = true;
    bool color_full_range_ = false;
    bool frame_dirty_ = false;

    int width_ = 0;
    int height_ = 0;
    double fps_ = 30.0;

    // GL resources (owned by GL thread)
    GLuint y_tex_ = 0;
    GLuint u_tex_ = 0;
    GLuint v_tex_ = 0;
    GLuint rgba_tex_ = 0;
    GLuint fbo_ = 0;
    GLuint yuv_prog_ = 0;
    GLuint dummy_vao_ = 0;
    int gl_w_ = 0;
    int gl_h_ = 0;
};

} // namespace sw
