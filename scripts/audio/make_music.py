#!/usr/bin/env python3
"""Muzica de fundal [D51], compusa si sintetizata aici, de la zero: nicio mostra, nicio bucata
luata de altundeva -- deci niciun drept de autor in afara de al nostru [owner, 2026-09-13: "o
muzica instrumentala ceva specifica temei noastre, no copyright"].

TEMA: malul unui rau, lemn, o taverna. Folk linistit, nu arcade: o lauta ciupita (arpegii), un
fluier de lemn cu melodia, un pad moale, contrabas, o kalimba ca picaturile de apa, shaker si toaca
de lemn foarte incete, apa departe. Re major, 84 BPM, 48 de masuri (~2:17):

    A1 (intrarea: lauta, pad, kalimba) · A2 (+ fluier, bas) · B (+ shaker, toaca) ·
    A3 (melodia variata, toba de rama) · C (respiro: lauta rara, kalimba) · A4 (melodia, din nou)

BUCLA FARA CUSATURA: tot ce suna dupa ultima masura (notele care se sting, reverbul) se aduna
peste inceputul piesei, iar apa e facuta cu capetele suprapuse. Cand Roblox reia bucla, nimic nu
se taie si nimic nu pocneste.

Totul cu numpy: corzile din armonice care se sting (nu Karplus-Strong esantion cu esantion, care
ar dura minute in Python), reverbul prin convolutie in FFT cu un raspuns sintetic. Timpul si
intensitatea notelor sunt usor umanizate, din acelasi seed -- piesa iese identica la fiecare rulare.

[D61] A doua piesa, a balciului: un dans de seara in Sol major, 108 BPM, 32 de masuri, cu aceleasi instrumente.

Folosire: python3 scripts/audio/make_music.py [river|fair] [cale_preview.mp3]
Scrie assets/audio/music_<piesa>.ogg (ce urca scripts/upload_assets.py --audio music_<piesa>) si,
optional, un MP3 de ascultat (macOS nu deschide .ogg din Finder).
"""
import os
import shutil
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
TAIL_SECONDS = 5.0  # cat mai suna dupa ultima masura; se aduna peste inceput

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUDIO_DIR = os.path.join(ROOT, "assets", "audio")
OGGENC = shutil.which("oggenc") or "/opt/homebrew/bin/oggenc"
LAME = shutil.which("lame") or "/opt/homebrew/bin/lame"

# Starea piesei in lucru. `start` o pune la zero; instrumentele de mai jos o citesc la fiecare apel, deci aceleasi
# functii scriu si raul, si balciul [D61]. Ordinea apelurilor e cea dinainte, asa ca raul iese esantion cu esantion la
# fel ca inainte de impartirea pe piese (verificat pe 2026-09-17).
BPM = BEAT = BAR = LOOP_SECONDS = 0.0
BARS = TOTAL = 0
rng = np.random.default_rng(0)
mixL = mixR = np.zeros(0)
# pista separata pentru fluier: primeste suflul la sfarsit, pe toata lungimea deodata
fluteEnvTrack = fluteToneL = fluteToneR = np.zeros(0)


def start(bpm, bars, seed):
    global BPM, BEAT, BAR, BARS, LOOP_SECONDS, TOTAL, rng, mixL, mixR, fluteEnvTrack, fluteToneL, fluteToneR
    BPM = bpm
    BEAT = 60.0 / BPM
    BAR = 4 * BEAT
    BARS = bars
    LOOP_SECONDS = BARS * BAR
    rng = np.random.default_rng(seed)
    TOTAL = int((LOOP_SECONDS + TAIL_SECONDS) * SR)
    mixL = np.zeros(TOTAL)
    mixR = np.zeros(TOTAL)
    fluteEnvTrack = np.zeros(TOTAL)
    fluteToneL = np.zeros(TOTAL)
    fluteToneR = np.zeros(TOTAL)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def place(sig, start_s, gain, pan):
    """Pune un sunet mono in mix, cu panoramare de putere constanta (pan -1 stanga .. 1 dreapta)."""
    i = int(start_s * SR)
    if i >= TOTAL:
        return
    if i < 0:
        # umanizarea poate muta prima nota putin inaintea inceputului: se taie doar atacul ei
        sig = sig[-i:]
        i = 0
    sig = sig[: TOTAL - i]
    a = (pan + 1) * np.pi / 4
    mixL[i : i + len(sig)] += sig * gain * np.cos(a)
    mixR[i : i + len(sig)] += sig * gain * np.sin(a)


def human(sec=0.006):
    return rng.uniform(-sec, sec)


def band_noise(n, lo, hi, seed):
    r = np.random.default_rng(seed)
    x = r.standard_normal(n)
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    spec *= (f >= lo) & (f <= hi)
    y = np.fft.irfft(spec, n)
    return y / (np.max(np.abs(y)) + 1e-9)


# ---- instrumentele --------------------------------------------------------------------------------


def pluck(freq, dur, bright=0.97, harmonics=18, decay_base=1.0, decay_slope=0.38):
    """Coarda ciupita: armonice cu stingere tot mai rapida spre agut, usor inarmonice (ca o coarda
    reala), un clic scurt de atac. `bright` < 1 inchide sunetul (bas, lauta moale)."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    inharm = 0.00011
    for k in range(1, harmonics + 1):
        fk = k * freq * np.sqrt(1 + inharm * k * k)
        if fk > 16000:
            break
        amp = (bright ** (k - 1)) / (k**0.85)
        # armonica a doua si a treia putin mai tari: corpul de lemn al lautei
        if k in (2, 3):
            amp *= 1.25
        out += amp * np.exp(-(decay_base + decay_slope * k) * t) * np.sin(
            2 * np.pi * fk * t + rng.uniform(0, 2 * np.pi)
        )
    a = max(1, int(0.003 * SR))
    out[:a] *= np.linspace(0, 1, a)
    click = band_noise(int(0.012 * SR), 2000, 9000, int(freq * 7) % 100000)
    click *= np.exp(-np.arange(len(click)) / (0.002 * SR)) * 0.22
    out[: len(click)] += click
    r = max(1, int(0.05 * SR))
    out[-r:] *= np.linspace(1, 0, r)
    return out / (np.max(np.abs(out)) + 1e-9)


def kalimba(freq, dur=1.6):
    """Lamela de metal ciupita: fundamentala + un partial inarmonic (~2.76x) care se stinge repede.
    Picaturi pe apa, in partile linistite."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.sin(2 * np.pi * freq * t) * np.exp(-2.6 * t)
    out += 0.28 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-9.0 * t)
    out += 0.08 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-16.0 * t)
    a = max(1, int(0.002 * SR))
    out[:a] *= np.linspace(0, 1, a)
    r = max(1, int(0.08 * SR))
    out[-r:] *= np.linspace(1, 0, r)
    return out / (np.max(np.abs(out)) + 1e-9)


def flute_note(midi, start_s, beats, gain, pan):
    """Fluier de lemn: sinus cu doua armonice slabe, vibrato care intra dupa un sfert de secunda,
    atac moale. Suflul se adauga la sfarsit (fluteEnvTrack), din acelasi plic."""
    freq = hz(midi)
    dur = beats * BEAT
    n = int((dur + 0.18) * SR)
    t = np.arange(n) / SR
    depth = 0.0045 * np.clip((t - 0.22) / 0.35, 0, 1)
    inst = freq * (1 + depth * np.sin(2 * np.pi * 5.3 * t + rng.uniform(0, 6.28)))
    phase = 2 * np.pi * np.cumsum(inst) / SR
    tone = (
        np.sin(phase)
        + 0.22 * np.sin(2 * phase)
        + 0.08 * np.sin(3 * phase)
        + 0.03 * np.sin(4 * phase)
        + 0.012 * np.sin(5 * phase)
    )
    env = np.ones(n)
    a = int(0.07 * SR)
    env[:a] = np.linspace(0, 1, a) ** 1.5
    rel_start = int(dur * SR)
    rel = n - rel_start
    env[rel_start:] = np.linspace(1, 0, rel) ** 1.3
    # o respiratie usoara in interiorul notelor lungi: fluierul nu e o orga
    env *= 1 - 0.06 * np.sin(np.pi * np.clip(t / max(dur, 0.1), 0, 1))
    sig = tone * env
    i = max(0, int((start_s + human(0.01)) * SR))
    if i >= TOTAL:
        return
    m = min(n, TOTAL - i)
    ang = (pan + 1) * np.pi / 4
    fluteToneL[i : i + m] += sig[:m] * gain * np.cos(ang)
    fluteToneR[i : i + m] += sig[:m] * gain * np.sin(ang)
    fluteEnvTrack[i : i + m] = np.maximum(fluteEnvTrack[i : i + m], env[:m] * gain)


def pad_chord(midis, start_s, bars, gain):
    """Pad moale: cate doua voci putin dezacordate pe fiecare nota, armonice care cad repede (sunet
    inchis), intrare si iesire lente. Stereo prin dezacordul diferit stanga/dreapta."""
    dur = bars * BAR
    n = int((dur + 1.2) * SR)
    t = np.arange(n) / SR
    left = np.zeros(n)
    right = np.zeros(n)
    for m in midis:
        f = hz(m)
        for side, cents in ((left, -5), (right, 5)):
            fd = f * 2 ** (cents / 1200)
            for k in range(1, 6):
                side += (1 / k**2.2) * np.sin(2 * np.pi * fd * k * t + rng.uniform(0, 6.28))
    env = np.ones(n)
    a = int(0.9 * SR)
    env[:a] = np.linspace(0, 1, a)
    rel_start = int(dur * SR)
    env[rel_start:] = np.linspace(1, 0, n - rel_start)
    norm = max(np.max(np.abs(left)), np.max(np.abs(right))) + 1e-9
    i = int(start_s * SR)
    mlen = min(n, TOTAL - i)
    mixL[i : i + mlen] += (left * env / norm)[:mlen] * gain
    mixR[i : i + mlen] += (right * env / norm)[:mlen] * gain


def shaker_hit(accent):
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    x = band_noise(n, 4000, 13000, int(rng.integers(0, 10**6)))
    env = np.minimum(t / 0.006, 1) * np.exp(-t / 0.028)
    return x * env * accent


def woodblock():
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * 980 * t) * np.exp(-t * 42) + 0.45 * np.sin(2 * np.pi * 2350 * t) * np.exp(-t * 70)
    return s / (np.max(np.abs(s)) + 1e-9)


def frame_drum():
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    f = 62 + 26 * np.exp(-t * 18)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6.5)
    skin = band_noise(n, 90, 900, 77) * np.exp(-t * 40) * 0.25
    s = body + skin
    return s / (np.max(np.abs(s)) + 1e-9)


# ---- armonia si melodiile -------------------------------------------------------------------------

# acord -> (bas, bas2, trei note la mijloc), MIDI; totul sub melodie (fluierul canta intre 62 si 81)
CHORD = {
    "D": (50, 45, (54, 57, 62)),
    "A": (45, 52, (52, 57, 61)),
    "Bm": (47, 54, (54, 59, 62)),
    "G": (43, 50, (55, 59, 62)),
    "Em": (52, 47, (55, 59, 64)),
}
PAD = {
    "D": (62, 66, 69),
    "A": (61, 64, 69),
    "Bm": (62, 66, 71),
    "G": (59, 62, 67),
    "Em": (59, 64, 67),
}
KAL_TOP = {"D": (74, 78, 81), "A": (73, 76, 81), "Bm": (74, 78, 83), "G": (74, 79, 83), "Em": (76, 79, 83)}
# [D61] balciul e in Sol major: mai trebuie Do si La minor
CHORD["C"] = (48, 43, (55, 60, 64))
CHORD["Am"] = (45, 52, (57, 60, 64))
PAD["C"] = (60, 64, 67)
PAD["Am"] = (60, 64, 69)
KAL_TOP["C"] = (72, 76, 79)
KAL_TOP["Am"] = (72, 76, 81)

PROG_A = ["D", "A", "Bm", "G", "D", "G", "A", "D"]
PROG_B = ["G", "D", "Em", "Bm", "G", "D", "Em", "A"]
PROG_C = ["Bm", "G", "D", "A", "Bm", "G", "Em", "A"]

# (nota MIDI sau None pentru pauza, durata in batai); fiecare masura are exact 4 batai
MEL_A = [
    (66, 1), (69, 1), (74, 1.5), (76, 0.5),
    (73, 1), (71, 0.5), (69, 0.5), (64, 2),
    (66, 1), (71, 1), (74, 1), (73, 1),
    (71, 1.5), (69, 0.5), (67, 2),
    (66, 1), (69, 1), (74, 1), (78, 1),
    (76, 1), (74, 0.5), (71, 0.5), (67, 2),
    (69, 1), (73, 1), (76, 1), (74, 0.5), (73, 0.5),
    (74, 3), (None, 1),
]
MEL_A2 = [
    (69, 0.5), (66, 0.5), (69, 1), (74, 1.5), (76, 0.5),
    (76, 1), (73, 0.5), (71, 0.5), (69, 2),
    (66, 0.5), (69, 0.5), (71, 1), (74, 1), (78, 1),
    (79, 1.5), (78, 0.5), (74, 2),
    (74, 1), (78, 1), (81, 1.5), (78, 0.5),
    (79, 1), (78, 0.5), (76, 0.5), (74, 2),
    (73, 1), (76, 1), (81, 1), (79, 0.5), (76, 0.5),
    (74, 2), (69, 1), (66, 1),
]
MEL_B = [
    (74, 1), (71, 1), (67, 1), (71, 1),
    (69, 1.5), (66, 0.5), (62, 2),
    (64, 1), (67, 1), (71, 1), (76, 1),
    (74, 1.5), (73, 0.5), (71, 2),
    (67, 1), (71, 1), (74, 1), (79, 1),
    (78, 1), (76, 0.5), (74, 0.5), (69, 2),
    (71, 1), (76, 1), (79, 1), (78, 0.5), (76, 0.5),
    (73, 2), (76, 1), (69, 1),
]

# [D61] Balciul: un dans de seara in Sol major, cu ritm punctat -- vesel, dar tot din lemn, ca raul.
PROG_F1 = ["G", "C", "G", "D", "G", "C", "D", "G"]
PROG_F2 = ["Em", "C", "G", "D", "Em", "Am", "D", "D"]
MEL_F1 = [
    (67, 0.5), (71, 0.5), (74, 1), (71, 0.5), (74, 0.5), (79, 1),
    (76, 1), (72, 0.5), (76, 0.5), (79, 1), (76, 1),
    (74, 0.5), (71, 0.5), (67, 1), (71, 0.5), (74, 0.5), (71, 1),
    (69, 1), (66, 0.5), (69, 0.5), (74, 2),
    (67, 0.5), (71, 0.5), (74, 1), (79, 1), (78, 0.5), (76, 0.5),
    (76, 1), (79, 0.5), (76, 0.5), (72, 1), (76, 1),
    (74, 1), (72, 0.5), (71, 0.5), (69, 1), (66, 1),
    (67, 3), (None, 1),
]
MEL_F2 = [
    (71, 1), (74, 0.5), (76, 0.5), (79, 1), (76, 1),
    (79, 0.5), (76, 0.5), (72, 1), (76, 1), (72, 1),
    (74, 1), (71, 0.5), (74, 0.5), (79, 1.5), (78, 0.5),
    (76, 1), (74, 1), (69, 2),
    (71, 0.5), (74, 0.5), (76, 1), (79, 0.5), (81, 0.5), (79, 1),
    (76, 1), (72, 0.5), (76, 0.5), (81, 1), (76, 1),
    (78, 1), (74, 0.5), (72, 0.5), (69, 1), (66, 1),
    (69, 1), (74, 1), (78, 1), (81, 1),
]

for name, mel in (("A", MEL_A), ("A2", MEL_A2), ("B", MEL_B), ("F1", MEL_F1), ("F2", MEL_F2)):
    total = sum(d for _, d in mel)
    assert abs(total - 32) < 1e-9, f"melodia {name} are {total} batai, nu 32"


# ---- aranjamentul ---------------------------------------------------------------------------------


def lute_bar(chord, bar_start, vel, sparse=False):
    bass, bass2, mids = CHORD[chord]
    m1, m2, m3 = mids
    if sparse:
        pattern = [(0, bass, 2.4), (1, m2, 1.8), (2, bass2, 2.2), (3, m3, 1.8)]
        step = BEAT
    else:
        seq = [bass, m2, m3, m1, bass2, m2, m3, m2]
        pattern = [(i, note, 2.2 if i in (0, 4) else 1.5) for i, note in enumerate(seq)]
        step = BEAT / 2
    for i, note, ring in pattern:
        is_bass = note in (bass, bass2)
        accent = 1.0 if i in (0, 4) else 0.78
        sig = pluck(hz(note), ring, bright=0.86 if is_bass else 0.95)
        place(sig, bar_start + i * step + human(), vel * accent * rng.uniform(0.9, 1.0), -0.25)


def bass_bar(chord, bar_start, vel, whole=False):
    bass, bass2, _ = CHORD[chord]
    low = bass - 12 if bass >= 45 else bass
    if whole:
        place(pluck(hz(low), BAR * 1.1, bright=0.6, harmonics=6, decay_base=0.8, decay_slope=1.4), bar_start, vel, 0)
        return
    place(pluck(hz(low), 1.6, bright=0.6, harmonics=6, decay_base=0.9, decay_slope=1.6), bar_start + human(), vel, 0)
    fifth = low + 7
    place(pluck(hz(fifth), 1.2, bright=0.6, harmonics=6, decay_base=1.2, decay_slope=1.8), bar_start + 2.5 * BEAT + human(), vel * 0.7, 0)


def melody(mel, section_start, gain):
    t = section_start
    for note, beats in mel:
        if note is not None:
            flute_note(note, t, beats, gain, 0.2)
        t += beats * BEAT


def kalimba_bar(chord, bar_start, gain, busy=False):
    top = KAL_TOP[chord]
    hits = [(0, top[0]), (2, top[1])] if not busy else [(0, top[0]), (1.5, top[2]), (3, top[1])]
    for beat, note in hits:
        place(kalimba(hz(note)), bar_start + beat * BEAT + human(0.01), gain * rng.uniform(0.8, 1.0), 0.45)


def percussion_bar(bar_start, shaker=0.0, block=0.0, drum=0.0):
    if shaker > 0:
        for i in range(8):
            accent = 1.0 if i % 2 == 1 else 0.55
            place(shaker_hit(accent), bar_start + i * BEAT / 2 + human(0.004), shaker, 0.55)
    if block > 0:
        for beat in (1, 3):
            place(woodblock(), bar_start + beat * BEAT + human(0.004), block, -0.5)
    if drum > 0:
        place(frame_drum(), bar_start + human(0.003), drum, 0)


def section(prog, first_bar, lute=0.0, sparse=False, pad=0.0, bass=0.0, bass_whole=False,
            kal=0.0, kal_busy=False, shaker=0.0, block=0.0, drum=0.0, mel=None, mel_gain=0.0):
    start = first_bar * BAR
    for i, chord in enumerate(prog):
        bar_start = start + i * BAR
        if lute > 0:
            lute_bar(chord, bar_start, lute, sparse)
        if bass > 0:
            bass_bar(chord, bar_start, bass, bass_whole)
        if kal > 0:
            kalimba_bar(chord, bar_start, kal, kal_busy)
        percussion_bar(bar_start, shaker, block, drum)
    if pad > 0:
        # acordurile padului, doua cate doua masuri cand se repeta, altfel masura cu masura
        for i, chord in enumerate(prog):
            pad_chord(PAD[chord], start + i * BAR, 1, pad)
    if mel is not None:
        melody(mel, start, mel_gain)


def river():
    """Raul [D51]: Re major, 84 BPM, 48 de masuri."""
    section(PROG_A, 0, lute=0.34, pad=0.065, kal=0.15)
    section(PROG_A, 8, lute=0.36, pad=0.065, bass=0.28, mel=MEL_A, mel_gain=0.20)
    section(PROG_B, 16, lute=0.34, pad=0.07, bass=0.28, shaker=0.08, block=0.05, mel=MEL_B, mel_gain=0.20)
    section(PROG_A, 24, lute=0.36, pad=0.065, bass=0.30, shaker=0.085, block=0.055, drum=0.16, mel=MEL_A2, mel_gain=0.21)
    section(PROG_C, 32, lute=0.30, sparse=True, pad=0.09, bass=0.2, bass_whole=True, kal=0.19, kal_busy=True)
    section(PROG_A, 40, lute=0.36, pad=0.065, bass=0.28, shaker=0.08, block=0.05, mel=MEL_A, mel_gain=0.20)

def dance_bar(bar_start, drum, shaker, block):
    """Toba pe unu si trei (si o atingere pe "si"-ul lui patru), shakerul pe optimi, toaca pe doi si patru."""
    for beat, gain in ((0, 1.0), (2, 0.8), (3.5, 0.45)):
        place(frame_drum(), bar_start + beat * BEAT + human(0.003), drum * gain, 0)
    for i in range(8):
        accent = 1.0 if i % 2 == 1 else 0.6
        place(shaker_hit(accent), bar_start + i * BEAT / 2 + human(0.004), shaker, 0.55)
    for beat in (1, 3):
        place(woodblock(), bar_start + beat * BEAT + human(0.004), block, -0.5)


def fair():
    """Balciul [D61]: Sol major, 108 BPM, 32 de masuri (~71 s). Lauta ciupita des, bas, toba de dans, fluierul cu
    melodia; kalimba doar in partea a doua, ca lumina ghirlandelor. Fara apa: aici se aude lumea, nu raul."""
    section(PROG_F1, 0, lute=0.36, bass=0.30, pad=0.04, mel=MEL_F1, mel_gain=0.21)
    section(PROG_F2, 8, lute=0.34, bass=0.30, pad=0.05, kal=0.11, kal_busy=True, mel=MEL_F2, mel_gain=0.21)
    section(PROG_F1, 16, lute=0.38, bass=0.32, pad=0.04, mel=MEL_F1, mel_gain=0.22)
    section(PROG_F2, 24, lute=0.36, bass=0.32, pad=0.05, kal=0.12, kal_busy=True, mel=MEL_F2, mel_gain=0.22)
    for bar in range(BARS):
        loud = bar >= 16
        dance_bar(bar * BAR, 0.20 if loud else 0.16, 0.10 if loud else 0.08, 0.06 if loud else 0.05)


# ---- suflul fluierului, apa, reverbul, bucla ------------------------------------------------------


def reverb_ir(seed, seconds=2.3):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    bright = band_noise(n, 1200, 10000, seed) * np.exp(-t * 4.2)
    dark = band_noise(n, 80, 1200, seed + 1) * np.exp(-t * 2.8)
    ir = bright * 0.8 + dark
    pre = int(0.022 * SR)
    ir = np.concatenate([np.zeros(pre), ir])
    return ir / np.sqrt(np.sum(ir**2))


def convolve(sig, ir):
    n = len(sig) + len(ir) - 1
    size = 1 << (n - 1).bit_length()
    out = np.fft.irfft(np.fft.rfft(sig, size) * np.fft.rfft(ir, size), size)
    return out[: len(sig)]


# Egalizarea finala, in FFT (bucla e periodica, deci FFT-ul nu taie nimic): fara ea mixul iesea
# cu 15-20 dB mai intunecat decat o inregistrare acustica -- masurat pe benzi, "ca prin perete".
# Putin mai putin sub 150 Hz (padul si basul se adunau acolo), aer de la 1.5 kHz in sus.
def tilt(sig):
    spec = np.fft.rfft(sig)
    f = np.fft.rfftfreq(len(sig), 1 / SR)
    db = np.interp(f, [0, 150, 300, 1500, 5000, 22050], [-3.0, -3.0, 0.0, 0.0, 9.0, 9.0])
    return np.fft.irfft(spec * 10 ** (db / 20), len(sig))


def finish(water=True):
    """Suflul fluierului, apa (doar la rau), reverbul, bucla fara cusatura, egalizarea si varful la -3 dBFS."""
    breath = band_noise(TOTAL, 1800, 7500, 4242) * 0.065
    left = mixL + (fluteToneL + breath * fluteEnvTrack * 0.8)
    right = mixR + (fluteToneR + breath * fluteEnvTrack)
    loop_n = int(LOOP_SECONDS * SR)

    if water:
        # Apa: zgomot "brun" (acumulat) intre 60 si 900 Hz, care creste si scade incet. Facuta cu 3 s mai
        # lunga si cu capetele suprapuse, ca sa nu se auda unde incepe bucla.
        xfade = int(3.0 * SR)
        water_n = loop_n + xfade
        wave_ = band_noise(water_n, 60, 900, 99) + 0.35 * band_noise(water_n, 900, 2600, 98)
        tt = np.arange(water_n) / SR
        swell = 0.65 + 0.2 * np.sin(2 * np.pi * tt / 11.0) + 0.15 * np.sin(2 * np.pi * tt / 4.3 + 1.1)
        wave_ *= swell
        ramp = np.linspace(0, 1, xfade)
        wave_[:xfade] = wave_[:xfade] * ramp + wave_[loop_n:] * (1 - ramp)
        wave_ = wave_[:loop_n]
        wave_ /= np.max(np.abs(wave_)) + 1e-9
        left[:loop_n] += wave_ * 0.035
        right[:loop_n] += np.roll(wave_, int(0.013 * SR)) * 0.035

    wetL = convolve(left, reverb_ir(11))
    wetR = convolve(right, reverb_ir(23))
    outL = left * 0.82 + wetL * 0.34
    outR = right * 0.82 + wetR * 0.34

    # bucla: ce suna dupa ultima masura se aduna peste inceput
    tail = TOTAL - loop_n
    outL[:tail] += outL[loop_n:]
    outR[:tail] += outR[loop_n:]
    outL = outL[:loop_n]
    outR = outR[:loop_n]

    outL, outR = tilt(outL), tilt(outR)

    # stapanire blanda a varfurilor, apoi varful la -3 dBFS
    peak = max(np.max(np.abs(outL)), np.max(np.abs(outR)))
    outL, outR = outL / peak * 0.9, outR / peak * 0.9
    outL, outR = np.tanh(outL * 1.25) / np.tanh(1.25), np.tanh(outR * 1.25) / np.tanh(1.25)
    peak = max(np.max(np.abs(outL)), np.max(np.abs(outR)))
    target = 10 ** (-3 / 20)
    return outL / peak * target, outR / peak * target


def write_wav(path, left, right):
    pcm = np.empty((len(left), 2), dtype=np.int16)
    pcm[:, 0] = np.clip(left, -1, 1) * 32767
    pcm[:, 1] = np.clip(right, -1, 1) * 32767
    with wave.open(path, "wb") as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())


PIECES = {
    # nume: (BPM, masuri, samanta, compunerea, apa)
    "river": (84, 48, 20260913, river, True),
    "fair": (108, 32, 20260917, fair, False),
}


def render(name):
    bpm, bars, seed, compose, water = PIECES[name]
    start(bpm, bars, seed)
    compose()
    return finish(water)


def main():
    args = sys.argv[1:]
    name = args[0] if args and args[0] in PIECES else "river"
    preview = next((a for a in args if a.endswith(".mp3")), None)
    left, right = render(name)
    out = os.path.join(AUDIO_DIR, f"music_{name}.ogg")
    fd, wav_path = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    try:
        write_wav(wav_path, left, right)
        os.makedirs(AUDIO_DIR, exist_ok=True)
        subprocess.run([OGGENC, "-Q", "-q", "5", "-o", out, wav_path], check=True)
        if preview:
            subprocess.run([LAME, "--silent", "-V", "2", wav_path, preview], check=True)
    finally:
        os.remove(wav_path)
    rms = np.sqrt(np.mean(np.concatenate([left, right]) ** 2))
    seam = abs(left[-1] - left[0]) + abs(right[-1] - right[0])
    print(f"  music_{name}  {LOOP_SECONDS:6.1f}s  rms {20 * np.log10(rms):5.1f} dBFS  "
          f"salt la cusatura {seam:.4f}  -> {out}")
    if preview:
        print(f"  mostra: {preview}")


if __name__ == "__main__":
    main()
