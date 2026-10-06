#!/bin/bash
# Records the raw microphone and the denoised source at the same time, compares their RMS.
# Fails unless the denoised source is at least 6 dB quieter: the graph is down or passes
# audio through unprocessed. Stay quiet while it runs.
#   ./check.sh [seconds]
set -euo pipefail
secs=${1:-5}
conf=${XDG_CONFIG_HOME:-$HOME/.config}/pipewire/filter-chain.conf.d/mic-denoise.conf
raw=$(sed -n 's/.*target.object *= *"\([^"]*\)".*/\1/p' "$conf")
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

rec() { timeout "$secs" pw-record --target "$1" --channels 1 --format s16 "$tmp/$2.wav" 2>/dev/null || true; }
rms() { ffmpeg -hide_banner -i "$tmp/$1.wav" -af astats=measure_perchannel=none:measure_overall=RMS_level -f null - 2>&1 \
        | sed -n 's/.*RMS level dB: //p' | tail -1; }

echo "recording $secs s, stay quiet…"
rec "$raw" raw & rec mic_denoise denoised & wait
r=$(rms raw); d=$(rms denoised)
echo "raw $r dB, denoised $d dB"
awk -v r="$r" -v d="$d" 'BEGIN { exit !(d < r - 6) }' || { echo "FAIL: denoised is not quieter" >&2; exit 1; }
echo OK
