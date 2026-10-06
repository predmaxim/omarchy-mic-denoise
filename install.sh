#!/bin/bash
# RNNoise plugin, the filter fragment with this machine's microphone, PipeWire's stock
# filter-chain.service, and the denoised source as the default input. Re-run to upgrade.
#   ./install.sh [alsa_input source name]   (default: the first alsa_input.* source)
set -euo pipefail
cd "$(dirname "$0")"
conf=${XDG_CONFIG_HOME:-$HOME/.config}/pipewire/filter-chain.conf.d/mic-denoise.conf

if ! pacman -Q noise-suppression-for-voice &>/dev/null; then
  if command -v omarchy-pkg-add >/dev/null; then omarchy-pkg-add noise-suppression-for-voice
  else sudo pacman -S --needed --noconfirm noise-suppression-for-voice; fi
fi

mic=${1:-$(pactl list sources short | awk '$2 ~ /^alsa_input\./ { print $2; exit }')}
[[ -n $mic ]] || { echo "no alsa_input.* source; pass its name: ./install.sh <source>" >&2; exit 1; }

# Named after the microphone it is pinned to, as audio panels show it ("ALC257 Analog").
nick=$(pactl -f json list sources | jq -r --arg n "$mic" '.[] | select(.name == $n) | .properties["node.nick"] // .description')
suffix="denoised"; [[ ${LC_ALL:-${LC_MESSAGES:-${LANG:-}}} == ru* ]] && suffix="без шума"
name="${nick:-Microphone} ($suffix)"
aec_name="${nick:-Microphone} (echo cancelled, no RNNoise)"
mkdir -p "$(dirname "$conf")"
sed "s|@MIC_SOURCE@|$mic|; s|@NAME@|$name|; s|@AEC_NAME@|$aec_name|" mic-denoise.conf > "$conf"
systemctl --user enable filter-chain.service >/dev/null 2>&1
systemctl --user restart filter-chain.service

for _ in $(seq 50); do pactl list sources short | grep -q $'\tmic_denoise\t' && break; sleep 0.1; done
id=$(pactl list sources short | awk '$2 == "mic_denoise" { print $1 }')
[[ -n $id ]] || { echo "mic_denoise did not appear: journalctl --user -u filter-chain" >&2; exit 1; }

# pactl only: Omarchy's omarchy-audio-input-set-default also moves every capture stream,
# including ones pinned to another source (agent-speak's echo-cancel recorder).
pactl set-default-source mic_denoise
echo "default input: $name <- $mic"
