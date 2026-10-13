# someshell-quickshare

The Quick Share (Nearby Share) helper behind `shell/services/QuickShare.qml`.
It has no window: the shell starts it, reads one JSON object per line from its
stdout and writes commands to its stdin. Closing stdin stops it.

It is a thin front end over [`rqs_lib`](https://github.com/Martichou/rquickshare)
(the library of rquickshare), which is GPL-3.0. This helper is therefore
GPL-3.0-or-later too, whatever the rest of the repository is licensed under.
It is a separate program; the shell only talks to it over a pipe.

Build it with `scripts/quickshare.sh` (needs `cargo` and `protoc`). The binary
goes to `~/.local/share/someshell/bin/someshell-quickshare`.

## Events (stdout)

```
{"event":"ready","download":"/home/me/Downloads"}
{"event":"device","id":"…","name":"Pixel 8","addr":"192.168.1.20:44123","kind":"phone","present":true}
{"event":"nearby"}                         a device near you is sharing (Bluetooth)
{"event":"transfer","id":"…","direction":"in","state":"waiting","device":"Pixel 8",
 "kind":"phone","pin":"1234","files":["a.jpg"],"text":null,"text_kind":null,
 "destination":null,"total":1024,"done":0}
{"event":"error","message":"…"}
```

`state` is one of `connecting`, `waiting` (asks for accept or reject),
`receiving`, `sending`, `finished`, `rejected`, `cancelled`, `disconnected`.

## Commands (stdin)

```
{"cmd":"accept","id":"…"}   {"cmd":"reject","id":"…"}   {"cmd":"cancel","id":"…"}
{"cmd":"visibility","value":"visible"}      visible | invisible | temporarily
{"cmd":"discover","on":true,"ble":false}    look for devices to send to; `ble` also
                                            advertises over Bluetooth, which switches the
                                            adapter on, so pass true only if it is on already
{"cmd":"send","id":"…","name":"Pixel 8","addr":"192.168.1.20:44123","files":["/path/a.jpg"]}
{"cmd":"download","path":"/home/me/Downloads"}
```

Nothing is accepted on its own: an incoming transfer waits in `waiting` until
`accept` arrives, and the library drops it after its own timeout.
