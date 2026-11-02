// Passes what each tab plays to the shell through the native helper, and the
// shell's commands back to the tab. Keeps the last message of every tab so a
// shell that just started gets them all again ("resend").
"use strict";

const HOST = "someshell_browser";
const tabs = new Map(); // tab id → last media message
let port = null;
let browserName = "browser";

browser.runtime.getBrowserInfo?.().then(info => { browserName = info.name; }).catch(() => {});

function connect() {
    if (port)
        return port;
    port = browser.runtime.connectNative(HOST);
    port.onMessage.addListener(fromShell);
    port.onDisconnect.addListener(() => {
        // The helper is missing or quit; the next message starts it again
        port = null;
    });
    return port;
}

function send(msg) {
    try {
        connect().postMessage(msg);
    } catch (e) {
        port = null;
    }
}

function fromShell(msg) {
    if (msg.type === "resend") {
        send({ type: "reset", browser: browserName });
        for (const m of tabs.values())
            send(m);
        return;
    }
    // Commands for one tab: like, play, pause
    const tab = Number(msg.tab);
    if (tabs.has(tab))
        browser.tabs.sendMessage(tab, msg).catch(() => {});
}

function forget(tab) {
    if (tabs.delete(tab))
        send({ type: "gone", browser: browserName, tab });
}

browser.runtime.onMessage.addListener((msg, sender) => {
    const tab = sender.tab?.id;
    if (tab === undefined || sender.frameId !== 0)
        return;
    if (msg.type === "gone") {
        forget(tab);
        return;
    }
    const m = Object.assign({}, msg, { type: "media", browser: browserName, tab, incognito: sender.tab.incognito });
    tabs.set(tab, m);
    send(m);
});

browser.tabs.onRemoved.addListener(forget);

// Start the helper at once, so the shell knows the browser is there
connect();
