#!/bin/bash
# Quiet check: records the raw microphone and the denoised source at once and compares
# their RMS. Fails unless the denoised source is at least 6 dB quieter: the chain is down
# or passes audio through unprocessed. Stay quiet while it runs.
#   ./check.sh [seconds]
# Echo check: plays a speech file through the default output while recording raw, after
# echo cancellation, and denoised. Fails unless the denoised source is 10 dB below raw:
# with echo cancellation off, RNNoise alone passes the played speech almost untouched.
#   ./check.sh --echo speech.wav
set -euo pipefail
conf=${XDG_CONFIG_HOME:-$HOME/.config}/pipewire/filter-chain.conf.d/mic-denoise.conf
raw=$(grep -m1 -o 'target.object *= *"[^"]*"' "$conf" | sed 's/.*"\(.*\)"/\1/')
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

rec() { timeout "$secs" pw-record --target "$1" --channels 1 --format s16 "$tmp/$2.wav" 2>/dev/null || true; }
rms() { ffmpeg -hide_banner -i "$tmp/$1.wav" -af astats=measure_perchannel=none:measure_overall=RMS_level -f null - 2>&1 \
        | sed -n 's/.*RMS level dB: //p' | tail -1; }
quieter_by() { awk -v a="$1" -v b="$2" -v n="$3" 'BEGIN { exit !(b < a - n) }'; }

if [[ ${1:-} == --echo ]]; then
  wav=${2:?speech file}
  secs=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$wav" | cut -d. -f1); (( secs > 8 )) && secs=8
  echo "playing $wav for $secs s, recording raw / echo-cancelled / denoised…"
  rec "$raw" raw & rec mic_aec aec & rec mic_denoise denoised & timeout "$secs" pw-play "$wav" 2>/dev/null || true; wait
  r=$(rms raw); a=$(rms aec); d=$(rms denoised)
  echo "raw $r dB, echo cancelled $a dB, denoised $d dB"
  quieter_by "$r" "$d" 10 || { echo "FAIL: echo is not cancelled" >&2; exit 1; }
else
  secs=${1:-5}
  echo "recording $secs s, stay quiet…"
  rec "$raw" raw & rec mic_denoise denoised & wait
  r=$(rms raw); d=$(rms denoised)
  echo "raw $r dB, denoised $d dB"
  quieter_by "$r" "$d" 6 || { echo "FAIL: denoised is not quieter" >&2; exit 1; }
fi
echo OK
