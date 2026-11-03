//! Google's Quick Share protocol on the local network, through rqs_lib
//! (rquickshare's core). This machine is visible under its host name while
//! the helper runs; phones on the same network send here from their share
//! sheet, and the Share page lists phones found nearby to send to.
//!
//! Events use the same names as the Bluetooth ones, with "via":"quick".

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::atomic::Ordering;
use std::sync::Arc;

use rqs_lib::channel::{ChannelAction, ChannelDirection, ChannelMessage, TransferType};
use rqs_lib::{EndpointInfo, OutboundPayload, SendInfo, State, Visibility, RQS};
use serde_json::json;
use tokio::sync::{broadcast, mpsc, Mutex};

use crate::{emit, Shared};

pub struct Quick {
    rqs: Mutex<RQS>,
    send: mpsc::Sender<SendInfo>,
    messages: broadcast::Sender<ChannelMessage>,
    // Our offer numbers → rqs transfer ids
    ids: Mutex<HashMap<u32, String>>,
    // The outbound transfer running now (to cancel it)
    current: Mutex<Option<String>>,
    scanning: Mutex<bool>,
}

fn names(m: &rqs_lib::channel::ChannelMessage) -> (String, String, u64, u64) {
    let meta = m.meta.clone().unwrap_or_default();
    let files = meta.files.clone().unwrap_or_default();
    let name = match files.len() {
        0 => meta.text_description.clone().unwrap_or_default(),
        1 => files[0].clone(),
        n => format!("{} + {} more", files[0], n - 1),
    };
    let peer = meta.source.as_ref().map(|s| s.name.clone()).unwrap_or_default();
    (name, peer, meta.total_bytes, meta.ack_bytes)
}

impl Quick {
    pub async fn start(folder: PathBuf) -> Result<Arc<Quick>, String> {
        let mut rqs = RQS::new(Visibility::Visible, None, Some(folder));
        let (send, _) = rqs.run().await.map_err(|e| e.to_string())?;
        let messages = rqs.message_sender.clone();
        Ok(Arc::new(Quick {
            rqs: Mutex::new(rqs),
            send,
            messages,
            ids: Mutex::new(HashMap::new()),
            current: Mutex::new(None),
            scanning: Mutex::new(false),
        }))
    }

    /// Follows every transfer and turns rqs's messages into events
    pub async fn listen(self: Arc<Self>, shared: Arc<Shared>) {
        let mut rx = self.messages.subscribe();
        // One event per state, not one per message (progress comes often)
        let mut seen: HashMap<String, String> = HashMap::new();
        loop {
            let m = match rx.recv().await {
                Ok(m) => m,
                Err(broadcast::error::RecvError::Lagged(_)) => continue,
                Err(_) => break,
            };
            if m.direction != ChannelDirection::LibToFront {
                continue;
            }
            let Some(state) = m.state.clone() else { continue };
            let inbound = m.rtype != Some(TransferType::Outbound);
            let dir = if inbound { "receive" } else { "send" };
            let (name, peer, size, done) = names(&m);
            let key = format!("{state:?}");
            let repeat = seen.get(&m.id) == Some(&key);
            seen.insert(m.id.clone(), key);
            match state {
                State::WaitingForUserConsent if inbound && !repeat => {
                    let meta = m.meta.clone().unwrap_or_default();
                    let id = shared.next.fetch_add(1, Ordering::SeqCst);
                    self.ids.lock().await.insert(id, m.id.clone());
                    let count = meta.files.as_ref().map(|f| f.len()).unwrap_or(0);
                    emit(json!({
                        "ev": "offer", "via": "quick", "id": id, "name": name, "size": size,
                        "count": count, "peer": peer, "pin": meta.pin_code.unwrap_or_default(),
                        "text": meta.text_description.unwrap_or_default(),
                    }));
                }
                // Waiting for the phone to accept: its PIN shows on both
                State::SentIntroduction if !inbound && !repeat => {
                    let pin = m.meta.as_ref().and_then(|x| x.pin_code.clone()).unwrap_or_default();
                    emit(json!({"ev": "waiting", "via": "quick", "dir": "send", "name": name, "pin": pin}));
                }
                State::ReceivingFiles | State::SendingFiles => {
                    emit(json!({"ev": "progress", "via": "quick", "dir": dir, "name": name, "size": size, "done": done, "index": 0, "count": 1, "peer": peer}));
                }
                State::Finished if !repeat => {
                    seen.remove(&m.id);
                    *self.current.lock().await = None;
                    let meta = m.meta.clone().unwrap_or_default();
                    if inbound {
                        if let Some(text) = meta.text_payload.clone() {
                            // (the type is not exported by rqs_lib: read its name)
                            let kind = match meta.text_type.as_ref().map(|t| format!("{t:?}")).as_deref() {
                                Some("Url") => "url",
                                Some("Wifi") => "wifi",
                                _ => "text",
                            };
                            emit(json!({"ev": "text", "via": "quick", "kind": kind, "text": text, "peer": peer}));
                        } else {
                            let files = meta.files.clone().unwrap_or_default();
                            let folder = meta.destination.clone().unwrap_or_default();
                            let path = files.first().map(|f| format!("{folder}/{f}")).unwrap_or(folder.clone());
                            emit(json!({"ev": "done", "via": "quick", "dir": "receive", "name": name, "path": path, "folder": folder, "count": files.len(), "peer": peer}));
                        }
                    } else {
                        let count = meta.files.as_ref().map(|f| f.len()).unwrap_or(1);
                        emit(json!({"ev": "finished", "via": "quick", "dir": "send", "sent": count, "count": count, "peer": peer}));
                    }
                }
                State::Rejected if !repeat => {
                    seen.remove(&m.id);
                    *self.current.lock().await = None;
                    if inbound {
                        emit(json!({"ev": "declined", "via": "quick", "name": name}));
                    } else {
                        emit(json!({"ev": "error", "via": "quick", "dir": "send", "message": "The phone declined it", "peer": peer}));
                    }
                }
                State::Cancelled if !repeat => {
                    seen.remove(&m.id);
                    *self.current.lock().await = None;
                    emit(json!({"ev": "cancelled", "via": "quick", "dir": dir, "sent": 0, "count": 1, "peer": peer}));
                }
                State::Disconnected if !repeat => {
                    seen.remove(&m.id);
                    *self.current.lock().await = None;
                    // A dropped request before anything was asked is noise
                    if done > 0 || !inbound {
                        emit(json!({"ev": "error", "via": "quick", "dir": dir, "message": "The connection was lost", "peer": peer}));
                    }
                    // An offer that went away unanswered
                    let gone: Vec<u32> = self.ids.lock().await.iter().filter(|(_, v)| **v == m.id).map(|(k, _)| *k).collect();
                    for id in gone {
                        self.ids.lock().await.remove(&id);
                        emit(json!({"ev": "declined", "id": id}));
                    }
                }
                _ => {}
            }
        }
    }

    /// Receiving: visible on the network (on) or not (off). Looking for
    /// phones to send to goes on either way.
    pub async fn set_receive(&self, on: bool) {
        self.rqs.lock().await.change_visibility(if on { Visibility::Visible } else { Visibility::Invisible });
    }

    /// Answers an offer; false when the number is not one of ours
    pub async fn answer(&self, id: u32, yes: bool) -> bool {
        let Some(rid) = self.ids.lock().await.remove(&id) else { return false };
        let _ = self.messages.send(ChannelMessage {
            id: rid,
            direction: ChannelDirection::FrontToLib,
            action: Some(if yes { ChannelAction::AcceptTransfer } else { ChannelAction::RejectTransfer }),
            ..Default::default()
        });
        true
    }

    /// Looks for phones on the network while the Share page is open
    pub async fn scan(self: &Arc<Self>, on: bool) {
        let mut scanning = self.scanning.lock().await;
        if *scanning == on {
            return;
        }
        *scanning = on;
        let mut rqs = self.rqs.lock().await;
        if !on {
            rqs.stop_discovery();
            return;
        }
        let (tx, mut rx) = broadcast::channel::<EndpointInfo>(20);
        if let Err(e) = rqs.discovery(tx) {
            emit(json!({"ev": "error", "dir": "start", "message": format!("Quick Share discovery: {e}")}));
            return;
        }
        tokio::spawn(async move {
            while let Ok(e) = rx.recv().await {
                emit(json!({
                    "ev": "nearby", "id": e.id, "name": e.name.unwrap_or_default(),
                    "addr": format!("{}:{}", e.ip.unwrap_or_default(), e.port.unwrap_or_default()),
                    "type": format!("{:?}", e.rtype.unwrap_or(rqs_lib::DeviceType::Unknown)),
                    "present": e.present.unwrap_or(true),
                }));
            }
        });
    }

    pub async fn send(&self, id: String, name: String, addr: String, files: Vec<String>) {
        *self.current.lock().await = Some(id.clone());
        let count = files.len();
        emit(json!({"ev": "progress", "via": "quick", "dir": "send", "name": files.first().and_then(|f| f.rsplit('/').next()).unwrap_or(""), "size": 0, "done": 0, "index": 0, "count": count, "peer": name}));
        if let Err(e) = self.send.send(SendInfo { id, name: name.clone(), addr, ob: OutboundPayload::Files(files) }).await {
            emit(json!({"ev": "error", "via": "quick", "dir": "send", "message": e.to_string(), "peer": name}));
        }
    }

    /// Stops the transfer running now; false when there is none
    pub async fn cancel(&self) -> bool {
        let Some(id) = self.current.lock().await.take() else { return false };
        let _ = self.messages.send(ChannelMessage {
            id,
            direction: ChannelDirection::FrontToLib,
            action: Some(ChannelAction::CancelTransfer),
            ..Default::default()
        });
        true
    }
}
