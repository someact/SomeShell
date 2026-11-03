//! someshell-share: Quick Share for SomeShell, Bluetooth file push (OBEX
//! Object Push) through bluez's obexd.
//!
//! Started by the shell (services/Share.qml), it reads one JSON command per
//! line on stdin and prints one JSON event per line on stdout:
//!
//!   commands
//!     {"cmd":"devices"}                                  paired devices
//!     {"cmd":"send","device":"AA:BB:…","files":["/path",…]}
//!     {"cmd":"cancel"}                                   stops the transfer running now
//!     {"cmd":"accept","id":1} / {"cmd":"decline","id":1} answers an offer
//!   events
//!     {"ev":"ready","folder":"…"}                        the agent is registered
//!     {"ev":"devices","list":[{address,name,icon,connected,files}]}
//!     {"ev":"offer","id":1,"name":"…","size":123,"device":"…","peer":"…"}
//!     {"ev":"progress","dir":"send"|"receive","name":"…","size":…,"done":…,"index":0,"count":2,"peer":"…"}
//!     {"ev":"done","dir":"…","name":"…","path":"…","peer":"…"}  (path: where a received file is)
//!     {"ev":"finished","dir":"send","sent":2,"count":2,"peer":"…"}
//!     {"ev":"error","dir":"…","message":"…"}
//!     {"ev":"cancelled","dir":"…"}
//!
//! Received files go to the folder given as the first argument (the shell
//! passes ~/Downloads or `share.folder`).

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;
use std::time::Duration;

use futures_util::StreamExt;
use serde_json::{json, Value as Json};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::sync::{oneshot, Mutex};
use zbus::fdo::PropertiesProxy;
use zbus::names::InterfaceName;
use zbus::zvariant::{OwnedObjectPath, OwnedValue, Value};
use zbus::{interface, Connection, Proxy};

const OBEX: &str = "org.bluez.obex";
const TRANSFER: &str = "org.bluez.obex.Transfer1";
const AGENT_PATH: &str = "/org/someshell/share/agent";
// Object Push
const OPP_UUID: &str = "00001105-0000-1000-8000-00805f9b34fb";
// obexd waits about a minute for the agent; answer before it gives up
const OFFER_TIMEOUT: Duration = Duration::from_secs(55);

fn emit(v: Json) {
    println!("{v}");
}

fn text(v: Option<&OwnedValue>) -> String {
    match v.map(|v| &**v) {
        Some(Value::Str(s)) => s.as_str().to_string(),
        Some(Value::ObjectPath(p)) => p.as_str().to_string(),
        _ => String::new(),
    }
}

fn number(v: Option<&OwnedValue>) -> u64 {
    match v.map(|v| &**v) {
        Some(Value::U64(n)) => *n,
        Some(Value::U32(n)) => *n as u64,
        Some(Value::I64(n)) => *n as u64,
        _ => 0,
    }
}

fn flag(v: Option<&OwnedValue>) -> bool {
    matches!(v.map(|v| &**v), Some(Value::Bool(true)))
}

fn strings(v: Option<&OwnedValue>) -> Vec<String> {
    match v.map(|v| &**v) {
        Some(Value::Array(a)) => a
            .iter()
            .filter_map(|x| match x {
                Value::Str(s) => Some(s.as_str().to_string()),
                _ => None,
            })
            .collect(),
        _ => vec![],
    }
}

async fn props(conn: &Connection, dest: &str, path: &str, iface: &'static str) -> zbus::Result<HashMap<String, OwnedValue>> {
    let p = PropertiesProxy::builder(conn).destination(dest.to_string())?.path(path.to_string())?.build().await?;
    Ok(p.get_all(InterfaceName::from_static_str_unchecked(iface)).await?)
}

/// A device's name from bluez (system bus), by address
async fn peer_name(system: &Option<Connection>, address: &str) -> String {
    let Some(sys) = system else { return address.to_string() };
    let Ok(om) = zbus::fdo::ObjectManagerProxy::builder(sys).destination("org.bluez").and_then(|b| b.path("/")) else {
        return address.to_string();
    };
    let Ok(om) = om.build().await else { return address.to_string() };
    let Ok(objects) = om.get_managed_objects().await else { return address.to_string() };
    for (_, ifaces) in objects {
        if let Some(d) = ifaces.get("org.bluez.Device1") {
            if text(d.get("Address")).eq_ignore_ascii_case(address) {
                let alias = text(d.get("Alias"));
                return if alias.is_empty() { address.to_string() } else { alias };
            }
        }
    }
    address.to_string()
}

/// A free name in a folder: photo.jpg, photo-2.jpg, …
fn free_path(folder: &Path, name: &str) -> PathBuf {
    // Only the last part of what the sender calls it
    let name = Path::new(name).file_name().and_then(|n| n.to_str()).filter(|n| !n.is_empty() && *n != "..").unwrap_or("received");
    let first = folder.join(name);
    if !first.exists() {
        return first;
    }
    let (base, ext) = match name.rfind('.') {
        Some(i) if i > 0 => (&name[..i], &name[i..]),
        _ => (name, ""),
    };
    (2..).map(|n| folder.join(format!("{base}-{n}{ext}"))).find(|p| !p.exists()).unwrap()
}

/// Follows one transfer until it ends: progress events, then Ok(()) when
/// complete or Err(message). obexd removes the object at the end, so a
/// vanished transfer that had all its bytes counts as complete.
async fn follow(conn: &Connection, path: &str, mut on_progress: impl FnMut(u64)) -> Result<(), String> {
    let proxy = PropertiesProxy::builder(conn)
        .destination(OBEX)
        .and_then(|b| b.path(path.to_string()))
        .map_err(|e| e.to_string())?
        .build()
        .await
        .map_err(|e| e.to_string())?;
    let mut changes = proxy.receive_properties_changed().await.map_err(|e| e.to_string())?;
    let mut size = 0;
    let mut done = 0;
    // The state now (it may have moved on before the subscription)
    if let Ok(p) = props(conn, OBEX, path, TRANSFER).await {
        size = number(p.get("Size"));
        done = number(p.get("Transferred"));
        match text(p.get("Status")).as_str() {
            "complete" => return Ok(()),
            "error" => return Err("The transfer failed".into()),
            _ => {}
        }
    }
    loop {
        tokio::select! {
            change = changes.next() => {
                let Some(change) = change else { break };
                let Ok(args) = change.args() else { continue };
                if args.interface_name.as_str() != TRANSFER {
                    continue;
                }
                if let Some(Value::U64(n)) = args.changed_properties.get("Transferred") {
                    done = *n;
                    on_progress(done);
                }
                if let Some(Value::Str(s)) = args.changed_properties.get("Status") {
                    match s.as_str() {
                        "complete" => return Ok(()),
                        "error" => return Err(if size > 0 && done > 0 { "The transfer stopped".into() } else { "The device refused it".into() }),
                        _ => {}
                    }
                }
            }
            // Every few seconds: is it still there?
            _ = tokio::time::sleep(Duration::from_secs(3)) => {
                match props(conn, OBEX, path, TRANSFER).await {
                    Ok(p) => {
                        let status = text(p.get("Status"));
                        if status == "complete" { return Ok(()) }
                        if status == "error" { return Err("The transfer failed".into()) }
                    }
                    Err(_) => break,
                }
            }
        }
    }
    if size > 0 && done >= size { Ok(()) } else { Err("The transfer stopped".into()) }
}

#[derive(Debug, zbus::DBusError)]
#[zbus(prefix = "org.bluez.obex.Error")]
enum AgentError {
    #[zbus(error)]
    ZBus(zbus::Error),
    Rejected(String),
}

struct Shared {
    session: Connection,
    system: Option<Connection>,
    folder: PathBuf,
    offers: Mutex<HashMap<u32, oneshot::Sender<bool>>>,
    next: AtomicU32,
    // The transfer running now (to cancel it), and whether a send was stopped
    current: Mutex<Option<String>>,
    stop: std::sync::atomic::AtomicBool,
}

struct Agent {
    shared: Arc<Shared>,
}

#[interface(name = "org.bluez.obex.Agent1")]
impl Agent {
    async fn release(&self) {}

    async fn authorize_push(&self, transfer: OwnedObjectPath) -> Result<String, AgentError> {
        let sh = &self.shared;
        let t = props(&sh.session, OBEX, transfer.as_str(), TRANSFER).await?;
        let name = text(t.get("Name"));
        let size = number(t.get("Size"));
        let session = text(t.get("Session"));
        let device = match props(&sh.session, OBEX, &session, "org.bluez.obex.Session1").await {
            Ok(s) => text(s.get("Destination")),
            Err(_) => String::new(),
        };
        let peer = peer_name(&sh.system, &device).await;
        let id = sh.next.fetch_add(1, Ordering::SeqCst);
        let (tx, rx) = oneshot::channel();
        sh.offers.lock().await.insert(id, tx);
        emit(json!({"ev": "offer", "id": id, "name": name, "size": size, "device": device, "peer": peer}));
        let accepted = matches!(tokio::time::timeout(OFFER_TIMEOUT, rx).await, Ok(Ok(true)));
        sh.offers.lock().await.remove(&id);
        if !accepted {
            emit(json!({"ev": "declined", "id": id, "name": name}));
            return Err(AgentError::Rejected("Declined".into()));
        }
        let _ = std::fs::create_dir_all(&sh.folder);
        let path = free_path(&sh.folder, &name);
        let shown = path.file_name().and_then(|n| n.to_str()).unwrap_or(&name).to_string();
        // Follow it once obexd has the answer
        let shared = sh.clone();
        let tpath = transfer.as_str().to_string();
        let file = path.to_string_lossy().to_string();
        tokio::spawn(async move {
            *shared.current.lock().await = Some(tpath.clone());
            let n = shown.clone();
            let p = peer.clone();
            let result = follow(&shared.session, &tpath, |done| {
                emit(json!({"ev": "progress", "dir": "receive", "name": n, "size": size, "done": done, "index": 0, "count": 1, "peer": p}));
            })
            .await;
            *shared.current.lock().await = None;
            match result {
                Ok(()) => emit(json!({"ev": "done", "dir": "receive", "name": shown, "path": file, "peer": peer})),
                Err(m) => emit(json!({"ev": "error", "dir": "receive", "message": m, "name": shown})),
            }
        });
        Ok(path.to_string_lossy().to_string())
    }

    async fn cancel(&self) {
        // obexd gave up waiting: drop every open offer
        for (id, tx) in self.shared.offers.lock().await.drain() {
            let _ = tx.send(false);
            emit(json!({"ev": "declined", "id": id}));
        }
    }
}

async fn devices(sh: &Shared) -> Json {
    let mut list = vec![];
    if let Some(sys) = &sh.system {
        if let Ok(b) = zbus::fdo::ObjectManagerProxy::builder(sys).destination("org.bluez").and_then(|b| b.path("/")) {
            if let Ok(om) = b.build().await {
                if let Ok(objects) = om.get_managed_objects().await {
                    for (_, ifaces) in objects {
                        let Some(d) = ifaces.get("org.bluez.Device1") else { continue };
                        if !flag(d.get("Paired")) {
                            continue;
                        }
                        let uuids = strings(d.get("UUIDs"));
                        let icon = text(d.get("Icon"));
                        // Takes files: says so, or is a phone or computer
                        let files = uuids.iter().any(|u| u.eq_ignore_ascii_case(OPP_UUID)) || icon.starts_with("phone") || icon.starts_with("computer");
                        list.push(json!({
                            "address": text(d.get("Address")),
                            "name": text(d.get("Alias")),
                            "icon": icon,
                            "connected": flag(d.get("Connected")),
                            "files": files,
                        }));
                    }
                }
            }
        }
    }
    json!({"ev": "devices", "list": list})
}

async fn send(sh: Arc<Shared>, device: String, files: Vec<String>) {
    sh.stop.store(false, Ordering::SeqCst);
    let peer = peer_name(&sh.system, &device).await;
    let fail = |m: String| emit(json!({"ev": "error", "dir": "send", "message": m, "peer": peer}));
    let client = match Proxy::new(&sh.session, OBEX, "/org/bluez/obex", "org.bluez.obex.Client1").await {
        Ok(c) => c,
        Err(e) => return fail(format!("obexd is not running: {e}")),
    };
    let mut args: HashMap<&str, Value> = HashMap::new();
    args.insert("Target", Value::from("opp"));
    let session: OwnedObjectPath = match client.call("CreateSession", &(device.as_str(), args)).await {
        Ok(s) => s,
        Err(e) => return fail(format!("Could not reach {peer}: {}", short(&e))),
    };
    let push = match Proxy::new(&sh.session, OBEX, session.as_str().to_string(), "org.bluez.obex.ObjectPush1").await {
        Ok(p) => p,
        Err(e) => return fail(e.to_string()),
    };
    let count = files.len();
    let mut sent = 0;
    for (index, file) in files.iter().enumerate() {
        if sh.stop.load(Ordering::SeqCst) {
            break;
        }
        let name = Path::new(file).file_name().and_then(|n| n.to_str()).unwrap_or(file).to_string();
        let size = std::fs::metadata(file).map(|m| m.len()).unwrap_or(0);
        emit(json!({"ev": "progress", "dir": "send", "name": name, "size": size, "done": 0, "index": index, "count": count, "peer": peer}));
        let reply: zbus::Result<(OwnedObjectPath, HashMap<String, OwnedValue>)> = push.call("SendFile", &(file.as_str(),)).await;
        let transfer = match reply {
            Ok((t, _)) => t.as_str().to_string(),
            Err(e) => {
                fail(format!("{name}: {}", short(&e)));
                break;
            }
        };
        *sh.current.lock().await = Some(transfer.clone());
        let (n, p) = (name.clone(), peer.clone());
        let result = follow(&sh.session, &transfer, |done| {
            emit(json!({"ev": "progress", "dir": "send", "name": n, "size": size, "done": done, "index": index, "count": count, "peer": p}));
        })
        .await;
        *sh.current.lock().await = None;
        match result {
            Ok(()) => {
                sent += 1;
                emit(json!({"ev": "done", "dir": "send", "name": name, "peer": peer}));
            }
            Err(m) => {
                if !sh.stop.load(Ordering::SeqCst) {
                    fail(format!("{name}: {m}"));
                }
                break;
            }
        }
    }
    let _: zbus::Result<()> = client.call("RemoveSession", &(session,)).await;
    if sh.stop.load(Ordering::SeqCst) {
        emit(json!({"ev": "cancelled", "dir": "send", "sent": sent, "count": count, "peer": peer}));
    } else {
        emit(json!({"ev": "finished", "dir": "send", "sent": sent, "count": count, "peer": peer}));
    }
}

/// A D-Bus error without the error name in front
fn short(e: &zbus::Error) -> String {
    match e {
        zbus::Error::MethodError(_, Some(m), _) => m.clone(),
        other => other.to_string(),
    }
}

async fn cancel(sh: &Shared) {
    sh.stop.store(true, Ordering::SeqCst);
    let current = sh.current.lock().await.clone();
    if let Some(t) = current {
        if let Ok(p) = Proxy::new(&sh.session, OBEX, t, TRANSFER).await {
            let _: zbus::Result<()> = p.call("Cancel", &()).await;
        }
    }
}

#[tokio::main(flavor = "current_thread")]
async fn main() {
    let folder = std::env::args().nth(1).map(PathBuf::from).unwrap_or_else(|| {
        PathBuf::from(std::env::var("HOME").unwrap_or_else(|_| "/tmp".into())).join("Downloads")
    });
    let session = match Connection::session().await {
        Ok(c) => c,
        Err(e) => {
            emit(json!({"ev": "error", "dir": "start", "message": format!("No session bus: {e}")}));
            std::process::exit(1);
        }
    };
    let system = Connection::system().await.ok();
    let shared = Arc::new(Shared {
        session: session.clone(),
        system,
        folder: folder.clone(),
        offers: Mutex::new(HashMap::new()),
        next: AtomicU32::new(1),
        current: Mutex::new(None),
        stop: std::sync::atomic::AtomicBool::new(false),
    });

    // The agent that answers incoming pushes (this also starts obexd)
    let agent = Agent { shared: shared.clone() };
    if let Err(e) = session.object_server().at(AGENT_PATH, agent).await {
        emit(json!({"ev": "error", "dir": "start", "message": e.to_string()}));
    }
    let manager = Proxy::new(&session, OBEX, "/org/bluez/obex", "org.bluez.obex.AgentManager1").await;
    let path = zbus::zvariant::ObjectPath::try_from(AGENT_PATH).unwrap();
    match manager {
        Ok(m) => match m.call::<_, _, ()>("RegisterAgent", &(&path,)).await {
            Ok(()) => emit(json!({"ev": "ready", "folder": folder})),
            Err(e) => emit(json!({"ev": "error", "dir": "start", "message": format!("Receiving is off: {}", short(&e))})),
        },
        Err(e) => emit(json!({"ev": "error", "dir": "start", "message": format!("obexd is missing: {e}")})),
    }

    let mut lines = BufReader::new(tokio::io::stdin()).lines();
    while let Ok(Some(line)) = lines.next_line().await {
        let Ok(cmd) = serde_json::from_str::<Json>(&line) else { continue };
        match cmd["cmd"].as_str().unwrap_or("") {
            "devices" => emit(devices(&shared).await),
            "send" => {
                let device = cmd["device"].as_str().unwrap_or("").to_string();
                let files: Vec<String> = cmd["files"].as_array().map(|a| a.iter().filter_map(|f| f.as_str().map(String::from)).collect()).unwrap_or_default();
                if device.is_empty() || files.is_empty() {
                    continue;
                }
                tokio::spawn(send(shared.clone(), device, files));
            }
            "cancel" => cancel(&shared).await,
            what @ ("accept" | "decline") => {
                let id = cmd["id"].as_u64().unwrap_or(0) as u32;
                if let Some(tx) = shared.offers.lock().await.remove(&id) {
                    let _ = tx.send(what == "accept");
                }
            }
            _ => {}
        }
    }
    // stdin closed: the shell has gone
    if let Ok(m) = Proxy::new(&session, OBEX, "/org/bluez/obex", "org.bluez.obex.AgentManager1").await {
        let _: zbus::Result<()> = m.call("UnregisterAgent", &(&path,)).await;
    }
}
