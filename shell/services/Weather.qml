pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Weather for the desktop widget from Open-Meteo (no key). The place is
// Config.widgets.weatherCity (geocoded by Open-Meteo), or, when empty, a rough
// location from the IP (ipwho.is, over https). One curl chain on start and every 30 min,
// only while a widget raises `watchers`.
Singleton {
    id: root

    property int watchers: 0
    property string place: ""
    property bool loading: false
    property string error: ""
    property var current: null      // { temp, feels, code, wind, day }
    property var days: []           // [{ date, max, min, code }]
    property real updated: 0

    readonly property string city: Config.widgets.weatherCity
    readonly property bool fahrenheit: Config.widgets.fahrenheit
    onCityChanged: if (watchers > 0) refresh()
    onFahrenheitChanged: if (watchers > 0) refresh()
    onWatchersChanged: if (watchers > 0 && Date.now() - updated > 25 * 60000) refresh()

    Timer {
        interval: 30 * 60000
        repeat: true
        running: root.watchers > 0
        onTriggered: root.refresh()
    }

    // Shell code that sets $ua, $lat, $lon and $name from the place in $1 (empty:
    // the IP's rough location); exits 1 without a connection, 2 if not found.
    // Also used by services/Schedule.qml for sun times.
    readonly property string locate: '
ua="SomeShell (https://github.com/someact/SomeShell)"
if [ -n "$1" ]; then
  g=$(curl -sfG -m 10 -A "$ua" --data-urlencode "name=$1" -d count=1 https://geocoding-api.open-meteo.com/v1/search) || exit 1
  lat=$(printf %s "$g" | jq -r ".results[0].latitude // empty"); lon=$(printf %s "$g" | jq -r ".results[0].longitude // empty")
  name=$(printf %s "$g" | jq -r ".results[0].name // empty")
else
  g=$(curl -sf -m 10 -A "$ua" "https://ipwho.is/?fields=latitude,longitude,city") || exit 1
  lat=$(printf %s "$g" | jq -r ".latitude // empty"); lon=$(printf %s "$g" | jq -r ".longitude // empty"); name=$(printf %s "$g" | jq -r ".city // empty")
fi
[ -n "$lat" ] || exit 2
'

    // $1 city (may be empty), $2 temperature unit. Prints "<place>\t<forecast json>"
    readonly property string script: locate + '
f=$(curl -sfG -m 10 -A "$ua" -d latitude=$lat -d longitude=$lon -d timezone=auto -d forecast_days=4 -d temperature_unit=$2 \
  -d current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,is_day \
  -d daily=temperature_2m_max,temperature_2m_min,weather_code https://api.open-meteo.com/v1/forecast) || exit 1
printf "%s\t%s" "$name" "$f"'

    function refresh() {
        if (proc.running)
            return;
        loading = true;
        proc.command = ["sh", "-c", script, "_", city.trim(), fahrenheit ? "fahrenheit" : "celsius"];
        proc.running = true;
    }

    Process {
        id: proc
        stdout: StdioCollector {
            id: out
        }
        onExited: code => {
            root.loading = false;
            if (code !== 0) {
                root.error = code === 2 ? "Place not found" : "No connection";
                return;
            }
            const tab = out.text.indexOf("\t");
            try {
                const f = JSON.parse(out.text.slice(tab + 1));
                root.place = out.text.slice(0, tab);
                root.current = { temp: Math.round(f.current.temperature_2m), feels: Math.round(f.current.apparent_temperature), code: f.current.weather_code, wind: Math.round(f.current.wind_speed_10m), day: f.current.is_day === 1 };
                root.days = f.daily.time.map((d, i) => ({ date: d, max: Math.round(f.daily.temperature_2m_max[i]), min: Math.round(f.daily.temperature_2m_min[i]), code: f.daily.weather_code[i] }));
                root.error = "";
                root.updated = Date.now();
            } catch (e) {
                root.error = "Bad answer";
            }
        }
    }

    // WMO weather codes → Material Symbols icon and words
    function icon(code, day) {
        if (code === 0)
            return day === false ? "clear_night" : "clear_day";
        if (code <= 2)
            return day === false ? "partly_cloudy_night" : "partly_cloudy_day";
        if (code === 3)
            return "cloud";
        if (code <= 48)
            return "foggy";
        if (code <= 57)
            return "rainy_light";
        if (code <= 67 || (code >= 80 && code <= 82))
            return "rainy";
        if (code <= 77 || code === 85 || code === 86)
            return "weather_snowy";
        return "thunderstorm";
    }
    function text(code) {
        if (code === 0)
            return "Clear";
        if (code <= 2)
            return "Partly cloudy";
        if (code === 3)
            return "Cloudy";
        if (code <= 48)
            return "Fog";
        if (code <= 57)
            return "Drizzle";
        if (code <= 67)
            return "Rain";
        if (code <= 77)
            return "Snow";
        if (code <= 82)
            return "Showers";
        if (code <= 86)
            return "Snow showers";
        return "Thunderstorm";
    }
}
