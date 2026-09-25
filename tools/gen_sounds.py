"""Generate the alarm sounds in assets/sounds/ (standard library only).

Looping sounds (2-4 s each; the app loops them and ramps volume itself):
  chime_loop.wav    Gentle chime: soft sine bells, high pitch. Quietest.
  beep_loop.wav     Classic two-tone beep, 1.3-1.8 kHz.
  siren_loop.wav    Rising siren, 0.7-1.6 kHz.
  lowtone_loop.wav  520 Hz square wave in the fire-alarm "temporal-3" pattern.
                    Low-pitched square waves wake people with high-frequency
                    hearing loss far better than high beeps.
  bass_loop.wav     Deep 200 Hz pulses with strong harmonics, for severe
                    high-frequency loss.
  blast_loop.wav    Continuous full-scale mix of low and mid square waves.
                    Loudest possible sound for a given speaker volume.

escalating_30s.wav - 30 s clip that gets louder on its own and turns into the
siren halfway. Used on iOS, where apps can't raise the volume in the background.

Run: python tools/gen_sounds.py   (prints each file's loudness in dBFS)
"""
import math
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"


def square(freq, t, hardness=4.0):
    # Soft-clipped sine: harsher than a sine but less brittle than a pure
    # square. Higher hardness = closer to a true square = louder.
    return math.tanh(hardness * math.sin(2 * math.pi * freq * t))


def chime(t):
    """Two soft bell strikes per 2 s, decaying sines."""
    phase = t % 1.0
    freq = 1320 if int(t) % 2 == 0 else 1760
    env = math.exp(-5 * phase)
    return 0.45 * env * (math.sin(2 * math.pi * freq * t)
                         + 0.3 * math.sin(2 * math.pi * 2 * freq * t))


def beep(t):
    """Two-tone beep-beep pattern with gaps, 0.5 s cycle."""
    phase = t % 0.5
    if phase < 0.12:
        return square(1320, t)
    if 0.18 <= phase < 0.30:
        return square(1760, t)
    return 0.0


def siren(t):
    """Siren sweeping 700 -> 1600 Hz every second."""
    # Integrate frequency so the sweep has no clicks: phase = 2*pi*(700*s + 450*s^2).
    s = t % 1.0
    phase = 2 * math.pi * (700 * s + 450 * s * s) + 2 * math.pi * 1150 * math.floor(t)
    return math.tanh(3 * math.sin(phase))


def low_tone(t):
    """520 Hz square wave, temporal-3: on .5 / off .5 x3, then 1.5 s off (4 s)."""
    phase = t % 4.0
    if phase < 3.0 and (phase % 1.0) < 0.5:
        return square(520, t, hardness=12)
    return 0.0


def bass(t):
    """Deep 200 Hz pulses, 4 per second."""
    phase = t % 0.25
    if phase < 0.16:
        return square(200, t, hardness=12)
    return 0.0


def blast(t):
    """No gaps, full scale: 520 Hz and 780 Hz square waves alternating 8x/s."""
    freq = 520 if int(t * 8) % 2 == 0 else 780
    return square(freq, t, hardness=40)


def write(name, seconds, sample_fn):
    OUT.mkdir(parents=True, exist_ok=True)
    frames = bytearray()
    n = int(seconds * RATE)
    sum_sq = 0.0
    for i in range(n):
        t = i / RATE
        v = max(-1.0, min(1.0, sample_fn(t, seconds)))
        sum_sq += v * v
        frames += struct.pack("<h", int(v * 32000))
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))
    rms_db = 10 * math.log10(sum_sq / n)
    print(f"{name:20s} {seconds:4.0f}s  loudness {rms_db:6.1f} dBFS")


def escalating(t, total):
    # Volume ramps 10% -> 100% over the clip; beeps first, siren in the second half.
    gain = 0.1 + 0.9 * (t / total)
    return gain * (beep(t) if t < total / 2 else siren(t))


if __name__ == "__main__":
    write("chime_loop.wav", 2.0, lambda t, _: chime(t))
    write("beep_loop.wav", 2.0, lambda t, _: beep(t))
    write("siren_loop.wav", 2.0, lambda t, _: siren(t))
    write("lowtone_loop.wav", 4.0, lambda t, _: low_tone(t))
    write("bass_loop.wav", 2.0, lambda t, _: bass(t))
    write("blast_loop.wav", 2.0, lambda t, _: blast(t))
    write("escalating_30s.wav", 30.0, escalating)
