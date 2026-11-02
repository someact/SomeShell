#!/usr/bin/env bash
# System sampler for the System page: one JSON line a second while it runs.
# The page starts it when it opens and stops it when it closes; nothing is
# sampled otherwise. Sensors are found once at start, then only read
# (bash builtins, no process per sample; NVIDIA through one nvidia-smi loop).
#
# Line: {"cpu":%,"cores":n,"cpuTemp":C,"memUsed":kB,"memTotal":kB,
#        "gpu":%|null,"gpuKind":"load"|"clock","gpuMHz":n,"gpuTemp":C,
#        "rx":B/s,"tx":B/s,"diskUsed":B,"diskTotal":B,
#        "batW":tenths of W,"batTemp":tenths of C}
set -u
shopt -s nullglob

# --- find the sensors ---------------------------------------------------
cpu_temps=()
gpu_temps=()
for z in /sys/class/thermal/thermal_zone*; do
    t=$(<"$z/type")
    case "$t" in
        *gpu*) gpu_temps+=("$z/temp") ;;
        cpu* | *cluster* | x86_pkg_temp | *soc*) cpu_temps+=("$z/temp") ;;
    esac
done
for h in /sys/class/hwmon/hwmon*; do
    n=$(<"$h/name")
    case "$n" in
        coretemp | k10temp | zenpower | cpu_thermal) cpu_temps+=("$h"/temp*_input) ;;
        amdgpu | nouveau) gpu_temps+=("$h"/temp1_input) ;;
    esac
done

gpu_kind=""
gpu_busy=""
gpu_cur=""
gpu_max=""
if command -v nvidia-smi >/dev/null && nvidia-smi -L >/dev/null 2>&1; then
    gpu_kind=nvidia
    coproc SMI { exec nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,clocks.gr --format=csv,noheader,nounits -l 1 2>/dev/null; }
else
    for f in /sys/class/drm/card*/device/gpu_busy_percent; do gpu_kind=amd; gpu_busy=$f; break; done
    if [ -z "$gpu_kind" ]; then
        for d in /sys/class/devfreq/*gpu*; do
            gpu_kind=clock; gpu_cur=$d/cur_freq; gpu_max=$d/max_freq; break
        done
    fi
fi

cores=$(grep -c '^cpu[0-9]' /proc/stat)

# A battery's own files: power draw (UPower often reports 0 W on ARM) and temperature
bat=""
for b in /sys/class/power_supply/*; do
    [ "$(<"$b/type")" = Battery ] && [ -r "$b/voltage_now" ] && { bat=$b; break; }
done

# The root disk, once (it changes slowly)
read -r disk_total disk_used < <(df -B1 --output=size,used / | tail -1)

# The helpers set variables instead of printing, so a sample starts no
# process (command substitution would fork every second)
max_temp() {
    local best=0 v f
    for f in "$@"; do
        [ -r "$f" ] || continue
        read -r v <"$f" || continue
        (( v > best )) && best=$v
    done
    temp=$(( best / 1000 ))
}

net_bytes() {
    local name a b n=0 line
    rx=0; tx=0
    while read -r line; do
        (( n++ < 2 )) && continue
        name=${line%%:*}
        name=${name// /}
        case "$name" in lo | tailscale* | docker* | veth* | br-* | virbr* | wg* | tun*) continue ;; esac
        read -r a _ _ _ _ _ _ _ b _ <<<"${line#*:}"
        rx=$(( rx + a )); tx=$(( tx + b ))
    done </proc/net/dev
}

cpu_times() {
    local u n s i w q sq st
    read -r _ u n s i w q sq st _ </proc/stat
    total=$(( u + n + s + i + w + q + sq + st ))
    idle=$(( i + w ))
}

# A pipe nobody writes to: `read -t 1` on it waits a second without `sleep`
exec {tick}<> <(:)

cpu_times; prev_total=$total; prev_idle=$idle
net_bytes; prev_rx=$rx; prev_tx=$tx
smi_line=""

while :; do
    read -r -t 1 -u "$tick" _ || true
    cpu_times
    dt=$(( total - prev_total )); di=$(( idle - prev_idle ))
    cpu=0
    (( dt > 0 )) && cpu=$(( (dt - di) * 100 / dt ))
    prev_total=$total; prev_idle=$idle

    net_bytes
    drx=$(( rx - prev_rx )); dtx=$(( tx - prev_tx ))
    (( drx < 0 )) && drx=0
    (( dtx < 0 )) && dtx=0
    prev_rx=$rx; prev_tx=$tx

    mem_total=0; mem_avail=0
    while read -r k v _; do
        case "$k" in
            MemTotal:) mem_total=$v ;;
            MemAvailable:) mem_avail=$v; break ;;
        esac
    done </proc/meminfo

    max_temp "${cpu_temps[@]}"; cpu_temp=$temp
    max_temp "${gpu_temps[@]}"; gpu_temp=$temp
    gpu=null; gpu_mhz=0
    case "$gpu_kind" in
        nvidia)
            # Take the newest line nvidia-smi has written
            while read -r -t 0.05 -u "${SMI[0]}" line; do smi_line=$line; done
            if [ -n "$smi_line" ]; then
                IFS=', ' read -r gpu gpu_temp gpu_mhz <<<"$smi_line"
            fi
            ;;
        amd) read -r gpu <"$gpu_busy" ;;
        clock)
            read -r c <"$gpu_cur"; read -r m <"$gpu_max"
            (( m > 0 )) && gpu=$(( c * 100 / m ))
            gpu_mhz=$(( c / 1000000 ))
            ;;
    esac
    # Battery: tenths of a watt (power_now, or current x voltage), tenths of a degree
    bat_w=0; bat_t=0
    if [ -n "$bat" ]; then
        if [ -r "$bat/power_now" ]; then
            read -r pw <"$bat/power_now"; bat_w=$(( ${pw#-} / 100000 ))
        elif [ -r "$bat/current_now" ]; then
            read -r ua <"$bat/current_now"; read -r uv <"$bat/voltage_now"
            bat_w=$(( ${ua#-} / 1000 * (uv / 1000) / 100000 ))
        fi
        [ -r "$bat/temp" ] && read -r bat_t <"$bat/temp"
    fi

    kind=load
    [ "$gpu_kind" = clock ] && kind=clock
    [ -z "$gpu_kind" ] && kind=none

    printf '{"cpu":%d,"cores":%d,"cpuTemp":%d,"memUsed":%d,"memTotal":%d,"gpu":%s,"gpuKind":"%s","gpuMHz":%d,"gpuTemp":%d,"rx":%d,"tx":%d,"diskUsed":%d,"diskTotal":%d,"batW":%d,"batTemp":%d}\n' \
        "$cpu" "$cores" "$cpu_temp" $(( mem_total - mem_avail )) "$mem_total" \
        "$gpu" "$kind" "${gpu_mhz:-0}" "${gpu_temp:-0}" "$drx" "$dtx" "$disk_used" "$disk_total" "$bat_w" "$bat_t"
done
