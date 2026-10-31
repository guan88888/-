"""Compose/render an original seamless ambient score; no sampled recordings.

Requires Python, numpy and ffmpeg. Run from any directory.
The score and synthesizers are included so the music can be regenerated.
"""
from pathlib import Path
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
BEAT = 60 / 72
BARS = 24
SECONDS = BEAT * 4 * BARS  # 80 seconds, exactly 24 bars.
COUNT = round(SECONDS * RATE)
mix = np.zeros((COUNT, 2), dtype=np.float64)


def hz(note):
    return 440 * 2 ** ((note - 69) / 12)


def add(signal, start, gain=1, pan=0):
    """Wrap every tail across the loop boundary, including reverb/delay."""
    indices = (round(start * RATE) + np.arange(len(signal))) % COUNT
    gains = np.array([np.sqrt((1 - pan) / 2), np.sqrt((1 + pan) / 2)])
    np.add.at(mix, indices, signal[:, None] * gains * gain)


def pad(note, start, duration, pan):
    t = np.arange(round((duration + 3.0) * RATE)) / RATE
    attack = np.minimum(t / 2.4, 1)
    release = np.minimum(np.maximum((duration + 3.0 - t) / 3.0, 0), 1)
    env = np.sin(attack * np.pi / 2) ** 2 * np.sin(release * np.pi / 2) ** 2
    f = hz(note)
    # Gently detuned sine voices; slow motion without a harsh saw-wave edge.
    tone = (np.sin(2 * np.pi * f * t + 0.12 * np.sin(2 * np.pi * 0.14 * t))
            + 0.35 * np.sin(2 * np.pi * f * 1.0017 * t)
            + 0.15 * np.sin(2 * np.pi * f * 2 * t))
    add(tone * env, start, 0.042, pan)


def pluck(note, start, pan, gain=0.07):
    t = np.arange(round(4.8 * RATE)) / RATE
    env = (1 - np.exp(-t * 35)) * np.exp(-t / 1.05)
    tone = np.sin(2 * np.pi * hz(note) * t) + 0.18 * np.sin(2 * np.pi * hz(note) * 2 * t)
    signal = tone * env
    add(signal, start, gain, pan)
    for delay, level in [(0.75 * BEAT, 0.28), (1.5 * BEAT, 0.14), (3 * BEAT, 0.06)]:
        add(signal, start + delay, gain * level, -pan)


# D minor/add9, Bb major7, F/add9, C/sus2, then a second phrase.
# Each chord lasts three bars. Voicings keep common tones for a calm loop.
chords = [(50, 57, 60, 64), (46, 53, 57, 60), (41, 53, 57, 67), (48, 55, 62, 67),
          (50, 57, 64, 65), (46, 53, 60, 65), (43, 55, 58, 62), (45, 52, 55, 62)]
motifs = [(74, 69, 72, 76), (74, 77, 72, 69), (72, 69, 67, 65), (67, 74, 72, 67),
          (77, 76, 74, 69), (77, 74, 72, 69), (74, 70, 69, 67), (76, 74, 69, 73)]
for phrase, chord in enumerate(chords):
    start = phrase * 12 * BEAT
    for voice, note in enumerate(chord):
        pad(note, start, 12 * BEAT, (voice - 1.5) * 0.38)
    # Rounded bass, three long notes per phrase.
    for bar in range(3):
        t = np.arange(round(4 * BEAT * RATE)) / RATE
        envelope = (1 - np.exp(-t * 5)) * np.exp(-t / 1.4) * np.minimum((4 * BEAT - t) * 8, 1)
        add(np.sin(2 * np.pi * hz(chord[0] - 12) * t) * envelope,
            start + bar * 4 * BEAT, 0.10)
    for j, offset in enumerate([0.5, 3.5, 7, 10]):
        pluck(motifs[phrase][j], start + offset * BEAT, (-1 if j % 2 else 1) * 0.35)
    # Quiet heartbeat on the second and third bars, never a forceful dance beat.
    for offset in [4, 6, 8, 10]:
        t = np.arange(round(0.5 * RATE)) / RATE
        phase = 2 * np.pi * (43 * t + 25 * 0.035 * (1 - np.exp(-t / 0.035)))
        pulse = np.sin(phase) * (1 - np.exp(-t * 180)) * np.exp(-t * 12)
        add(pulse, start + offset * BEAT, 0.055)

# Reverb reflections use circular delays, so decay is continuous at the seam.
dry = mix.copy()
for delay, gain in [(0.113, 0.13), (0.197, 0.10), (0.331, 0.08), (0.571, 0.05)]:
    mix += np.roll(dry[:, ::-1], round(delay * RATE), axis=0) * gain
# Smooth periodic frequency filtering has no startup transient at the loop seam.
frequencies = np.fft.rfftfreq(COUNT, 1 / RATE)
response = 1 / np.sqrt(1 + (30 / np.maximum(frequencies, 1e-9)) ** 4)
response /= np.sqrt(1 + (frequencies / 6500) ** 4)
mix = np.fft.irfft(np.fft.rfft(mix, axis=0) * response[:, None], n=COUNT, axis=0)
mix *= 0.65 / np.max(np.abs(mix))
pcm = np.round(mix * 32767).astype("<i2")
destination = Path(__file__).resolve().parents[1] / "assets" / "audio" / "deep_blue_watch.ogg"
destination.parent.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="stargate-score-") as temp:
    source = Path(temp) / "score.wav"
    with wave.open(str(source), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(source),
                    "-c:a", "vorbis", "-strict", "experimental", "-b:a", "192k", "-metadata", "title=深蓝守望",
                    "-metadata", "artist=星门纪元原创配乐", str(destination)], check=True)
print(f"Created {destination}: {SECONDS:.1f}s, stereo {RATE}Hz")
print(f"PCM peak={np.max(np.abs(mix)):.4f}, RMS={np.sqrt(np.mean(mix ** 2)):.4f}, "
      f"loop seam delta={np.max(np.abs(mix[0] - mix[-1])):.6f}")
