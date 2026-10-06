#!/bin/bash
# Remove the fragment, hand the default input back to the microphone, stop the service
# if nothing else uses it. The noise-suppression-for-voice package stays.
set -euo pipefail
conf=${XDG_CONFIG_HOME:-$HOME/.config}/pipewire/filter-chain.conf.d/mic-denoise.conf
[[ -f $conf ]] || { echo "not installed"; exit 0; }

mic=$(grep -m1 -o 'target.object *= *"[^"]*"' "$conf" | sed 's/.*"\(.*\)"/\1/')
[[ $(pactl get-default-source) == mic_denoise && -n $mic ]] && pactl set-default-source "$mic"
rm "$conf"
if ls "$(dirname "$conf")"/*.conf &>/dev/null; then systemctl --user restart filter-chain.service
else
  systemctl --user disable --now filter-chain.service
  # The stock unit has Also=pipewire.socket, so disabling it disables the socket too.
  systemctl --user enable pipewire.socket >/dev/null 2>&1
fi
echo "removed; the package stays: pacman -Rns noise-suppression-for-voice"
