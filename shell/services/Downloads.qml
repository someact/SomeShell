pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Video links downloaded with yt-dlp (lib/download.sh): video into Videos,
// audio into Music. Each download is a job (Jobs) while it runs; the alert at
// the end opens the file.
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("lib/download.sh")

    function start(url, mode, title) {
        const name = title || url;
        const job = proc.createObject(root, { url: url, mode: mode, title: name });
        job.jobId = Jobs.add("download", mode === "audio" ? "music_note" : "download", name, () => job.cancelled());
        job.running = true;
    }

    Component {
        id: proc
        Process {
            id: p
            property string url
            property string mode
            property string title
            property int jobId: 0
            property string file: ""
            property string error: ""
            property bool stopped: false
            command: [root.script, mode, url]
            function cancelled() {
                stopped = true;
                signal(15);
            }
            stdout: SplitParser {
                onRead: line => {
                    if (line.startsWith("P ")) {
                        const v = parseFloat(line.slice(2));
                        if (!isNaN(v))
                            Jobs.progress(p.jobId, v / 100);
                    } else if (line.startsWith("T ")) {
                        p.title = line.slice(2);
                        Jobs.update(p.jobId, { title: p.title });
                    } else if (line.startsWith("F ")) {
                        p.file = line.slice(2);
                    }
                }
            }
            stderr: SplitParser {
                onRead: line => {
                    if (line.startsWith("ERROR:"))
                        p.error = line.slice(6).trim();
                }
            }
            onExited: code => {
                Jobs.finish(jobId);
                if (stopped)
                    Ui.showAlert("Download stopped", title, "Download", "block");
                else if (code === 0 && file)
                    Ui.showAlert(mode === "audio" ? "Audio saved" : "Video saved", file.split("/").pop() + " · click to open", "Download", mode === "audio" ? "music_note" : "movie", { open: file });
                else
                    Ui.showAlert("Download failed", error || title, "Download", "error", { wide: error.length > 40 });
                destroy();
            }
        }
    }
}
