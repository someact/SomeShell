// someshell-quickshare: headless Quick Share for SomeShell.
// Events go out as JSON lines on stdout, commands come in as JSON lines on
// stdin (see README.md). End of stdin, SIGINT or SIGTERM stops the service.

use std::collections::HashMap;
use std::path::PathBuf;

use rqs_lib::channel::{ChannelAction, ChannelDirection, ChannelMessage, TransferType};
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use mdns_sd::{ServiceDaemon, ServiceEvent};
use rqs_lib::{DeviceType, EndpointInfo, OutboundPayload, SendInfo, State, Visibility, RQS};
use serde::Deserialize;
use serde_json::{json, Value};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::signal::unix::{signal, SignalKind};
use tokio::sync::broadcast;
use tokio_util::sync::CancellationToken;

#[derive(Deserialize)]
#[serde(tag = "cmd", rename_all = "lowercase")]
enum Command {
    Accept { id: String },
    Reject { id: String },
    Cancel { id: String },
    Visibility { value: String },
    Discover {
        on: bool,
        #[serde(default)]
        ble: bool,
    },
    Send { id: String, name: String, addr: String, files: Vec<String> },
    Download { path: String },
}

fn emit(value: Value) {
    // One line per event; println! locks stdout, so lines never interleave
    println!("{value}");
}

fn error(message: impl std::fmt::Display) {
    emit(json!({ "event": "error", "message": message.to_string() }));
}

fn kind(device: &Option<DeviceType>) -> &'static str {
    match device {
        Some(DeviceType::Phone) => "phone",
        Some(DeviceType::Tablet) => "tablet",
        Some(DeviceType::Laptop) => "laptop",
        _ => "unknown",
    }
}

fn visibility(name: &str) -> Option<Visibility> {
    match name {
        "visible" => Some(Visibility::Visible),
        "invisible" => Some(Visibility::Invisible),
        "temporarily" => Some(Visibility::Temporarily),
        _ => None,
    }
}

// The handshake steps are of no use to a front end: they all read "connecting"
fn state(state: &State) -> &'static str {
    match state {
        State::WaitingForUserConsent => "waiting",
        State::ReceivingFiles => "receiving",
        State::SendingFiles => "sending",
        State::Finished => "finished",
        State::Rejected => "rejected",
        State::Cancelled => "cancelled",
        State::Disconnected => "disconnected",
        _ => "connecting",
    }
}

fn transfer(message: &ChannelMessage) -> Value {
    let meta = message.meta.as_ref();
    let source = meta.and_then(|m| m.source.as_ref());
    json!({
        "event": "transfer",
        "id": message.id,
        "direction": match message.rtype { Some(TransferType::Outbound) => "out", _ => "in" },
        "state": message.state.as_ref().map(state).unwrap_or("connecting"),
        "device": source.map(|s| s.name.clone()),
        "kind": kind(&source.map(|s| s.device_type.clone())),
        "pin": meta.and_then(|m| m.pin_code.clone()),
        "files": meta.and_then(|m| m.files.clone()),
        "text": meta.and_then(|m| m.text_payload.clone()),
        "text_kind": meta.and_then(|m| m.text_type.as_ref()).map(|t| format!("{t:?}").to_lowercase()),
        "destination": meta.and_then(|m| m.destination.clone()),
        "total": meta.map(|m| m.total_bytes).unwrap_or(0),
        "done": meta.map(|m| m.ack_bytes).unwrap_or(0),
    })
}

fn device(info: &EndpointInfo) -> Value {
    let addr = match (&info.ip, &info.port) {
        (Some(ip), Some(port)) => Some(format!("{ip}:{port}")),
        _ => None,
    };
    json!({
        "event": "device",
        "id": info.id,
        "name": info.name,
        "addr": addr,
        "kind": kind(&info.rtype),
        "present": info.present.unwrap_or(false),
    })
}

// Devices that can receive, from mDNS alone. The library has the same search,
// but only together with a Bluetooth advertiser that switches the adapter on;
// this one leaves Bluetooth as it is. Same service name and record layout
// (rqs_lib hdl/mdns_discovery.rs, utils.rs).
async fn search_network(stop: CancellationToken) -> Result<(), anyhow::Error> {
    let daemon = ServiceDaemon::new()?;
    let found = daemon.browse("_FC9F5ED42C8A._tcp.local.")?;
    let own: Vec<std::net::IpAddr> = get_if_addrs::get_if_addrs()
        .map(|list| list.into_iter().map(|i| i.ip()).collect())
        .unwrap_or_default();
    let mut seen: HashMap<String, String> = HashMap::new();     // mDNS name -> device id

    loop {
        tokio::select! {
            _ = stop.cancelled() => break,
            event = found.recv_async() => match event {
                Ok(ServiceEvent::ServiceResolved(info)) => {
                    let Some(ip) = info.get_addresses_v4().into_iter().next() else { continue };
                    if own.contains(&std::net::IpAddr::V4(*ip)) {
                        continue;
                    }
                    // "n": base64 of 1 byte flags (device type in bits 1-3), 16 bytes, name length, name
                    let Some(record) = info.get_property("n") else { continue };
                    let Ok(bytes) = URL_SAFE_NO_PAD.decode(record.val_str()) else { continue };
                    if bytes.len() < 19 || 18 + bytes[17] as usize > bytes.len() {
                        continue;
                    }
                    let Ok(name) = String::from_utf8(bytes[18..18 + bytes[17] as usize].to_vec()) else { continue };
                    let kind = match (bytes[0] >> 1) & 0x7 { 1 => "phone", 2 => "tablet", 3 => "laptop", _ => "unknown" };
                    let addr = format!("{ip}:{}", info.get_port());
                    // Only what answers: a stale record is no use as a target
                    if tokio::net::TcpStream::connect(&addr).await.is_err() {
                        continue;
                    }
                    seen.insert(info.get_fullname().to_string(), addr.clone());
                    emit(json!({ "event": "device", "id": addr, "name": name, "addr": addr, "kind": kind, "present": true }));
                }
                Ok(ServiceEvent::ServiceRemoved(_, fullname)) => {
                    if let Some(id) = seen.remove(&fullname) {
                        emit(json!({ "event": "device", "id": id, "name": null, "addr": null, "kind": "unknown", "present": false }));
                    }
                }
                Ok(_) => {}
                Err(_) => break,
            },
        }
    }
    let _ = daemon.shutdown();
    Ok(())
}

fn action(sender: &broadcast::Sender<ChannelMessage>, id: String, action: ChannelAction) {
    let _ = sender.send(ChannelMessage {
        id,
        direction: ChannelDirection::FrontToLib,
        action: Some(action),
        ..Default::default()
    });
}

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    // --visibility <visible|invisible|temporarily>  --download <dir>
    let mut start = Visibility::Invisible;
    let mut download: Option<PathBuf> = None;
    let mut args = std::env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--visibility" => match args.next().as_deref().and_then(visibility) {
                Some(v) => start = v,
                None => anyhow::bail!("--visibility takes visible, invisible or temporarily"),
            },
            "--download" => download = args.next().map(PathBuf::from),
            other => anyhow::bail!("unknown argument: {other}"),
        }
    }

    let mut rqs = RQS::new(start, None, download.clone());
    let mut messages = rqs.message_sender.subscribe();
    let (send_file, mut nearby) = rqs.run().await?;
    let (device_sender, mut devices) = broadcast::channel::<EndpointInfo>(20);
    // What looks for devices right now: the library's discovery (network and
    // Bluetooth), or the network part alone under a token of our own
    let mut discovering = false;
    let mut network_only: Option<CancellationToken> = None;

    emit(json!({ "event": "ready", "download": download }));

    let mut lines = BufReader::new(tokio::io::stdin()).lines();
    let mut term = signal(SignalKind::terminate())?;
    let mut int = signal(SignalKind::interrupt())?;

    loop {
        tokio::select! {
            _ = term.recv() => break,
            _ = int.recv() => break,
            line = lines.next_line() => {
                let line = match line {
                    Ok(Some(line)) => line,
                    _ => break,     // stdin closed: the shell is gone
                };
                if line.trim().is_empty() {
                    continue;
                }
                match serde_json::from_str::<Command>(&line) {
                    Ok(Command::Accept { id }) => action(&rqs.message_sender, id, ChannelAction::AcceptTransfer),
                    Ok(Command::Reject { id }) => action(&rqs.message_sender, id, ChannelAction::RejectTransfer),
                    Ok(Command::Cancel { id }) => action(&rqs.message_sender, id, ChannelAction::CancelTransfer),
                    Ok(Command::Visibility { value }) => match visibility(&value) {
                        Some(v) => rqs.change_visibility(v),
                        None => error(format!("unknown visibility: {value}")),
                    },
                    // The library's discovery also advertises over Bluetooth and
                    // switches the adapter on for that. It is only used when the
                    // front end says Bluetooth is on already (`ble`); otherwise the
                    // network search runs alone and Bluetooth stays as it is.
                    Ok(Command::Discover { on, ble }) => {
                        if discovering {
                            rqs.stop_discovery();
                            if let Some(token) = network_only.take() {
                                token.cancel();
                            }
                            discovering = false;
                        }
                        if on && ble {
                            match rqs.discovery(device_sender.clone()) {
                                Ok(()) => discovering = true,
                                Err(e) => error(format!("discovery: {e}")),
                            }
                        } else if on {
                            let token = CancellationToken::new();
                            network_only = Some(token.clone());
                            tokio::spawn(async move {
                                if let Err(e) = search_network(token).await {
                                    error(format!("discovery: {e}"));
                                }
                            });
                            discovering = true;
                        }
                    }
                    Ok(Command::Send { id, name, addr, files }) => {
                        let info = SendInfo { id, name, addr, ob: OutboundPayload::Files(files) };
                        if let Err(e) = send_file.send(info).await {
                            error(format!("send: {e}"));
                        }
                    }
                    Ok(Command::Download { path }) => {
                        rqs.set_download_path(if path.is_empty() { None } else { Some(PathBuf::from(path)) });
                    }
                    Err(e) => error(format!("bad command: {e}")),
                }
            }
            message = messages.recv() => {
                match message {
                    Ok(message) if message.direction == ChannelDirection::LibToFront => emit(transfer(&message)),
                    Ok(_) => {}
                    // Progress came faster than it was read: the next one has the totals
                    Err(broadcast::error::RecvError::Lagged(_)) => {}
                    Err(broadcast::error::RecvError::Closed) => break,
                }
            }
            info = devices.recv() => {
                if let Ok(info) = info {
                    emit(device(&info));
                }
            }
            signal = nearby.recv() => {
                if signal.is_ok() {
                    emit(json!({ "event": "nearby" }));
                }
            }
        }
    }

    if let Some(token) = network_only.take() {
        token.cancel();
    }
    // The library's stop waits for all of its tasks, and the mDNS one can sit
    // there for good while visible. Go invisible, give it a moment, then leave:
    // the shell waits for this process to exit before it starts the next one.
    rqs.change_visibility(Visibility::Invisible);
    let _ = tokio::time::timeout(std::time::Duration::from_millis(1500), rqs.stop()).await;
    std::process::exit(0)
}
