#!/usr/bin/env bash
# Start the shell (qs -c someshell). Autostart, the restart bind and install.sh
# all go through here, so the environment is decided in one place.
#
# NVIDIA as the only GPU: glvnd would also load Mesa and LLVM (~100 MB for
# nothing), so EGL is pinned to the NVIDIA vendor file. With any other GPU
# (AMD, Intel, a hybrid laptop) that pin would leave the shell without EGL.
# The settings app is started by the shell and inherits this.
vendors="$(cat /sys/class/drm/card*/device/vendor 2>/dev/null | sort -u)"
egl=/usr/share/glvnd/egl_vendor.d/10_nvidia.json
if [[ "$vendors" == "0x10de" && -f "$egl" ]]; then
    export __EGL_VENDOR_LIBRARY_FILENAMES="$egl"
fi
exec qs -c someshell "$@"
