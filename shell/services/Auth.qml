pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs.core

// The polkit agent: an app asks for the admin password (pkexec, a package
// manager, a disk tool) → the island opens on the tabless `auth` page.
// Quickshell registers the agent on the session bus; when another agent
// already runs, `registered` stays false and that one answers.
//   flow       the request now (null when none)
//   wrongTick  counts wrong passwords (the page shakes)
// Leaving the page (Esc, Cancel, closing the island) cancels the request.
Singleton {
    id: root

    readonly property bool registered: agent.isRegistered
    readonly property var flow: agent.isActive ? agent.flow : null
    readonly property bool asking: flow !== null
    property int wrongTick: 0
    property string error: ""

    function submit(password) {
        if (flow && flow.isResponseRequired)
            flow.submit(password);
    }
    function cancel() {
        if (flow)
            flow.cancelAuthenticationRequest();
    }
    // Several users can answer (polkit's admin group): the next one
    function nextUser(d) {
        const ids = flow?.identities ?? [];
        if (ids.length < 2)
            return;
        const i = ids.indexOf(flow.selectedIdentity);
        flow.selectedIdentity = ids[(i + d + ids.length) % ids.length];
    }

    PolkitAgent {
        id: agent
        onAuthenticationRequestStarted: {
            root.error = "";
            Ui.openPage("auth");
        }
    }

    Connections {
        target: root.flow
        function onAuthenticationFailed() {
            root.error = "Wrong password";
            root.wrongTick++;
        }
        function onSupplementaryMessageChanged() {
            if (root.flow?.supplementaryIsError && root.flow.supplementaryMessage)
                root.error = root.flow.supplementaryMessage;
        }
    }

    // The request ended (unlocked, cancelled, or the app gave up): leave the page
    onAskingChanged: {
        if (!asking && Ui.open && Ui.pageId === "auth")
            Ui.close();
    }
    // The page left while asking: cancel, so the app is not left waiting
    Connections {
        target: Ui
        function onPageIdChanged() { leave.restart(); }
        function onOpenChanged() { leave.restart(); }
    }
    Timer {
        id: leave
        interval: 50
        onTriggered: {
            if (root.asking && !(Ui.open && Ui.pageId === "auth"))
                root.cancel();
        }
    }
}
