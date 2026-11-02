// Reads what this page plays and tells the background script. Every site
// through navigator.mediaSession; YouTube Music and YouTube have their own
// readers for a full-size cover and the like state. Reads only on events
// (media element events, title changes, the like button changing).
"use strict";

(() => {
    const host = location.hostname.replace(/^www\./, "");
    const MUSIC_SITES = /(^|\.)(music\.youtube\.com|open\.spotify\.com|soundcloud\.com|bandcamp\.com|tidal\.com|deezer\.com|music\.apple\.com|music\.amazon\.[a-z.]+)$/;

    let last = "";
    let timers = [];

    // The page's own objects (Firefox hides some behind Xray wrappers)
    const pageNav = window.wrappedJSObject?.navigator ?? navigator;

    function mediaElement() {
        const all = [...document.querySelectorAll("video, audio")];
        return all.find(m => !m.paused) ?? all.find(m => m.currentSrc) ?? null;
    }

    function biggest(artwork) {
        let best = null, bestSize = -1;
        for (const a of artwork ?? []) {
            const size = Math.max(0, ...String(a.sizes ?? "").split(/\s+/).map(s => parseInt(s, 10) || 0));
            if (size >= bestSize) {
                best = a.src;
                bestSize = size;
            }
        }
        return best ? new URL(best, location.href).href : "";
    }

    // Site readers: each fills in what it knows better than mediaSession
    const readers = {
        "music.youtube.com"(info) {
            // Google image links carry their size: ask for a big one
            const img = document.querySelector("ytmusic-player-bar img.image, #song-image img");
            const src = info.cover || img?.src || "";
            if (/googleusercontent\.com|ggpht\.com/.test(src))
                info.cover = src.replace(/=w\d+-h\d+[^/]*$/, "=w1200-h1200-l90-rj").replace(/=s\d+[^/]*$/, "=s1200");
            const like = document.querySelector("ytmusic-player-bar ytmusic-like-button-renderer");
            const status = like?.getAttribute("like-status");
            info.liked = status ? status === "LIKE" : null;
            info.canLike = !!like;
        },
        "youtube.com"(info) {
            const id = new URL(location.href).searchParams.get("v") ?? /\/(?:shorts|live)\/([\w-]{11})/.exec(location.pathname)?.[1];
            if (id)
                info.cover = `https://i.ytimg.com/vi/${id}/maxresdefault.jpg`;
            info.kind = "video";
        },
    };

    // maxresdefault does not exist for every video: YouTube sends a 120 px placeholder
    const coverChecks = new Map();
    function checkCover(url) {
        if (!/\/maxresdefault\.jpg$/.test(url))
            return Promise.resolve(url);
        if (!coverChecks.has(url)) {
            coverChecks.set(url, new Promise(done => {
                const img = new Image();
                img.onload = () => done(img.naturalWidth > 200 ? url : url.replace("maxresdefault", "hqdefault"));
                img.onerror = () => done(url.replace("maxresdefault", "hqdefault"));
                img.src = url;
            }));
        }
        return coverChecks.get(url);
    }

    async function read() {
        const session = pageNav.mediaSession;
        const meta = session?.metadata;
        const el = mediaElement();
        if (!meta?.title && !el)
            return null;
        const info = {
            site: host,
            url: location.href,
            title: meta?.title || document.title,
            artist: meta?.artist ?? "",
            album: meta?.album ?? "",
            cover: biggest(meta?.artwork),
            kind: MUSIC_SITES.test(host) || el instanceof HTMLAudioElement ? "music" : "video",
            playing: el ? !el.paused : session?.playbackState === "playing",
            duration: el && isFinite(el.duration) ? el.duration : 0,
            liked: null,
            canLike: false,
        };
        readers[host]?.(info);
        info.cover = await checkCover(info.cover);
        return info;
    }

    async function update() {
        const info = await read();
        if (!info) {
            if (last) {
                last = "";
                browser.runtime.sendMessage({ type: "gone" }).catch(() => {});
            }
            return;
        }
        const json = JSON.stringify(info);
        if (json === last)
            return;
        last = json;
        browser.runtime.sendMessage(info).catch(() => {});
    }

    // Sites set mediaSession a moment after the media changes: read now and twice more
    function soon() {
        timers.forEach(clearTimeout);
        timers = [0, 600, 2000].map(ms => setTimeout(update, ms));
    }

    // Media events do not bubble, but they can be caught on the way down
    for (const ev of ["play", "playing", "pause", "ended", "emptied", "loadedmetadata", "durationchange"])
        document.addEventListener(ev, soon, true);

    // Title changes (single-page sites change track without loading a page)
    const titleWatch = new MutationObserver(soon);
    const watchTitle = () => {
        const t = document.querySelector("head > title");
        if (t)
            titleWatch.observe(t, { childList: true, characterData: true, subtree: true });
    };
    watchTitle();
    new MutationObserver(watchTitle).observe(document.head ?? document.documentElement, { childList: true });

    // YouTube Music: the like button changes without any media event
    if (host === "music.youtube.com") {
        const likeWatch = new MutationObserver(soon);
        const hook = () => {
            const like = document.querySelector("ytmusic-player-bar ytmusic-like-button-renderer");
            if (!like)
                return false;
            likeWatch.observe(like, { attributes: true, attributeFilter: ["like-status"] });
            return true;
        };
        if (!hook()) {
            const wait = new MutationObserver(() => { if (hook()) wait.disconnect(); });
            wait.observe(document.body, { childList: true, subtree: true });
        }
    }

    // Commands from the shell
    browser.runtime.onMessage.addListener(msg => {
        const el = mediaElement();
        if (msg.type === "like" && host === "music.youtube.com") {
            document.querySelector("ytmusic-player-bar ytmusic-like-button-renderer #button-shape-like button, ytmusic-player-bar ytmusic-like-button-renderer .like")?.click();
        } else if (msg.type === "play") {
            el?.play();
        } else if (msg.type === "pause") {
            el?.pause();
        }
    });

    window.addEventListener("pagehide", () => {
        if (last)
            browser.runtime.sendMessage({ type: "gone" }).catch(() => {});
    window.addEventListener("pageshow", e => { if (e.persisted) { last = ""; soon(); } });
    });

    soon();
})();
