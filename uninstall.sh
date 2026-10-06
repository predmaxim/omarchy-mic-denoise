#!/bin/bash
# Remove the fragment, hand the default input back to the microphone, stop the service
# if nothing else uses it. The noise-suppression-for-voice package stays.
set -euo pipefail
conf=${XDG_CONFIG_HOME:-$HOME/.config}/pipewire/filter-chain.conf.d/mic-denoise.conf
[[ -f $conf ]] || { echo "not installed"; exit 0; }

mic=$(sed -n 's/.*target.object *= *"\([^"]*\)".*/\1/p' "$conf")
[[ $(pactl get-default-source) == mic_denoise && -n $mic ]] && pactl set-default-source "$mic"
rm "$conf"
if ls "$(dirname "$conf")"/*.conf &>/dev/null; then systemctl --user restart filter-chain.service
else systemctl --user disable --now filter-chain.service; fi
echo "removed; the package stays: pacman -Rns noise-suppression-for-voice"
