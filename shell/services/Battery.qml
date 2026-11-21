pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.core

// The battery, through UPower's display device (all batteries as one).
// `available` is false on a desktop, so everything built on it hides there.
// Alerts on the island at 20% and 10% while discharging, once each until
// it charges again.
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool available: (device?.ready ?? false) && device.isLaptopBattery && device.isPresent

    // A test can stand in for the hardware: `qs ipc call battery simulate 15 false`
    property int testPercent: -1
    property bool testCharging: false
    readonly property bool testing: testPercent >= 0

    // UPower gives 0..1
    readonly property int percent: testing ? testPercent : Math.round((device?.percentage ?? 0) * 100)
    // The charge limit is holding it (plugged in, not charging; the driver
    // may still say charging)
    readonly property bool held: ChargeLimit.holding
    readonly property bool charging: !held && (testing ? testCharging
        : device?.state === UPowerDeviceState.Charging || device?.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: !testing && device?.state === UPowerDeviceState.FullyCharged
    readonly property bool low: !charging && !full && percent <= 20

    // Minutes left (to empty, or to full while charging); 0 when unknown
    readonly property int minutes: testing ? 0 : Math.round(((charging ? device?.timeToFull : device?.timeToEmpty) ?? 0) / 60)

    readonly property string icon: {
        if (held)
            return "power";
        if (charging || full) {
            const steps = [20, 30, 50, 60, 80, 90];
            const s = steps.find(v => percent <= v);
            return full || !s ? "battery_charging_full" : "battery_charging_" + s;
        }
        if (percent <= 5)
            return "battery_alert";
        if (percent >= 95)
            return "battery_full";
        return "battery_" + Math.min(6, Math.floor(percent / 100 * 7)) + "_bar";
    }

    // Each alert level fires once per discharge
    property int alerted: 100
    function check() {
        if (!available && !testing)
            return;
        if (charging || full || held) {
            alerted = 100;
            return;
        }
        if (percent <= 10 && alerted > 10) {
            alerted = 10;
            Ui.showAlert("Battery " + percent + "%", "Plug in soon, or the system will sleep.", "Battery", "battery_alert");
        } else if (percent <= 20 && alerted > 20) {
            alerted = 20;
            if (!Notifications.dnd)
                Ui.showAlert("Battery " + percent + "%", "Battery is getting low.", "Battery", "battery_2_bar");
        }
    }
    onPercentChanged: check()
    onChargingChanged: check()
    onAvailableChanged: check()
    onHeldChanged: check()

    function simulate(p, chargingNow) {
        testCharging = chargingNow;
        testPercent = p;
        check();
    }
}
