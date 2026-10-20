"""Rendert alle Soundeffekte und den Soundtrack nach audio/*.ogg.

Aufruf:  python tools/make_audio.py           (benötigt numpy, scipy, soundfile)

Alles ist synthetisch, aber sorgfältig gefiltert, mit weichen Hüllkurven und Hall,
damit es angenehm klingt. Die Dateien können jederzeit durch echte Aufnahmen mit
gleichem Namen ersetzt werden.
"""
import os
import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
rng = np.random.default_rng(42)


# ---------------------------------------------------------------- Bausteine

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def noise(dur, color="white"):
    n = rng.standard_normal(int(dur * SR))
    if color == "pink":
        b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
        a = [1, -2.494956002, 2.017265875, -0.522189400]
        n = signal.lfilter(b, a, n)
    elif color == "brown":
        n = signal.lfilter([1], [1, -0.995], n)
    return n / (np.max(np.abs(n)) + 1e-9)


def lp(x, hz, order=2):
    b, a = signal.butter(order, hz / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, hz, order=2):
    b, a = signal.butter(order, hz / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def smooth_random(dur, rate_hz, seed_shift=0):
    """Weiche Zufallskurve 0..1 (für Modulationen)."""
    n = int(dur * rate_hz) + 4
    pts = rng.random(n)
    x = np.linspace(0, n - 3, int(dur * SR))
    i = np.floor(x).astype(int)
    f = x - i
    f = f * f * (3 - 2 * f)
    return pts[i] * (1 - f) + pts[i + 1] * f


def env_adsr(n, a, d, s, r):
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = max(na, 1)
    e[:na] = np.linspace(0, 1, na) ** 1.5
    e[na:na + nd] = np.linspace(1, s, len(e[na:na + nd]))
    if nr > 0:
        e[-nr:] *= np.linspace(1, 0, nr) ** 1.5
    return e


def reverb(x, wet=0.25, size=1.0, damp=3500):
    """Kleiner Schroeder-Hall (4 Kämme + 2 Allpässe)."""
    out = np.zeros(len(x) + int(SR * 2.5 * size))
    xin = np.concatenate([x, np.zeros(len(out) - len(x))])
    xin = lp(xin, damp, 1)
    for d_ms, g in [(29.7, 0.82), (37.1, 0.80), (41.1, 0.79), (43.7, 0.77)]:
        d = int(d_ms * size * SR / 1000)
        a = np.zeros(d + 1)
        a[0] = 1
        a[d] = -g
        out += signal.lfilter([1], a, xin)
    for d_ms, g in [(5.0, 0.7), (1.7, 0.7)]:
        d = int(d_ms * SR / 1000)
        b = np.zeros(d + 1)
        b[0] = -g
        b[d] = 1
        a = np.zeros(d + 1)
        a[0] = 1
        a[d] = -g
        out = signal.lfilter(b, a, out)
    out = out / (np.max(np.abs(out)) + 1e-9)
    dry = np.concatenate([x, np.zeros(len(out) - len(x))])
    return dry * (1 - wet) + out * wet * np.max(np.abs(x))


def make_loop(x, fade=1.0):
    """Nahtlose Schleife: Ende über den Anfang blenden."""
    n = int(fade * SR)
    head, body, tail = x[:n], x[n:-n] if n else x, x[-n:]
    ramp = np.linspace(0, 1, n)
    mixed = tail * (1 - ramp) + head * ramp
    return np.concatenate([mixed, x[n:len(x) - n]])


def norm(x, peak_db=-3.0):
    return x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20)


def save(name, x, peak_db=-3.0, stereo=False):
    os.makedirs(OUT, exist_ok=True)
    x = norm(x, peak_db)
    if stereo and x.ndim == 1:
        x = np.stack([x, x], axis=1)
    x = x.astype(np.float32)
    channels = 1 if x.ndim == 1 else x.shape[1]
    # in Blöcken schreiben (libsndfile stürzt sonst bei langen Vorbis-Dateien ab)
    with sf.SoundFile(os.path.join(OUT, name + ".ogg"), "w", SR, channels, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(x), SR // 4):
            f.write(x[i:i + SR // 4])
    print("wrote", name, f"{len(x) / SR:.1f}s")


# ---------------------------------------------------------------- Effekte

def wind_loop():
    dur = 20.0
    base = lp(noise(dur + 2, "brown"), 900)
    gust = 0.55 + 0.45 * smooth_random(dur + 2, 0.25)
    airy = bp(noise(dur + 2, "pink"), 500, 2500) * 0.25 * smooth_random(dur + 2, 0.4)
    x = (base * gust + airy * gust)
    return make_loop(x, 2.0)


def water_loop():
    dur = 10.0
    rush = bp(noise(dur + 1, "pink"), 250, 3000) * (0.6 + 0.4 * smooth_random(dur + 1, 0.7))
    x = rush * 0.6
    # Plätschern: kurze, gefilterte Wassertropfen-Körner
    t = t_axis(dur + 1)
    for _ in range(40):
        at = rng.uniform(0, dur)
        f = rng.uniform(300, 1200)
        n = int(rng.uniform(0.04, 0.12) * SR)
        i = int(at * SR)
        if i + n >= len(x):
            continue
        tt = np.arange(n) / SR
        grain = np.sin(2 * np.pi * (f + f * 2.5 * tt) * tt) * np.exp(-tt * 40)
        x[i:i + n] += grain * rng.uniform(0.02, 0.06)
    x = lp(x, 4000)
    return make_loop(x, 1.0)


def flap_loop():
    dur = 4.0
    t = t_axis(dur + 1)
    cloth = bp(noise(dur + 1, "pink"), 120, 1800)
    rate = 7 + 5 * smooth_random(dur + 1, 1.2)
    phase = np.cumsum(rate) / SR
    flutter = (0.5 + 0.5 * np.sin(2 * np.pi * phase)) ** 3
    snaps = np.zeros_like(t)
    for _ in range(4):
        i = int(rng.uniform(0, dur) * SR)
        n = int(0.05 * SR)
        snaps[i:i + n] += np.exp(-np.arange(len(snaps[i:i + n])) / SR * 60)
    x = cloth * (0.5 + 0.5 * flutter) + lp(noise(dur + 1) * snaps, 1200) * 0.25
    x = lp(x, 1600)
    return make_loop(x, 0.8)


def engine_loop():
    # Gemütlicher Schiffsdiesel: tiefe, weiche Zündimpulse (2 s, ganzzahlige Takte)
    dur = 2.0
    t = t_axis(dur)
    rate = 8.0
    phase = (t * rate) % 1.0
    pulse = np.exp(-phase * 7.0)
    body = np.sin(2 * np.pi * 47 * t) * 0.6 + np.sin(2 * np.pi * 94 * t) * 0.4 + np.sin(2 * np.pi * 141 * t) * 0.25 + np.sin(2 * np.pi * 23.5 * t) * 0.3
    rumble = lp(noise(dur, "brown"), 450) * 0.8
    x = (body + rumble) * (0.35 + 0.65 * pulse)
    x = lp(x, 700, 3)
    return x


def whoosh():
    dur = 1.4
    t = t_axis(dur)
    n = noise(dur, "pink")
    env = np.sin(np.pi * np.clip(t / 1.0, 0, 1)) ** 2
    sweep = np.zeros_like(n)
    # zeitvariabler Bandpass über Blöcke
    blocks = 40
    L = len(n) // blocks
    for k in range(blocks):
        c = 300 + 1500 * np.sin(np.pi * k / blocks)
        seg = bp(n, c * 0.6, c * 1.6)[k * L:(k + 1) * L]
        sweep[k * L:(k + 1) * L] = seg
    x = sweep * env
    # Winsch-Ratsche am Ende: weiche Klicks
    for k in range(6):
        i = int((0.95 + k * 0.06) * SR)
        m = int(0.02 * SR)
        tt = np.arange(m) / SR
        x[i:i + m] += np.sin(2 * np.pi * 2300 * tt) * np.exp(-tt * 300) * 0.08
    return reverb(lp(x, 5000), 0.15, 0.6)


def crunch():
    dur = 1.6
    t = t_axis(dur)
    thud = np.sin(2 * np.pi * (70 - 30 * t) * t) * np.exp(-t * 6)
    scrape = lp(noise(dur, "brown"), 600) * np.exp(-t * 2.2) * (0.6 + 0.4 * smooth_random(dur, 18))
    grit = bp(noise(dur), 800, 2500) * np.exp(-t * 4) * 0.05 * (smooth_random(dur, 40) > 0.6)
    return reverb(thud * 0.9 + scrape * 0.7 + grit, 0.12, 0.5)


def bell_tone(freq, dur, bright=1.0):
    t = t_axis(dur)
    partials = [(0.5, 0.35, 0.9), (1.0, 1.0, 1.6), (1.19, 0.4, 2.2), (1.56, 0.3, 2.8), (2.0, 0.35, 3.2),
                (2.51, 0.18 * bright, 4.5), (3.0, 0.12 * bright, 5.5)]
    x = np.zeros_like(t)
    for ratio, amp, decay in partials:
        x += amp * np.sin(2 * np.pi * freq * ratio * t + rng.uniform(0, 6)) * np.exp(-t * decay)
    x *= np.minimum(1, t * 2000)
    return x


def bell():
    # Tonnenglocke: zwei Schläge, wie vom Seegang angeschlagen
    a = bell_tone(523.25, 3.5)
    b = bell_tone(523.25, 3.0) * 0.6
    x = np.zeros(int(4.0 * SR))
    x[:len(a)] += a
    i = int(0.55 * SR)
    x[i:i + len(b)] += b[:len(x) - i]
    return reverb(x, 0.3, 1.0)


def tick():
    # weicher Holz-/Glockenton für den Countdown
    t = t_axis(0.6)
    x = (np.sin(2 * np.pi * 880 * t) + 0.3 * np.sin(2 * np.pi * 1760 * t)) * np.exp(-t * 9)
    x += np.sin(2 * np.pi * 440 * t) * np.exp(-t * 14) * 0.4
    x *= np.minimum(1, t * 1500)
    return reverb(x, 0.2, 0.5)


def horn(freq, dur, bright=900, detune=0.004):
    t = t_axis(dur)
    x = np.zeros_like(t)
    vib = 1 + 0.003 * np.sin(2 * np.pi * 4.5 * t)
    for d in (-detune, 0, detune):
        ph = np.cumsum(freq * (1 + d) * vib) / SR
        x += 2 * (ph % 1.0) - 1
    x = lp(x, bright, 3)
    x += np.sin(2 * np.pi * freq * t) * 0.5
    e = env_adsr(len(t), 0.12, 0.2, 0.85, 0.5)
    return x * e


def go_signal():
    x = horn(220, 1.2, 1100)
    return reverb(x, 0.3, 1.2)


def tug_horn():
    x = horn(98, 1.6, 650, 0.006) + horn(147, 1.6, 650, 0.006) * 0.5
    return reverb(x, 0.35, 1.5)


def finish():
    # Zielhorn + kleine Glockenfanfare
    x = np.zeros(int(4.5 * SR))
    h = horn(196, 1.0, 1100) * 0.7
    x[:len(h)] += h
    for k, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        b = bell_tone(f, 2.5, 0.6) * 0.5
        i = int((0.9 + k * 0.18) * SR)
        x[i:i + len(b)] += b[:len(x) - i]
    return reverb(x, 0.3, 1.2)


def outboard_loop():
    # kleiner Außenborder: schnelles, gedämpftes Knattern (2 s, ganzzahlige Takte)
    dur = 2.0
    t = t_axis(dur)
    rate = 40.0
    phase = (t * rate) % 1.0
    pulse = np.exp(-phase * 5.0)
    body = np.sin(2 * np.pi * 80 * t) * 0.5 + np.sin(2 * np.pi * 160 * t) * 0.3 + np.sin(2 * np.pi * 240 * t) * 0.15
    rasp = bp(noise(dur, "pink"), 300, 1500) * 0.5
    x = (body + rasp) * (0.45 + 0.55 * pulse)
    # leises Blubbern des Auspuffs unter Wasser
    x += lp(noise(dur, "brown"), 200) * (0.5 + 0.5 * smooth_random(dur, 6)) * 0.6
    return lp(x, 1400, 2)


def starter():
    # Anlasser: Orgeln (rhythmisch), dann Zündung
    dur = 1.3
    t = t_axis(dur)
    crank = np.zeros_like(t)
    for k in range(7):
        i = int((0.05 + k * 0.11) * SR)
        n = int(0.09 * SR)
        tt = np.arange(n) / SR
        crank[i:i + n] += (np.sin(2 * np.pi * 110 * tt) + 0.5 * bp(rng.standard_normal(n), 400, 1800)) * np.exp(-tt * 18)
    run = outboard_loop()[: len(t)]
    env = np.clip((t - 0.8) / 0.15, 0, 1)
    x = crank * (1 - env) * 0.8 + run * env
    return lp(x, 2500)


def engine_stop():
    # Motor stirbt ab: Knattern wird langsamer und leiser
    dur = 1.2
    t = t_axis(dur)
    rate = 40.0 * np.exp(-t * 1.8)
    phase = np.cumsum(rate) / SR % 1.0
    pulse = np.exp(-phase * 5.0)
    x = (np.sin(2 * np.pi * 80 * t) * 0.6 + bp(noise(dur, "pink"), 300, 1200) * 0.4) * pulse * np.exp(-t * 2.5)
    return lp(x, 1200)


# ---------------------------------------------------------------- Soundtrack
# Renn-Shanty im 6/8-Takt, d-Moll: galoppierender Achtelbass, Akkordeon, Tin Whistle,
# Bodhrán mit Wirbeln vor jedem Teil, Streicher-Tremolo für Spannung, leise Brandung.
# 48 Takte, nahtlos schleifbar.

BPM = 96                          # punktierte Viertel pro Minute
EIGHTH = 60 / BPM / 3
BAR = 6 * EIGHTH
NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def hz(name):
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[pitch] + 12 * (octave + 1) - 69) / 12)


CHORDS = {   # Bass, Akkordtöne Mittellage
    "Dm": ["D2", "D4", "F4", "A4"],
    "C": ["C2", "C4", "E4", "G4"],
    "Am": ["A1", "C4", "E4", "A4"],
    "F": ["F1", "C4", "F4", "A4"],
    "G": ["G1", "B3", "D4", "G4"],
    "A": ["A1", "C#4", "E4", "A4"],
    "Bb": ["A#1", "A#3", "D4", "F4"],
}
INTRO = ["Dm", "Dm", "Bb", "A", "Dm", "Dm", "Bb", "A"]
PART_A = ["Dm", "Dm", "C", "C", "Dm", "Dm", "A", "Dm"]
PART_B = ["F", "C", "Dm", "A", "Bb", "C", "A", "A"]
FORM = INTRO + PART_A + PART_A + PART_B + PART_A + PART_B   # 48 Takte

# Melodien in Achteln (6 pro Takt), "-" = Pause
MEL_A = [
    ("D5", 2), ("D5", 1), ("D5", 2), ("A4", 1),
    ("F5", 2), ("E5", 1), ("D5", 3),
    ("E5", 2), ("E5", 1), ("E5", 2), ("C5", 1),
    ("G5", 2), ("F5", 1), ("E5", 3),
    ("D5", 2), ("D5", 1), ("D5", 2), ("F5", 1),
    ("A5", 2), ("G5", 1), ("F5", 2), ("D5", 1),
    ("E5", 2), ("D5", 1), ("C#5", 2), ("A4", 1),
    ("D5", 5), ("-", 1),
]
MEL_B = [
    ("F5", 2), ("A5", 1), ("C6", 2), ("A5", 1),
    ("G5", 2), ("E5", 1), ("C5", 3),
    ("F5", 2), ("E5", 1), ("D5", 2), ("F5", 1),
    ("E5", 3), ("A4", 3),
    ("A#5", 2), ("A5", 1), ("F5", 2), ("D5", 1),
    ("G5", 2), ("F5", 1), ("E5", 2), ("C5", 1),
    ("E5", 2), ("F5", 1), ("G5", 2), ("E5", 1),
    ("C#5", 3), ("E5", 2), ("A5", 1),
]


def accordion(freqs, dur, bright=1.0):
    """Akkordeon: je Ton drei leicht verstimmte Zungen (Musette-Schweben)."""
    t = t_axis(dur)
    x = np.zeros_like(t)
    for f in freqs:
        for det in (-0.0035, 0.0, 0.0035):
            ph = (f * (1 + det) * t + rng.uniform(0, 1)) % 1.0
            x += np.where(ph < 0.35, 1.0, -0.55) * 0.6 + (2 * ph - 1) * 0.4
    x = bp(x, 180, 2600 * bright)
    return x / (len(freqs) * 3) * env_adsr(len(t), 0.035, 0.05, 0.85, min(0.08, dur * 0.3))


def whistle(freq, dur, cut=False):
    """Tin Whistle mit verzögertem Vibrato, Atemgeräusch und gelegentlichem Vorschlag."""
    t = t_axis(dur)
    f = np.full(len(t), freq)
    if cut and dur > 0.15:
        n = int(0.035 * SR)
        f[:n] = freq * 2 ** (2 / 12)            # kurzer Vorschlag von oben
    vib = 1 + 0.007 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.18) / 0.2, 0, 1)
    ph = np.cumsum(f * vib) / SR
    x = np.sin(2 * np.pi * ph) + 0.12 * np.sin(4 * np.pi * ph) + 0.04 * np.sin(6 * np.pi * ph)
    breath = bp(rng.standard_normal(len(t)), 1500, 6000) * 0.035
    return (x + breath) * env_adsr(len(t), 0.02, 0.06, 0.85, min(0.06, dur * 0.3))


def bodhran(accent=1.0):
    t = t_axis(0.45)
    tone = np.sin(2 * np.pi * (72 + 40 * np.exp(-t * 30)) * t) * np.exp(-t * 9)
    skin = lp(rng.standard_normal(len(t)), 900) * np.exp(-t * 35) * 0.5
    return (tone + skin) * accent


def upright_bass(freq, dur):
    t = t_axis(dur)
    x = np.sin(2 * np.pi * freq * t) + 0.45 * np.sin(4 * np.pi * freq * t) + 0.15 * np.sin(6 * np.pi * freq * t)
    pluck_noise = lp(rng.standard_normal(len(t)), 800) * np.exp(-t * 60) * 0.3
    return (x * np.exp(-t * 2.2) + pluck_noise) * env_adsr(len(t), 0.004, 0.0, 1.0, 0.06)


def strings(freqs, dur, swell=True):
    """Tiefe Streicher mit schnellem Tremolo, schwellen an."""
    t = t_axis(dur)
    x = np.zeros_like(t)
    for f in freqs:
        for det in (-0.004, 0.004):
            ph = (f * (1 + det) * t + rng.uniform(0, 1)) % 1.0
            x += 2 * ph - 1
    x = lp(x, 1400, 2)
    trem = 0.6 + 0.4 * (0.5 + 0.5 * np.sin(2 * np.pi * 9.0 * t))
    env = np.clip(t / dur, 0, 1) ** 1.5 if swell else np.ones_like(t)
    return x * trem * env * env_adsr(len(t), 0.05, 0.0, 1.0, 0.1) / len(freqs)


def waves_bed(total):
    """Leise Brandung mit langsamen Wellen (Periode passt in die Schleife)."""
    t = t_axis(total)
    n = noise(total, "brown")
    swell_period = total / 11
    swell = 0.35 + 0.65 * (0.5 + 0.5 * np.sin(2 * np.pi * t / swell_period)) ** 2
    hiss = bp(noise(total, "pink"), 400, 2500) * 0.4
    return lp(n, 700) * swell + hiss * swell ** 2


def place(buf, x, start, gain=1.0, pan=0.0):
    i = int(start * SR)
    j = min(len(buf), i + len(x))
    if j <= i:
        return
    l = np.cos((pan + 1) * np.pi / 4)
    r = np.sin((pan + 1) * np.pi / 4)
    buf[i:j, 0] += x[:j - i] * gain * l
    buf[i:j, 1] += x[:j - i] * gain * r


def music():
    total = len(FORM) * BAR
    buf = np.zeros((int(total * SR) + int(4 * SR), 2))

    def melody(seq, start_bar, inst, gain, pan):
        t = start_bar * BAR
        for k, (nme, eighths) in enumerate(seq):
            d = eighths * EIGHTH
            if nme != "-":
                if inst == "whistle":
                    place(buf, whistle(hz(nme), d * 0.97, cut=(eighths >= 2 and k % 3 == 0)), t, gain, pan)
                else:
                    place(buf, accordion([hz(nme)], d * 0.95, 1.2), t, gain, pan)
            t += d

    for b, ch in enumerate(FORM):
        t0 = b * BAR
        notes = CHORDS[ch]
        chord = [hz(n) for n in notes[1:]]
        root = hz(notes[0])
        build = min(1.0, (b + 1) / 8.0) if b < 8 else 1.0        # Intro schwillt an
        section_bar = b % 8
        # Galoppierender Achtelbass (Grundton, Oktave auf 4)
        for e in range(6):
            f = root * (2.0 if e == 3 else 1.0)
            g = (0.42 if e in (0, 3) else 0.24) * (0.5 + 0.5 * build)
            place(buf, upright_bass(f, EIGHTH * 0.9), t0 + e * EIGHTH, g)
        # Akkordeon-Stöße (ab Takt 3 des Intros)
        if b >= 2:
            for e in (1, 2, 4, 5):
                place(buf, accordion(chord, EIGHTH * 0.8, 0.9), t0 + e * EIGHTH,
                      (0.15 if e in (1, 4) else 0.11) * build, -0.25)
        # Bodhrán: Grundschlag, im letzten Takt jedes Teils ein Wirbel
        if section_bar == 7:
            for e in range(6):
                for half in (0, 1):
                    place(buf, bodhran(0.35 + 0.65 * (e * 2 + half) / 11), t0 + (e + half * 0.5) * EIGHTH, 0.2 * build, 0.15)
        else:
            for e, acc in ((0, 1.0), (2, 0.4), (3, 0.8), (4, 0.3), (5, 0.45)):
                place(buf, bodhran(acc), t0 + e * EIGHTH, 0.2 * build, 0.15)
        # Spannung: Streicher-Tremolo im Intro-Ende und im B-Teil
        in_b = 24 <= b < 32 or b >= 40
        if in_b or 4 <= b < 8:
            place(buf, strings([root * 2, root * 3], BAR * 1.02, swell=(section_bar % 2 == 1)), t0, 0.22 if in_b else 0.16, 0.0)

    # Melodien: A Whistle, A Akkordeon-Lead, B Whistle, A beide, B Whistle
    melody(MEL_A, 8, "whistle", 0.2, 0.25)
    melody(MEL_A, 16, "accordion", 0.2, -0.1)
    melody(MEL_B, 24, "whistle", 0.2, 0.25)
    melody(MEL_A, 32, "whistle", 0.17, 0.25)
    melody(MEL_A, 32, "accordion", 0.13, -0.1)
    melody(MEL_B, 40, "whistle", 0.18, 0.25)

    # Hall, dann Brandung (ohne Hall) dazu
    mixed = np.zeros_like(buf)
    for c in range(2):
        r = reverb(lp(buf[:, c], 7000, 2), 0.2, 1.0 + 0.07 * c)
        mixed[:, c] = r[:len(buf)]
    n = int(total * SR)
    loop = mixed[:n].copy()
    tail = mixed[n:]
    loop[:len(tail)] += tail[:n]
    loop /= np.max(np.abs(loop))
    w = waves_bed(total)[:n]
    w /= np.max(np.abs(w))
    loop[:, 0] += w * 0.16
    loop[:, 1] += np.roll(w, int(0.3 * SR)) * 0.16
    return np.tanh(loop * 1.1)


def trim(x, seconds, fade=1.0):
    """Hallfahne kürzen und ausblenden."""
    x = x[:int(seconds * SR)].copy()
    n = min(int(fade * SR), len(x))
    x[-n:] *= np.linspace(1, 0, n)
    return x


def ship_horn():
    # Typhon eines großen Schiffs: tiefer Dreiklang, lang gehalten, mit leichtem Schwebungseffekt
    dur = 2.6
    t = t_axis(dur)
    x = np.zeros_like(t)
    for f, a in [(98.0, 1.0), (98.0 * 1.003, 0.8), (147.0, 0.55), (196.0, 0.35), (294.0, 0.15)]:
        x += a * (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t))
    x = lp(x, 900, 2)
    x *= env_adsr(len(t), 0.12, 0.2, 0.9, 0.5)
    return trim(reverb(x, 0.3, 1.4), 3.6, 0.8)


def explosion():
    # Seemine: dumpfer Schlag, Druckwelle, prasselnde Trümmer und Wasserplatschen
    dur = 3.2
    t = t_axis(dur)
    thump = np.sin(2 * np.pi * (95 * np.exp(-t * 3.5) + 28) * t) * np.exp(-t * 2.2)
    boom = lp(noise(dur, "brown"), 380) * np.exp(-t * 2.6)
    crack = hp(noise(dur), 900) * np.exp(-t * 14) * 0.9
    body = bp(noise(dur), 150, 1400) * np.exp(-t * 4.5) * 1.3  # Mitten, damit es auch auf kleinen Lautsprechern knallt
    debris = bp(noise(dur), 1200, 5000) * np.exp(-t * 3.0) * 0.12 * (smooth_random(dur, 55) > 0.55)
    splash = lp(noise(dur), 2500) * np.clip((t - 0.9) * 2.0, 0, 1) * np.exp(-(t - 0.9) * 2.0) * 0.18 * smooth_random(dur, 30)
    x = thump * 1.0 + boom * 1.1 + crack + body + debris + np.where(t > 0.9, splash, 0)
    x *= np.minimum(1, t * 1500)
    return reverb(x, 0.22, 1.2)


def police_siren():
    # Wasserschutzpolizei: Hi-Lo-Horn, kommt näher (Lautstärke schwillt an) und fährt wieder ab
    dur = 7.0
    t = t_axis(dur)
    step = (np.floor(t / 0.55) % 2).astype(float)
    f = np.where(step > 0.5, 960.0, 725.0)
    f = lp(f, 40, 1)
    phase = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(phase) + 0.5 * np.sin(2 * phase) + 0.25 * np.sin(3 * phase)
    x = lp(x, 3200, 2)
    swell = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 0.8
    x *= swell * (0.85 + 0.15 * np.sin(2 * np.pi * 5 * t))
    return trim(reverb(x, 0.2, 0.7), 7.6, 0.6)


def siren_phrase():
    # Gesang der Sirenen: zwei sanfte, vibrierende Stimmen in Terzen über einem Pentatonik-Motiv
    dur = 7.5
    t = t_axis(dur)
    notes = [(0.0, 1.2, "A4"), (1.1, 1.0, "C5"), (2.0, 1.3, "D5"), (3.2, 1.0, "E5"), (4.1, 1.4, "D5"),
             (5.3, 1.0, "C5"), (6.1, 1.4, "A4")]
    x = np.zeros_like(t)
    for start, length, name in notes:
        f0 = hz(name)
        i0 = int(start * SR)
        n = int((length + 0.5) * SR)
        n = min(n, len(t) - i0)
        tt = np.arange(n) / SR
        vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * tt) * np.clip(tt * 2, 0, 1)
        for ratio, amp in [(1.0, 1.0), (1.2599, 0.55)]:       # Grundton und große Terz darüber
            ph = 2 * np.pi * np.cumsum(f0 * ratio * vib) / SR
            voice = np.zeros(n)
            for k, a in [(1, 1.0), (2, 0.5), (3, 0.28), (4, 0.12)]:
                voice += a * np.sin(k * ph + rng.uniform(0, 6))
            # Vokalfärbung "aah": Formanten um 800 und 1200 Hz
            voice = voice + 0.6 * bp(voice, 700, 950, 1) + 0.4 * bp(voice, 1100, 1400, 1)
            x[i0:i0 + n] += amp * voice * env_adsr(n, 0.25, 0.2, 0.8, 0.45)
    breath = bp(noise(dur), 2500, 6000) * 0.02 * smooth_random(dur, 6)
    x = x / (np.max(np.abs(x)) + 1e-9) + breath
    return x


def siren_song():
    # zwei Strophen hintereinander: der Gesang hält an, solange das Boot festsitzt (16 s)
    x = np.concatenate([siren_phrase(), siren_phrase() * 0.9])
    return trim(reverb(x, 0.45, 1.8), 16.8, 1.5)


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "motor":
        save("outboard_loop", outboard_loop(), -6)
        save("starter", starter(), -5)
        save("engine_stop", engine_stop(), -6)
        sys.exit()
    if len(sys.argv) > 1 and sys.argv[1] == "hazards":
        save("explosion", explosion(), -1)
        save("police_siren", police_siren(), -6)
        save("siren_song", siren_song(), -5)
        save("ship_horn", ship_horn(), -4)
        sys.exit()
    if len(sys.argv) > 1 and sys.argv[1] == "music":
        save("music_loop", music(), -4, stereo=True)
        sys.exit()
    save("wind_loop", wind_loop(), -6)
    save("water_loop", water_loop(), -6)
    save("flap_loop", flap_loop(), -6)
    save("engine_loop", engine_loop(), -6)
    save("whoosh", whoosh(), -4)
    save("crunch", crunch(), -3)
    save("bell", bell(), -4)
    save("beep", tick(), -6)
    save("go", go_signal(), -4)
    save("finish", finish(), -3)
    save("tug_horn", tug_horn(), -4)
    save("outboard_loop", outboard_loop(), -6)
    save("starter", starter(), -5)
    save("engine_stop", engine_stop(), -6)
    save("music_loop", music(), -4, stereo=True)
