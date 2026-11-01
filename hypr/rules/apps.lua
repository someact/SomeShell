-- Drawing, 3D and video apps.

-- Clip Studio Paint (Wine). Its untitled clipstudio.exe windows are real modal
-- dialogs (sign-in, WebView2): never give them no_focus, or they can't be typed
-- into and the main window looks frozen.
hl.window_rule({ match = { class = "^(clipstudio\\.exe)$", title = "^()$" }, float = true, center = true })
-- Canvas stutters with compositor effects; both spellings of the class occur
hl.window_rule({ match = { class = "^(CLIPStudioPaint\\.exe|clipstudiopaint\\.exe)$" }, no_shadow = true, no_anim = true, opaque = true })

-- Art and 3D apps: always opaque, colors stay true
for _, class in ipairs({
    "^(blender|Blender)$",
    "^(blockbench|Blockbench)$",
    "^(krita|Krita)$",
    "^(aseprite|Aseprite)$",
    "^(gimp|Gimp|gimp-.*)$",
    "^(inkscape|org\\.inkscape\\.Inkscape)$",
}) do
    hl.window_rule({ match = { class = class }, opaque = true })
end

-- Video players, image viewers, OBS: always opaque
for _, class in ipairs({
    "^(mpv|vlc|org\\.videolan\\.vlc|io\\.github\\.celluloid_player\\.Celluloid)$",
    "^(imv|swappy|feh|loupe|eog|gwenview|org\\.kde\\.gwenview)$",
    "^(obs|com\\.obsproject\\.Studio|zoom)$",
}) do
    hl.window_rule({ match = { class = class }, opaque = true })
end
