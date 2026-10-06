# Microphone denoise for Omarchy

Makes the laptop's built-in microphone sound like a headset microphone: mono, no rumble, and
[RNNoise](https://github.com/werman/noise-suppression-for-voice) noise suppression with a voice
gate. A PipeWire filter-chain source, "Microphone (denoised)", hosted by PipeWire's stock
`filter-chain.service`, set as the default input. Nothing in Omarchy is patched.

```
mic (stereo) -> mix to mono -> high-pass 100 Hz -> RNNoise -> Microphone (denoised)
```

On a Lenovo Legion (ALC257 digital mic) the noise floor in a quiet room goes from −38 dB to below
−90 dB; speech passes. CPU: ~3 % of one core while something records, nothing otherwise.

## Install

Requirements: Omarchy (or any PipeWire ≥ 1.0 with WirePlumber), `ffmpeg` for `check.sh`.

```bash
git clone https://github.com/predmaxim/omarchy-mic-denoise.git ~/Projects/omarchy-mic-denoise
~/Projects/omarchy-mic-denoise/install.sh      # [alsa_input source name], default: the first one
```

`install.sh` installs `noise-suppression-for-voice`, writes
`~/.config/pipewire/filter-chain.conf.d/mic-denoise.conf` with your microphone's node name, enables
`filter-chain.service`, and makes the denoised source the default input. Re-run it to upgrade after
`git pull` (restarts the filter). The microphone in the 3.5 mm jack is the same PipeWire node, so it
is covered too; a Bluetooth headset keeps its own processing and is still picked by hand in the
audio panel.

```bash
./check.sh        # records raw and denoised at once, fails unless denoised is ≥ 6 dB quieter
./uninstall.sh    # default input back to the microphone, fragment removed, service stopped if unused
```

## Tuning

Edit `mic-denoise.conf` and re-run `install.sh`:

- `"Freq"` of the high-pass: 100 Hz; lower it if your voice sounds thin.
- `"VAD Threshold (%)"`: 50; higher gates non-speech harder but can clip the first syllable.
- Level: the source has its own volume in the audio panel; the hardware gain stays on the ALSA node.

## Why not …

- *EasyEffects* — a GTK app that must stay running to process audio.
- *A WirePlumber smart filter* — would keep the device as the default and insert the filter
  transparently, but Omarchy's own speaker tuning notes that on current PipeWire/WirePlumber a
  smart filter links and passes audio unprocessed.
- *Filtering "any input"* — a filter has one source; wired mics share this node, Bluetooth
  headsets denoise in the earbuds.
