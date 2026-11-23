#pragma once

#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

namespace sw {

// Reference to a byte slice in a file on disk (used to stream large video-in-TEX
// entries straight from scene.pkg without copying 200 MB into RAM!)
struct FileSlice {
    std::filesystem::path disk_path;
    uint64_t offset = 0;
    uint64_t size = 0;
};

class Vfs {
public:
    bool mount_wallpaper(const std::filesystem::path& wallpaper_dir);
    void set_assets_dir(const std::filesystem::path& assets_dir);
    void add_extra_dir(const std::filesystem::path& dir);

    bool exists(const std::string& virtual_path) const;
    std::optional<std::vector<uint8_t>> read_bytes(const std::string& virtual_path) const;
    std::optional<std::string> read_text(const std::string& virtual_path) const;
    std::optional<FileSlice> locate(const std::string& virtual_path) const;

    const std::filesystem::path& wallpaper_dir() const { return wallpaper_dir_; }
    const std::filesystem::path& assets_dir() const { return assets_dir_; }

private:
    struct PkgEntry {
        uint64_t offset = 0;
        uint64_t size = 0;
    };

    bool load_pkg(const std::filesystem::path& pkg_path);
    static std::string normalize(const std::string& p);
    std::optional<std::filesystem::path> find_on_disk(const std::filesystem::path& root, const std::string& norm_rel) const;

    std::filesystem::path wallpaper_dir_;
    std::filesystem::path assets_dir_;
    std::vector<std::filesystem::path> extra_dirs_;
    std::filesystem::path pkg_path_;
    std::unordered_map<std::string, PkgEntry> pkg_entries_;
    std::unordered_map<std::string, std::string> pkg_lower_map_;
};

} // namespace sw
