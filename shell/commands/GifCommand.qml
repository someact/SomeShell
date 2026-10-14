import QtQuick
import qs.core
import qs.services

Command {
    name: "gif"
    icon: "gif_box"
    args: "<words>"
    description: "Search GIFs (" + Gifs.serviceName + "); Enter copies one, Ctrl+S saves it"
    keepOpen: true
    function run(arg) {
        Gifs.seed = arg;
        UiState.open("gif");
    }
}
