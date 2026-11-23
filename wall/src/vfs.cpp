#include "vfs.hpp"

#include <algorithm>
#include <cctype>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iostream>

namespace sw {

namespace fs = std::filesystem;

std::string Vfs::normalize(const std::string& p) {
    std::string out;
    out.reserve(p.size());
    for (char c : p) {
        if (c == '\\') c = '/';
        if (c == '/' && !out.empty() && out.back() == '/') continue;
        out.push_back(c);
    }
    while (!out.empty() && out.front() == '/') out.erase(out.begin());
    if (out.rfind("./", 0) == 0) out.erase(0, 2);
    return out;
}

static std::string to_lower(const std::string& s) {
    std::string r = s;
    for (char& c : r) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return r;
}

void Vfs::set_assets_dir(const fs::path& assets_dir) {
    assets_dir_ = assets_dir;
}

void Vfs::add_extra_dir(const fs::path& dir) {
    std::error_code ec;
    if (!fs::is_directory(dir, ec)) return;
    if (std::find(extra_dirs_.begin(), extra_dirs_.end(), dir) == extra_dirs_.end()) {
        extra_dirs_.push_back(dir);
    }
}

bool Vfs::mount_wallpaper(const fs::path& wallpaper_dir) {
    wallpaper_dir_ = wallpaper_dir;
    extra_dirs_.clear();
    pkg_entries_.clear();
    pkg_lower_map_.clear();
    pkg_path_.clear();

    // Look for scene.pkg (or any *.pkg)
    fs::path scene_pkg = wallpaper_dir / "scene.pkg";
    if (fs::exists(scene_pkg)) {
        load_pkg(scene_pkg);
    } else {
        for (const auto& entry : fs::directory_iterator(wallpaper_dir)) {
            if (entry.is_regular_file() && entry.path().extension() == ".pkg") {
                load_pkg(entry.path());
                break;
            }
        }
    }
    return true;
}

bool Vfs::load_pkg(const fs::path& pkg_path) {
    std::ifstream f(pkg_path, std::ios::binary);
    if (!f) return false;

    auto read_u32 = [&](uint32_t& v) -> bool {
        f.read(reinterpret_cast<char*>(&v), 4);
        return static_cast<bool>(f);
    };

    uint32_t ver_len = 0;
    if (!read_u32(ver_len) || ver_len > 64) return false;
    std::string ver(ver_len, '\0');
    f.read(ver.data(), ver_len);
    if (!f || ver.rfind("PKGV", 0) != 0) return false;

    uint32_t count = 0;
    if (!read_u32(count) || count > 100000) return false;

    struct RawEntry {
        std::string name;
        uint32_t offset;
        uint32_t size;
    };
    std::vector<RawEntry> raw;
    raw.reserve(count);

    for (uint32_t i = 0; i < count; ++i) {
        uint32_t nlen = 0;
        if (!read_u32(nlen) || nlen > 4096) return false;
        std::string name(nlen, '\0');
        f.read(name.data(), nlen);
        uint32_t off = 0, sz = 0;
        if (!read_u32(off) || !read_u32(sz)) return false;
        raw.push_back({normalize(name), off, sz});
    }

    uint64_t data_start = static_cast<uint64_t>(f.tellg());
    pkg_path_ = pkg_path;
    for (const auto& e : raw) {
        pkg_entries_[e.name] = PkgEntry{data_start + e.offset, e.size};
        pkg_lower_map_[to_lower(e.name)] = e.name;
    }
    return true;
}

std::optional<fs::path> Vfs::find_on_disk(const fs::path& root, const std::string& norm_rel) const {
    if (root.empty()) return std::nullopt;
    fs::path direct = root / norm_rel;
    std::error_code ec;
    if (fs::is_regular_file(direct, ec)) return direct;

    // Case-insensitive walk for Windows-authored paths
    fs::path cur = root;
    size_t start = 0;
    while (start < norm_rel.size()) {
        size_t slash = norm_rel.find('/', start);
        std::string part = (slash == std::string::npos) ? norm_rel.substr(start) : norm_rel.substr(start, slash - start);
        fs::path next = cur / part;
        if (fs::exists(next, ec)) {
            cur = next;
        } else {
            std::string low = to_lower(part);
            bool found = false;
            if (fs::is_directory(cur, ec)) {
                for (const auto& de : fs::directory_iterator(cur, ec)) {
                    if (to_lower(de.path().filename().string()) == low) {
                        cur = de.path();
                        found = true;
                        break;
                    }
                }
            }
            if (!found) return std::nullopt;
        }
        if (slash == std::string::npos) break;
        start = slash + 1;
    }
    if (fs::is_regular_file(cur, ec)) return cur;
    return std::nullopt;
}

std::optional<FileSlice> Vfs::locate(const std::string& virtual_path) const {
    std::string norm = normalize(virtual_path);
    if (norm.empty()) return std::nullopt;

    // 1. Loose file in wallpaper directory
    if (auto p = find_on_disk(wallpaper_dir_, norm)) {
        std::error_code ec;
        auto sz = fs::file_size(*p, ec);
        if (!ec) return FileSlice{*p, 0, sz};
    }

    // 2. Entry in scene.pkg
    if (auto it = pkg_entries_.find(norm); it != pkg_entries_.end()) {
        return FileSlice{pkg_path_, it->second.offset, it->second.size};
    }
    if (auto itl = pkg_lower_map_.find(to_lower(norm)); itl != pkg_lower_map_.end()) {
        auto it = pkg_entries_.find(itl->second);
        if (it != pkg_entries_.end()) {
            return FileSlice{pkg_path_, it->second.offset, it->second.size};
        }
    }

    // 3. Wallpaper Engine built-in assets directory
    if (auto p = find_on_disk(assets_dir_, norm)) {
        std::error_code ec;
        auto sz = fs::file_size(*p, ec);
        if (!ec) return FileSlice{*p, 0, sz};
    }

    // 4. Registered effect subdirectories (e.g. assets/effects/scroll/)
    for (const auto& ed : extra_dirs_) {
        if (auto p = find_on_disk(ed, norm)) {
            std::error_code ec;
            auto sz = fs::file_size(*p, ec);
            if (!ec) return FileSlice{*p, 0, sz};
        }
    }

    // Also try zcompat/ inside assets if not found directly
    if (!assets_dir_.empty()) {
        if (auto p = find_on_disk(assets_dir_ / "zcompat", norm)) {
            std::error_code ec;
            auto sz = fs::file_size(*p, ec);
            if (!ec) return FileSlice{*p, 0, sz};
        }
    }

    return std::nullopt;
}

bool Vfs::exists(const std::string& virtual_path) const {
    return locate(virtual_path).has_value();
}

std::optional<std::vector<uint8_t>> Vfs::read_bytes(const std::string& virtual_path) const {
    auto slice = locate(virtual_path);
    if (!slice) return std::nullopt;
    std::ifstream f(slice->disk_path, std::ios::binary);
    if (!f) return std::nullopt;
    f.seekg(static_cast<std::streamoff>(slice->offset));
    std::vector<uint8_t> buf(slice->size);
    if (slice->size > 0) {
        f.read(reinterpret_cast<char*>(buf.data()), static_cast<std::streamsize>(slice->size));
        if (!f) return std::nullopt;
    }
    return buf;
}

std::optional<std::string> Vfs::read_text(const std::string& virtual_path) const {
    auto bytes = read_bytes(virtual_path);
    if (!bytes) return std::nullopt;
    return std::string(reinterpret_cast<const char*>(bytes->data()), bytes->size());
}

} // namespace sw
