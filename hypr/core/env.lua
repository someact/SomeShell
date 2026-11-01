-- Environment for Hyprland and everything it starts.

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
-- Qt apps take the KDE platform theme (matugen writes its color scheme);
-- the menu prefix lets Dolphin find "Open with" entries.
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("XDG_MENU_PREFIX", "plasma-")

-- Flatpak apps show up in launchers
hl.env("XDG_DATA_DIRS", HOME .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:"
    .. (os.getenv("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"))

-- GPU vendors from sysfs (0x10de NVIDIA, 0x8086 Intel, 0x1002 AMD), read on
-- every load so the same config fits any machine.
GPU_VENDORS = {}
for i = 0, 9 do
    local f = io.open("/sys/class/drm/card" .. i .. "/device/vendor", "r")
    if f then
        GPU_VENDORS[f:read("l") or ""] = true
        f:close()
    end
end
ONLY_NVIDIA = GPU_VENDORS["0x10de"] and not GPU_VENDORS["0x8086"] and not GPU_VENDORS["0x1002"]

-- NVIDIA as the only GPU: video decode through nvidia-vaapi-driver. A hybrid
-- laptop renders on the integrated GPU, where these would break GL and video,
-- so they stay unset there. GBM_BACKEND is left out: it crashes Zen on some drivers.
if ONLY_NVIDIA then
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
end
