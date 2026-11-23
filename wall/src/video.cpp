#include "video.hpp"

#include <GL/glext.h>
#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iostream>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>
#include <libswscale/swscale.h>
}

namespace sw {

namespace {

struct MemBio {
    const uint8_t* data;
    size_t size;
    size_t pos;
};

int mem_read(void* opaque, uint8_t* buf, int buf_size) {
    auto* m = static_cast<MemBio*>(opaque);
    if (m->pos >= m->size) return AVERROR_EOF;
    size_t avail = m->size - m->pos;
    size_t n = std::min(avail, static_cast<size_t>(buf_size));
    std::memcpy(buf, m->data + m->pos, n);
    m->pos += n;
    return static_cast<int>(n);
}

int64_t mem_seek(void* opaque, int64_t offset, int whence) {
    auto* m = static_cast<MemBio*>(opaque);
    if (whence == AVSEEK_SIZE) return static_cast<int64_t>(m->size);
    int64_t np = 0;
    if (whence == SEEK_SET) np = offset;
    else if (whence == SEEK_CUR) np = static_cast<int64_t>(m->pos) + offset;
    else if (whence == SEEK_END) np = static_cast<int64_t>(m->size) + offset;
    else return -1;
    if (np < 0 || np > static_cast<int64_t>(m->size)) return -1;
    m->pos = static_cast<size_t>(np);
    return np;
}

struct SliceBio {
    FILE* fp = nullptr;
    uint64_t base = 0;
    uint64_t size = 0;
    uint64_t pos = 0;
};

int slice_read(void* opaque, uint8_t* buf, int buf_size) {
    auto* s = static_cast<SliceBio*>(opaque);
    if (s->pos >= s->size) return AVERROR_EOF;
    uint64_t avail = s->size - s->pos;
    size_t n = static_cast<size_t>(std::min<uint64_t>(avail, static_cast<uint64_t>(buf_size)));
    size_t r = std::fread(buf, 1, n, s->fp);
    if (r == 0) return AVERROR_EOF;
    s->pos += r;
    return static_cast<int>(r);
}

int64_t slice_seek(void* opaque, int64_t offset, int whence) {
    auto* s = static_cast<SliceBio*>(opaque);
    if (whence == AVSEEK_SIZE) return static_cast<int64_t>(s->size);
    int64_t np = 0;
    if (whence == SEEK_SET) np = offset;
    else if (whence == SEEK_CUR) np = static_cast<int64_t>(s->pos) + offset;
    else if (whence == SEEK_END) np = static_cast<int64_t>(s->size) + offset;
    else return -1;
    if (np < 0 || np > static_cast<int64_t>(s->size)) return -1;
    if (::fseeko(s->fp, static_cast<off_t>(s->base + static_cast<uint64_t>(np)), SEEK_SET) != 0)
        return -1;
    s->pos = static_cast<uint64_t>(np);
    return np;
}

GLuint compile_simple_shader(GLenum type, const char* src) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    GLint ok = 0;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[1024];
        glGetShaderInfoLog(s, sizeof(log), nullptr, log);
        std::cerr << "[video] shader compile error: " << log << "\n";
        glDeleteShader(s);
        return 0;
    }
    return s;
}

GLuint build_yuv_program() {
    static const char* vs_src = R"GLSL(
#version 330 core
out vec2 v_uv;
void main() {
    vec2 pos[3] = vec2[3](vec2(-1.0, -1.0), vec2(3.0, -1.0), vec2(-1.0, 3.0));
    vec2 uv[3]  = vec2[3](vec2(0.0, 0.0),   vec2(2.0, 0.0),  vec2(0.0, 2.0));
    gl_Position = vec4(pos[gl_VertexID], 0.0, 1.0);
    v_uv = uv[gl_VertexID];
}
)GLSL";

    // Note: Video rows are top-to-bottom (row 0 = top), while Wallpaper Engine
    // texture UVs have (0,0) = top-left when uploaded raw into GL (so GL row 0
    // is the top of the image). Rendering without vertical flip keeps row 0 of
    // the output FBO matching the top row of the video!
    static const char* fs_src = R"GLSL(
#version 330 core
in vec2 v_uv;
out vec4 fragColor;
uniform sampler2D u_texY;
uniform sampler2D u_texU;
uniform sampler2D u_texV;
uniform int u_bt709;
uniform int u_fullRange;
void main() {
    float y = texture(u_texY, v_uv).r;
    float u = texture(u_texU, v_uv).r - 0.5;
    float v = texture(u_texV, v_uv).r - 0.5;
    if (u_fullRange == 0) {
        y = (y - 16.0 / 255.0) * (255.0 / 219.0);
        u = u * (255.0 / 224.0);
        v = v * (255.0 / 224.0);
    }
    vec3 rgb;
    if (u_bt709 != 0) {
        rgb.r = y + 1.5748 * v;
        rgb.g = y - 0.187324 * u - 0.468124 * v;
        rgb.b = y + 1.8556 * u;
    } else {
        rgb.r = y + 1.402 * v;
        rgb.g = y - 0.344136 * u - 0.714136 * v;
        rgb.b = y + 1.772 * u;
    }
    fragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0);
}
)GLSL";

    GLuint vs = compile_simple_shader(GL_VERTEX_SHADER, vs_src);
    GLuint fs = compile_simple_shader(GL_FRAGMENT_SHADER, fs_src);
    if (!vs || !fs) {
        if (vs) glDeleteShader(vs);
        if (fs) glDeleteShader(fs);
        return 0;
    }
    GLuint prog = glCreateProgram();
    glAttachShader(prog, vs);
    glAttachShader(prog, fs);
    glLinkProgram(prog);
    glDeleteShader(vs);
    glDeleteShader(fs);
    return prog;
}

} // namespace

bool decode_image_memory(const uint8_t* data, size_t size, DecodedImage& out) {
    if (!data || size == 0) return false;
    av_log_set_level(AV_LOG_ERROR);

    MemBio bio{data, size, 0};
    constexpr int kBufSize = 32768;
    uint8_t* avio_buf = static_cast<uint8_t*>(av_malloc(kBufSize));
    if (!avio_buf) return false;

    AVIOContext* avio = avio_alloc_context(avio_buf, kBufSize, 0, &bio, mem_read, nullptr, mem_seek);
    if (!avio) {
        av_free(avio_buf);
        return false;
    }

    AVFormatContext* fmt = avformat_alloc_context();
    fmt->pb = avio;
    fmt->flags |= AVFMT_FLAG_CUSTOM_IO;

    bool ok = false;
    AVCodecContext* dec = nullptr;
    AVFrame* frame = nullptr;
    AVPacket* pkt = nullptr;
    SwsContext* sws = nullptr;

    if (avformat_open_input(&fmt, "", nullptr, nullptr) == 0 &&
        avformat_find_stream_info(fmt, nullptr) >= 0) {
        int vidx = av_find_best_stream(fmt, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
        if (vidx >= 0) {
            AVStream* st = fmt->streams[vidx];
            const AVCodec* codec = avcodec_find_decoder(st->codecpar->codec_id);
            if (codec) {
                dec = avcodec_alloc_context3(codec);
                if (avcodec_parameters_to_context(dec, st->codecpar) >= 0 &&
                    avcodec_open2(dec, codec, nullptr) == 0) {
                    frame = av_frame_alloc();
                    pkt = av_packet_alloc();
                    while (av_read_frame(fmt, pkt) >= 0) {
                        if (pkt->stream_index == vidx) {
                            if (avcodec_send_packet(dec, pkt) == 0 &&
                                avcodec_receive_frame(dec, frame) == 0) {
                                out.width = frame->width;
                                out.height = frame->height;
                                out.rgba.resize(static_cast<size_t>(out.width) * out.height * 4);
                                sws = sws_getContext(frame->width, frame->height,
                                                     static_cast<AVPixelFormat>(frame->format),
                                                     out.width, out.height, AV_PIX_FMT_RGBA,
                                                     SWS_BILINEAR, nullptr, nullptr, nullptr);
                                if (sws) {
                                    uint8_t* dst[4] = {out.rgba.data(), nullptr, nullptr, nullptr};
                                    int dst_linesize[4] = {out.width * 4, 0, 0, 0};
                                    sws_scale(sws, frame->data, frame->linesize, 0, frame->height, dst, dst_linesize);
                                    ok = true;
                                }
                                av_packet_unref(pkt);
                                break;
                            }
                        }
                        av_packet_unref(pkt);
                    }
                }
            }
        }
    }

    if (sws) sws_freeContext(sws);
    if (pkt) av_packet_free(&pkt);
    if (frame) av_frame_free(&frame);
    if (dec) avcodec_free_context(&dec);
    if (fmt) {
        avformat_close_input(&fmt);
    }
    if (avio) {
        av_freep(&avio->buffer);
        avio_context_free(&avio);
    }
    return ok;
}

struct VideoDecoder::Impl {
    SliceBio bio;
    AVIOContext* avio = nullptr;
    AVFormatContext* fmt = nullptr;
    AVCodecContext* dec = nullptr;
    SwsContext* sws = nullptr;
    int vidx = -1;
    AVRational time_base{1, 30};
};

VideoDecoder::VideoDecoder() = default;

VideoDecoder::~VideoDecoder() {
    close();
}

bool VideoDecoder::open(const FileSlice& slice) {
    close();
    av_log_set_level(AV_LOG_ERROR);

    impl_ = std::make_unique<Impl>();
    impl_->bio.fp = std::fopen(slice.disk_path.c_str(), "rb");
    if (!impl_->bio.fp) {
        std::cerr << "[video] failed to open: " << slice.disk_path << "\n";
        impl_.reset();
        return false;
    }
    impl_->bio.base = slice.offset;
    impl_->bio.size = slice.size;
    impl_->bio.pos = 0;
    ::fseeko(impl_->bio.fp, static_cast<off_t>(slice.offset), SEEK_SET);

    constexpr int kBufSize = 65536;
    uint8_t* buf = static_cast<uint8_t*>(av_malloc(kBufSize));
    impl_->avio = avio_alloc_context(buf, kBufSize, 0, &impl_->bio, slice_read, nullptr, slice_seek);
    impl_->fmt = avformat_alloc_context();
    impl_->fmt->pb = impl_->avio;
    impl_->fmt->flags |= AVFMT_FLAG_CUSTOM_IO;

    if (avformat_open_input(&impl_->fmt, "", nullptr, nullptr) != 0 ||
        avformat_find_stream_info(impl_->fmt, nullptr) < 0) {
        std::cerr << "[video] avformat failed on " << slice.disk_path << "\n";
        close();
        return false;
    }

    impl_->vidx = av_find_best_stream(impl_->fmt, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
    if (impl_->vidx < 0) {
        close();
        return false;
    }

    AVStream* st = impl_->fmt->streams[impl_->vidx];
    const AVCodec* codec = avcodec_find_decoder(st->codecpar->codec_id);
    if (!codec) {
        close();
        return false;
    }

    impl_->dec = avcodec_alloc_context3(codec);
    avcodec_parameters_to_context(impl_->dec, st->codecpar);
    // Cap decode threads to 4 so 4K FF_THREAD_FRAME buffers stay lean in RAM
    unsigned hw_threads = std::thread::hardware_concurrency();
    impl_->dec->thread_count = static_cast<int>(std::clamp(hw_threads ? hw_threads : 2u, 2u, 4u));
    impl_->dec->thread_type = FF_THREAD_FRAME | FF_THREAD_SLICE;

    if (avcodec_open2(impl_->dec, codec, nullptr) != 0) {
        close();
        return false;
    }

    width_ = impl_->dec->width;
    height_ = impl_->dec->height;
    impl_->time_base = st->time_base;

    AVRational fr = av_guess_frame_rate(impl_->fmt, st, nullptr);
    if (fr.num > 0 && fr.den > 0) {
        fps_ = av_q2d(fr);
    } else {
        fps_ = 30.0;
    }
    if (fps_ < 1.0 || fps_ > 240.0) fps_ = 30.0;

    running_.store(true);
    thread_ = std::thread(&VideoDecoder::decode_loop, this);
    return true;
}

void VideoDecoder::close() {
    running_.store(false);
    {
        std::lock_guard<std::mutex> lk(pause_mtx_);
        paused_.store(false);
    }
    pause_cv_.notify_all();
    if (thread_.joinable()) thread_.join();

    if (impl_) {
        if (impl_->sws) sws_freeContext(impl_->sws);
        if (impl_->dec) avcodec_free_context(&impl_->dec);
        if (impl_->fmt) avformat_close_input(&impl_->fmt);
        if (impl_->avio) {
            av_freep(&impl_->avio->buffer);
            avio_context_free(&impl_->avio);
        }
        if (impl_->bio.fp) std::fclose(impl_->bio.fp);
        impl_.reset();
    }

    if (y_tex_) { glDeleteTextures(1, &y_tex_); y_tex_ = 0; }
    if (u_tex_) { glDeleteTextures(1, &u_tex_); u_tex_ = 0; }
    if (v_tex_) { glDeleteTextures(1, &v_tex_); v_tex_ = 0; }
    if (rgba_tex_) { glDeleteTextures(1, &rgba_tex_); rgba_tex_ = 0; }
    if (fbo_) { glDeleteFramebuffers(1, &fbo_); fbo_ = 0; }
    if (yuv_prog_) { glDeleteProgram(yuv_prog_); yuv_prog_ = 0; }
    if (dummy_vao_) { glDeleteVertexArrays(1, &dummy_vao_); dummy_vao_ = 0; }
    gl_w_ = gl_h_ = 0;
}

void VideoDecoder::set_paused(bool paused) {
    {
        std::lock_guard<std::mutex> lk(pause_mtx_);
        paused_.store(paused);
    }
    pause_cv_.notify_all();
}

void VideoDecoder::decode_loop() {
    AVPacket* pkt = av_packet_alloc();
    AVFrame* frame = av_frame_alloc();
    AVFrame* yuv_frame = av_frame_alloc();
    std::vector<uint8_t> sws_buf;
    int sws_w = 0, sws_h = 0;
    AVPixelFormat sws_fmt = AV_PIX_FMT_NONE;

    using clock = std::chrono::steady_clock;
    auto frame_dur = std::chrono::duration<double>(1.0 / fps_);
    auto next_pts_time = clock::now();

    while (running_.load()) {
        if (paused_.load()) {
            std::unique_lock<std::mutex> lk(pause_mtx_);
            pause_cv_.wait(lk, [&] { return !paused_.load() || !running_.load(); });
            next_pts_time = clock::now();
            continue;
        }

        int ret = av_read_frame(impl_->fmt, pkt);
        if (ret == AVERROR_EOF) {
            // Seamless loop back to start
            av_seek_frame(impl_->fmt, impl_->vidx, 0, AVSEEK_FLAG_BACKWARD);
            avcodec_flush_buffers(impl_->dec);
            continue;
        }
        if (ret < 0) {
            std::this_thread::sleep_for(std::chrono::milliseconds(5));
            continue;
        }

        if (pkt->stream_index != impl_->vidx) {
            av_packet_unref(pkt);
            continue;
        }

        if (avcodec_send_packet(impl_->dec, pkt) == 0) {
            while (running_.load() && avcodec_receive_frame(impl_->dec, frame) == 0) {
                AVFrame* src = frame;
                bool is_yuv420 = (frame->format == AV_PIX_FMT_YUV420P || frame->format == AV_PIX_FMT_YUVJ420P);

                if (!is_yuv420) {
                    if (!impl_->sws || sws_w != frame->width || sws_h != frame->height ||
                        sws_fmt != static_cast<AVPixelFormat>(frame->format)) {
                        if (impl_->sws) sws_freeContext(impl_->sws);
                        sws_w = frame->width;
                        sws_h = frame->height;
                        sws_fmt = static_cast<AVPixelFormat>(frame->format);
                        impl_->sws = sws_getContext(sws_w, sws_h, sws_fmt,
                                                    sws_w, sws_h, AV_PIX_FMT_YUV420P,
                                                    SWS_FAST_BILINEAR, nullptr, nullptr, nullptr);
                        int nbytes = av_image_get_buffer_size(AV_PIX_FMT_YUV420P, sws_w, sws_h, 1);
                        sws_buf.resize(static_cast<size_t>(nbytes));
                        av_image_fill_arrays(yuv_frame->data, yuv_frame->linesize, sws_buf.data(),
                                             AV_PIX_FMT_YUV420P, sws_w, sws_h, 1);
                        yuv_frame->width = sws_w;
                        yuv_frame->height = sws_h;
                        yuv_frame->format = AV_PIX_FMT_YUV420P;
                    }
                    sws_scale(impl_->sws, frame->data, frame->linesize, 0, frame->height,
                              yuv_frame->data, yuv_frame->linesize);
                    src = yuv_frame;
                }

                int w = src->width;
                int h = src->height;
                int cw = (w + 1) / 2;
                int ch = (h + 1) / 2;

                // Pace playback cleanly to the video's native frame rate
                auto now = clock::now();
                if (next_pts_time > now) {
                    auto diff = next_pts_time - now;
                    if (diff < std::chrono::milliseconds(200)) {
                        std::this_thread::sleep_until(next_pts_time);
                    } else {
                        next_pts_time = now;
                    }
                }
                next_pts_time += std::chrono::duration_cast<clock::duration>(frame_dur);

                {
                    std::lock_guard<std::mutex> lk(frame_mtx_);
                    y_plane_.resize(static_cast<size_t>(w) * h);
                    u_plane_.resize(static_cast<size_t>(cw) * ch);
                    v_plane_.resize(static_cast<size_t>(cw) * ch);

                    for (int row = 0; row < h; ++row) {
                        std::memcpy(y_plane_.data() + static_cast<size_t>(row) * w,
                                    src->data[0] + row * src->linesize[0], static_cast<size_t>(w));
                    }
                    for (int row = 0; row < ch; ++row) {
                        std::memcpy(u_plane_.data() + static_cast<size_t>(row) * cw,
                                    src->data[1] + row * src->linesize[1], static_cast<size_t>(cw));
                        std::memcpy(v_plane_.data() + static_cast<size_t>(row) * cw,
                                    src->data[2] + row * src->linesize[2], static_cast<size_t>(cw));
                    }
                    frame_w_ = w;
                    frame_h_ = h;
                    color_bt709_ = (frame->colorspace == AVCOL_SPC_BT709 ||
                                    (frame->colorspace == AVCOL_SPC_UNSPECIFIED && h >= 720));
                    color_full_range_ = (frame->color_range == AVCOL_RANGE_JPEG ||
                                         frame->format == AV_PIX_FMT_YUVJ420P);
                    frame_dirty_ = true;
                }
            }
        }
        av_packet_unref(pkt);
    }

    av_frame_free(&yuv_frame);
    av_frame_free(&frame);
    av_packet_free(&pkt);
}

void VideoDecoder::ensure_gl_resources() {
    if (!yuv_prog_) {
        yuv_prog_ = build_yuv_program();
        glGenVertexArrays(1, &dummy_vao_);
    }
    if (gl_w_ == frame_w_ && gl_h_ == frame_h_ && rgba_tex_ != 0) return;

    gl_w_ = frame_w_;
    gl_h_ = frame_h_;
    int cw = (gl_w_ + 1) / 2;
    int ch = (gl_h_ + 1) / 2;

    auto make_plane = [](GLuint& tex, int w, int h) {
        if (!tex) glGenTextures(1, &tex);
        glBindTexture(GL_TEXTURE_2D, tex);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, w, h, 0, GL_RED, GL_UNSIGNED_BYTE, nullptr);
    };

    make_plane(y_tex_, gl_w_, gl_h_);
    make_plane(u_tex_, cw, ch);
    make_plane(v_tex_, cw, ch);

    if (!rgba_tex_) glGenTextures(1, &rgba_tex_);
    glBindTexture(GL_TEXTURE_2D, rgba_tex_);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, gl_w_, gl_h_, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);

    if (!fbo_) glGenFramebuffers(1, &fbo_);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo_);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, rgba_tex_, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void VideoDecoder::update_gl() {
    std::lock_guard<std::mutex> lk(frame_mtx_);
    if (!frame_dirty_ || frame_w_ <= 0 || frame_h_ <= 0) return;

    ensure_gl_resources();

    int cw = (gl_w_ + 1) / 2;
    int ch = (gl_h_ + 1) / 2;

    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glBindTexture(GL_TEXTURE_2D, y_tex_);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, gl_w_, gl_h_, GL_RED, GL_UNSIGNED_BYTE, y_plane_.data());
    glBindTexture(GL_TEXTURE_2D, u_tex_);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, cw, ch, GL_RED, GL_UNSIGNED_BYTE, u_plane_.data());
    glBindTexture(GL_TEXTURE_2D, v_tex_);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, cw, ch, GL_RED, GL_UNSIGNED_BYTE, v_plane_.data());
    frame_dirty_ = false;

    // Save current GL state that we modify
    GLint prev_fbo = 0, prev_vp[4] = {0, 0, 0, 0}, prev_prog = 0;
    GLboolean prev_blend = glIsEnabled(GL_BLEND);
    GLboolean prev_depth = glIsEnabled(GL_DEPTH_TEST);
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &prev_fbo);
    glGetIntegerv(GL_VIEWPORT, prev_vp);
    glGetIntegerv(GL_CURRENT_PROGRAM, &prev_prog);

    glBindFramebuffer(GL_FRAMEBUFFER, fbo_);
    glViewport(0, 0, gl_w_, gl_h_);
    glDisable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);

    glUseProgram(yuv_prog_);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, y_tex_);
    glUniform1i(glGetUniformLocation(yuv_prog_, "u_texY"), 0);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, u_tex_);
    glUniform1i(glGetUniformLocation(yuv_prog_, "u_texU"), 1);
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, v_tex_);
    glUniform1i(glGetUniformLocation(yuv_prog_, "u_texV"), 2);
    glUniform1i(glGetUniformLocation(yuv_prog_, "u_bt709"), color_bt709_ ? 1 : 0);
    glUniform1i(glGetUniformLocation(yuv_prog_, "u_fullRange"), color_full_range_ ? 1 : 0);

    glBindVertexArray(dummy_vao_);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glBindVertexArray(0);

    if (prev_blend) glEnable(GL_BLEND);
    if (prev_depth) glEnable(GL_DEPTH_TEST);
    glUseProgram(prev_prog);
    glBindFramebuffer(GL_FRAMEBUFFER, prev_fbo);
    glViewport(prev_vp[0], prev_vp[1], prev_vp[2], prev_vp[3]);
}

} // namespace sw
