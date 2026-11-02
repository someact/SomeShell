//! someshell-browser: the native messaging helper of the SomeShell extension.
//!
//! The browser starts it and talks over stdin/stdout (each message is a
//! 4-byte length in native byte order, then JSON). It passes every message to
//! the shell's socket as one line, and every line from the shell back to the
//! browser. When the shell is not running it waits for the socket to appear
//! (inotify on the runtime directory, no polling) and then asks the extension
//! to send everything again.

use std::env;
use std::ffi::CString;
use std::fs::File;
use std::io::{self, BufRead, BufReader, Read, Write};
use std::os::fd::FromRawFd;
use std::os::unix::net::UnixStream;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::thread;

const SOCKET_NAME: &str = "someshell-browser.sock";
// The browser refuses messages over 1 MB from a helper
const MAX_TO_BROWSER: usize = 1024 * 1024;

extern "C" {
    fn getuid() -> u32;
    fn inotify_init1(flags: i32) -> i32;
    fn inotify_add_watch(fd: i32, path: *const std::ffi::c_char, mask: u32) -> i32;
}
const IN_ATTRIB: u32 = 0x4;
const IN_MOVED_TO: u32 = 0x80;
const IN_CREATE: u32 = 0x100;
const IN_CLOEXEC: i32 = 0o2000000;

fn runtime_dir() -> PathBuf {
    match env::var_os("XDG_RUNTIME_DIR") {
        Some(dir) if !dir.is_empty() => PathBuf::from(dir),
        _ => PathBuf::from(format!("/run/user/{}", unsafe { getuid() })),
    }
}

type Shared<T> = Arc<Mutex<T>>;

fn to_browser(out: &Shared<io::Stdout>, json: &[u8]) {
    if json.is_empty() || json.len() > MAX_TO_BROWSER {
        return;
    }
    let mut out = out.lock().unwrap();
    let len = (json.len() as u32).to_ne_bytes();
    // A failed write means the browser is gone; stdin's end will stop us
    let _ = out.write_all(&len).and_then(|_| out.write_all(json)).and_then(|_| out.flush());
}

/// Blocks until the shell's socket accepts a connection.
fn connect(dir: &PathBuf, path: &PathBuf) -> UnixStream {
    // Watch first, then try, so a socket made in between is not missed
    let mut watch = CString::new(dir.as_os_str().as_encoded_bytes()).ok().and_then(|cdir| {
        let fd = unsafe { inotify_init1(IN_CLOEXEC) };
        if fd < 0 {
            return None;
        }
        let file = unsafe { File::from_raw_fd(fd) };
        let ok = unsafe { inotify_add_watch(fd, cdir.as_ptr(), IN_CREATE | IN_MOVED_TO | IN_ATTRIB) };
        (ok >= 0).then_some(file)
    });
    let mut events = [0u8; 4096];
    loop {
        if let Ok(stream) = UnixStream::connect(path) {
            return stream;
        }
        match watch.as_mut() {
            // Any change in the directory is a reason to try again
            Some(file) => {
                if file.read(&mut events).unwrap_or(0) == 0 {
                    thread::sleep(std::time::Duration::from_secs(2));
                }
            }
            // No inotify (should not happen on Linux): try again now and then
            None => thread::sleep(std::time::Duration::from_secs(2)),
        }
    }
}

/// Keeps one connection to the shell and passes its lines to the browser.
fn shell_link(shell: Shared<Option<UnixStream>>, out: Shared<io::Stdout>) {
    let dir = runtime_dir();
    let path = dir.join(SOCKET_NAME);
    loop {
        let stream = connect(&dir, &path);
        let reader = match stream.try_clone() {
            Ok(r) => r,
            Err(_) => continue,
        };
        *shell.lock().unwrap() = Some(stream);
        // The shell may have just started: have the extension send its tabs again
        to_browser(&out, br#"{"type":"resend"}"#);
        for line in BufReader::new(reader).split(b'\n') {
            match line {
                Ok(line) => to_browser(&out, line.trim_ascii()),
                Err(_) => break,
            }
        }
        *shell.lock().unwrap() = None;
    }
}

fn main() {
    let shell: Shared<Option<UnixStream>> = Arc::new(Mutex::new(None));
    let out = Arc::new(Mutex::new(io::stdout()));
    {
        let (shell, out) = (shell.clone(), out.clone());
        thread::spawn(move || shell_link(shell, out));
    }

    let mut input = io::stdin().lock();
    let mut len = [0u8; 4];
    // The browser closes stdin when the extension lets go of the helper
    while input.read_exact(&mut len).is_ok() {
        let mut msg = vec![0u8; u32::from_ne_bytes(len) as usize];
        if input.read_exact(&mut msg).is_err() {
            break;
        }
        // JSON from the browser is one line already; make sure of it
        msg.retain(|&b| b != b'\n' && b != b'\r');
        msg.push(b'\n');
        let mut guard = shell.lock().unwrap();
        if let Some(stream) = guard.as_mut() {
            if stream.write_all(&msg).is_err() {
                // The reader sees the end too and connects again
                *guard = None;
            }
        }
        // While the shell is down, messages are dropped: it asks for all of them when it is back
    }
}
