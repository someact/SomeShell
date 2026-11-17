#!/usr/bin/env python3
# Virtual multitouch screen through uinput, for scripted touch tests.
# Usage: vtouch.py "<cmd>; <cmd>; ..."
#   down X Y | move X Y | up | wait SEC | tap X Y | hold X Y SEC | swipe X1 Y1 X2 Y2 SEC
# X and Y are 0..1 fractions of the raw panel, before Hyprland's
# touchdevice transform. Tablet (DSI-1, transform 3, 1440x900 logical):
# logical (x, y) -> raw (1 - y/900, x/1440). Needs the input group (uinput).
import os, sys, struct, fcntl, time

W, H = 1800, 2880
EV_SYN, EV_KEY, EV_ABS = 0, 1, 3
BTN_TOUCH = 0x14a
ABS_X, ABS_Y = 0, 1
ABS_MT_SLOT, ABS_MT_POSITION_X, ABS_MT_POSITION_Y, ABS_MT_TRACKING_ID = 0x2f, 0x35, 0x36, 0x39
INPUT_PROP_DIRECT = 1
UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_ABSBIT, UI_SET_PROPBIT = 0x40045564, 0x40045565, 0x40045567, 0x4004556e
UI_DEV_SETUP, UI_ABS_SETUP, UI_DEV_CREATE, UI_DEV_DESTROY = 0x405c5503, 0x401c5504, 0x5501, 0x5502

fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
for ev in (EV_SYN, EV_KEY, EV_ABS):
    fcntl.ioctl(fd, UI_SET_EVBIT, ev)
fcntl.ioctl(fd, UI_SET_KEYBIT, BTN_TOUCH)
fcntl.ioctl(fd, UI_SET_PROPBIT, INPUT_PROP_DIRECT)
for code, mx in ((ABS_X, W - 1), (ABS_Y, H - 1), (ABS_MT_SLOT, 9), (ABS_MT_POSITION_X, W - 1),
                 (ABS_MT_POSITION_Y, H - 1), (ABS_MT_TRACKING_ID, 65535)):
    fcntl.ioctl(fd, UI_SET_ABSBIT, code)
    fcntl.ioctl(fd, UI_ABS_SETUP, struct.pack("HHiiiiii", code, 0, 0, 0, mx, 0, 0, 10))
fcntl.ioctl(fd, UI_DEV_SETUP, struct.pack("HHHH80sI", 3, 0x1234, 0x5678, 1, b"someshell-vtouch", 0))
fcntl.ioctl(fd, UI_DEV_CREATE)
time.sleep(1.0)  # let the compositor open it

def emit(t, c, v):
    os.write(fd, struct.pack("qqHHi", 0, 0, t, c, v))
def syn():
    emit(EV_SYN, 0, 0)
tid = [100]
def pos(x, y, key=False):
    X, Y = int(x * (W - 1)), int(y * (H - 1))
    emit(EV_ABS, ABS_MT_POSITION_X, X); emit(EV_ABS, ABS_MT_POSITION_Y, Y)
    if key: emit(EV_KEY, BTN_TOUCH, 1)
    emit(EV_ABS, ABS_X, X); emit(EV_ABS, ABS_Y, Y); syn()
def down(x, y):
    tid[0] += 1
    emit(EV_ABS, ABS_MT_SLOT, 0); emit(EV_ABS, ABS_MT_TRACKING_ID, tid[0])
    pos(x, y, key=True)
def up():
    emit(EV_ABS, ABS_MT_SLOT, 0); emit(EV_ABS, ABS_MT_TRACKING_ID, -1)
    emit(EV_KEY, BTN_TOUCH, 0); syn()

try:
    for cmd in sys.argv[1].split(";"):
        a = cmd.split()
        if not a: continue
        f = [float(v) for v in a[1:]]
        if a[0] == "down": down(f[0], f[1])
        elif a[0] == "move": pos(f[0], f[1])
        elif a[0] == "up": up()
        elif a[0] == "wait": time.sleep(f[0])
        elif a[0] == "tap": down(f[0], f[1]); time.sleep(0.08); up()
        elif a[0] == "hold": down(f[0], f[1]); time.sleep(f[2]); up()
        elif a[0] == "swipe":
            n = max(2, int(f[4] * 60))
            down(f[0], f[1])
            for i in range(1, n + 1):
                time.sleep(f[4] / n); pos(f[0] + (f[2] - f[0]) * i / n, f[1] + (f[3] - f[1]) * i / n)
            up()
        time.sleep(0.03)
    time.sleep(0.3)
finally:
    fcntl.ioctl(fd, UI_DEV_DESTROY)
    os.close(fd)
