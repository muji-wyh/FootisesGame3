"""Synthesise small, royalty-free (CC0, self-generated) SFX and a looping BGM for
Brawl Arena. Pure standard library (wave/struct/math). Outputs 16-bit mono WAVs to
assets/audio/. Re-run to regenerate: python tools/gen_audio.py
"""
import math
import os
import struct
import wave
import random

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def _write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    peak = max(1e-6, max(abs(s) for s in samples))
    norm = min(1.0, 0.9 / peak) if peak > 0.9 else 1.0
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for s in samples:
            v = int(max(-1.0, min(1.0, s * norm)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(frames)
    print("wrote", name, len(samples), "samples")


def _env(i, n, attack=0.01, release=0.3):
    t = i / RATE
    dur = n / RATE
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, (dur - t) / release) if release > 0 else 1.0
    return max(0.0, a) * max(0.0, r)


def hit():
    n = int(RATE * 0.16)
    out = []
    for i in range(n):
        t = i / RATE
        e = math.exp(-t * 28.0)
        thump = math.sin(2 * math.pi * 130 * t) * e
        noise = (random.uniform(-1, 1)) * math.exp(-t * 45.0)
        out.append(0.7 * thump + 0.5 * noise)
    return out


def block():
    n = int(RATE * 0.13)
    out = []
    for i in range(n):
        t = i / RATE
        e = math.exp(-t * 36.0)
        click = math.sin(2 * math.pi * 210 * t) * e
        noise = random.uniform(-1, 1) * math.exp(-t * 70.0)
        out.append(0.45 * click + 0.3 * noise)
    return out


def whoosh():
    n = int(RATE * 0.18)
    out = []
    prev = 0.0
    for i in range(n):
        t = i / RATE
        swish = math.sin(math.pi * (t / (n / RATE)))  # rise then fall
        noise = random.uniform(-1, 1)
        prev = 0.85 * prev + 0.15 * noise              # low-passed noise
        out.append(0.5 * prev * swish)
    return out


def jump():
    n = int(RATE * 0.13)
    out = []
    for i in range(n):
        t = i / RATE
        f = 300 + 500 * (t / (n / RATE))
        out.append(0.5 * math.sin(2 * math.pi * f * t) * _env(i, n, 0.005, 0.05))
    return out


def ko():
    n = int(RATE * 0.55)
    out = []
    for i in range(n):
        t = i / RATE
        f = 420 * math.exp(-t * 3.2) + 70
        tone = math.sin(2 * math.pi * f * t) * math.exp(-t * 4.0)
        noise = random.uniform(-1, 1) * math.exp(-t * 30.0)
        out.append(0.6 * tone + 0.5 * noise)
    return out


def bgm():
    # 4-second seamless loop: a kick on each beat plus a bass arpeggio.
    beats = 8
    beat = 0.5  # 120 BPM
    n = int(RATE * beats * beat)
    out = [0.0] * n
    scale = [55.0, 65.41, 73.42, 82.41]  # A1, C2, D2, E2
    for b in range(beats):
        start = int(b * beat * RATE)
        # kick
        for i in range(int(RATE * 0.12)):
            idx = start + i
            if idx >= n:
                break
            t = i / RATE
            f = 120 * math.exp(-t * 18.0) + 45
            out[idx] += 0.6 * math.sin(2 * math.pi * f * t) * math.exp(-t * 12.0)
        # bass note
        note = scale[b % len(scale)]
        for i in range(int(RATE * beat)):
            idx = start + i
            if idx >= n:
                break
            t = i / RATE
            saw = 2.0 * ((note * t) % 1.0) - 1.0
            out[idx] += 0.18 * saw * math.exp(-t * 1.5)
    return out


if __name__ == "__main__":
    random.seed(7)
    _write("hit.wav", hit())
    _write("block.wav", block())
    _write("whoosh.wav", whoosh())
    _write("jump.wav", jump())
    _write("ko.wav", ko())
    _write("bgm.wav", bgm())
    print("done")
