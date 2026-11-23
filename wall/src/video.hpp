#pragma once

#include "vfs.hpp"

#include <GL/gl.h>
#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
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

// How video is decoded: "auto" picks a hardware device (CUDA when GL runs on
// NVIDIA, else VAAPI, then Vulkan; V4L2 m2m on aarch64), "none" forces the CPU,
// or one name. Set once at start (--hwdec, SOMEWALL_HWDEC).
void set_hwdec_preference(const std::string& pref, const std::string& gl_vendor);

// Streaming video decoder. Frames stay in the decoder's own buffers (a
// reference is kept, nothing is copied on the CPU after a hardware download)
// and are converted YUV -> RGBA on the GPU. Streams from a FileSlice, so it
// works for plain files and for MP4 payloads inside scene.pkg .tex entries.
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
    // Playback speed: frames are paced at fps * speed
    void set_speed(float speed) { speed_.store(speed); }

    // Upload the latest decoded frame (if a new one is ready) and convert it
    // into the output texture. GL thread only. True when a new frame arrived.
    bool update_gl();

    // Readable (eventfd) whenever a new frame waits: poll it to sleep until
    // the next frame instead of drawing on a timer
    int frame_fd() const { return frame_fd_; }

    GLuint texture() const { return rgba_tex_; }
    int width() const { return width_; }
    int height() const { return height_; }
    double fps() const { return fps_; }
    // The decoder in use, e.g. "h264 (cuda)" or "hevc (cpu)"
    const std::string& decoder_name() const { return decoder_name_; }

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;

    bool open_codec(bool try_hw);
    void decode_loop();
    void ensure_gl_resources(int w, int h, bool semi_planar, bool wide);

    std::thread thread_;
    std::atomic<bool> running_{false};
    std::atomic<bool> paused_{false};
    std::atomic<float> speed_{1.0f};
    std::mutex pause_mtx_;
    std::condition_variable pause_cv_;

    // The latest decoded frame waiting for upload (an AVFrame, owned)
    std::mutex frame_mtx_;
    void* pending_ = nullptr;
    int frame_fd_ = -1;

    int width_ = 0;
    int height_ = 0;
    double fps_ = 30.0;
    std::string decoder_name_;

    // GL resources (owned by GL thread)
    GLuint y_tex_ = 0;
    GLuint u_tex_ = 0;   // U plane, or the interleaved UV plane (NV12/P010)
    GLuint v_tex_ = 0;
    GLuint rgba_tex_ = 0;
    GLuint fbo_ = 0;
    GLuint yuv_prog_ = 0;
    GLuint dummy_vao_ = 0;
    int gl_w_ = 0;
    int gl_h_ = 0;
    bool gl_semi_planar_ = false;
    bool gl_wide_ = false;
};

} // namespace sw
