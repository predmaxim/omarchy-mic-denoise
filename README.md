# Microphone denoise for Omarchy

Makes the laptop's built-in microphone sound like a headset microphone: echo cancellation for
every app, mono, no rumble, and [RNNoise](https://github.com/werman/noise-suppression-for-voice)
noise suppression with a voice gate. A PipeWire source, "Microphone (denoised)" ("Микрофон без
шума" under a Russian locale), hosted by PipeWire's stock `filter-chain.service`, set as the
default input. Nothing in Omarchy is patched.

```
mic -> echo cancellation (webrtc, reference: the monitor of the default output)
    -> high-pass 100 Hz -> RNNoise -> Microphone (denoised)
```

Echo cancellation comes first because it wants the raw, linear microphone signal. Its reference
is whatever plays on the default output, so a browser call, a TTS voice or music is subtracted
without routing anything through a virtual sink; apps that cancel echo themselves (browsers,
Zoom) simply have nothing left to do. The stage between the two, "Microphone (echo cancelled, no
RNNoise)", is a second input in audio panels: PipeWire 1.6.8 crashes the host when it is marked
`Audio/Source/Virtual` to hide it.

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
./check.sh                    # quiet room: raw and denoised at once, denoised must be ≥ 6 dB quieter
./check.sh --echo speech.wav  # plays speech through the output, denoised must be ≥ 10 dB below raw
./uninstall.sh                # default input back to the microphone, fragment removed, service stopped if unused
```

## Tuning

Edit `mic-denoise.conf` and re-run `install.sh`:

- `"Freq"` of the high-pass: 100 Hz; lower it if your voice sounds thin.
- `"VAD Threshold (%)"`: 50; higher gates non-speech harder but can clip the first syllable.
- Level: the source has its own volume in the audio panel; the hardware gain stays on the ALSA node.
- `aec.args`: webrtc's own noise suppression and gain control are off; RNNoise does the noise.

## Why not …

- *EasyEffects* — a GTK app that must stay running to process audio.
- *A WirePlumber smart filter* — would keep the device as the default and insert the filter
  transparently, but Omarchy's own speaker tuning notes that on current PipeWire/WirePlumber a
  smart filter links and passes audio unprocessed.
- *Filtering "any input"* — a filter has one source; wired mics share this node, Bluetooth
  headsets denoise in the earbuds.
- *The echo-cancel module in `pipewire.conf.d`* — works, but lives in the daemon: every change
  needs a PipeWire restart, which drops every PulseAudio client.
