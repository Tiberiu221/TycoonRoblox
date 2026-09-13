#!/usr/bin/env python3
"""Sintetizeaza cele 8 efecte sonore [F1 spec 5.6, O1] cu numpy, apoi converteste WAV -> OGG
Vorbis cu oggenc. Muzical si moale -- un joc de rau pentru copii, nu blipuri de arcade. 44.1 kHz
mono, 0.1-2.5 s, varf <= -3 dBFS, fade de 5 ms la capete ca sa nu pocneasca nimic la taiere.

DE CE oggenc SI NU ffmpeg: spec-ul cere "ffmpeg, apoi OGG Vorbis", dar encoder-ul vorbis nativ din
build-ul de ffmpeg de pe masina asta accepta DOAR 2 canale ("Current FFmpeg Vorbis encoder only
supports 2 channels") -- l-ar fi scos stereo, nu mono. `brew install vorbis-tools` aduce oggenc,
encoder-ul de referinta Xiph, care scrie mono direct; ffmpeg n-a mai fost nevoie pentru pasul asta.

Fara scipy: filtrarea de banda foloseste doar np.fft (zerorizeaza bin-ii din afara benzii).

Folosire: python3 scripts/audio/make_sounds.py [cheie ...]   (fara argumente = toate 8)
Scrie in assets/audio/sfx_<cheie>.ogg -- exact ce citeste scripts/upload_assets.py --audio, care
pune ID-ul in Assets.sounds.<cheie> DUPA ce owner-ul asculta si urca (nu se urca de aici).
"""
import os
import shutil
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "audio")
OGGENC = shutil.which("oggenc") or "/opt/homebrew/bin/oggenc"

# ---- unelte mici, refolosite de toate sunetele -------------------------------------------------


def t_axis(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def sine(freq, dur, phase=0.0):
    return np.sin(2 * np.pi * freq * t_axis(dur) + phase)


def exp_decay(dur, tau):
    """Plic exponential: 1 la t=0, scade spre 0. tau mic = stins repede (percutie), mare = suna lung."""
    return np.exp(-t_axis(dur) / tau)


def fade_edges(sig, ms=5):
    """5 ms in/out -- fara asta orice sunet taiat brusc pocneste la capete [spec 5.6]."""
    n = max(1, int(SR * ms / 1000))
    n = min(n, len(sig) // 2)
    ramp = np.linspace(0, 1, n)
    sig = sig.copy()
    sig[:n] *= ramp
    sig[-n:] *= ramp[::-1]
    return sig


def normalize(sig, peak_dbfs=-3.0):
    """Aduce varful exact la peak_dbfs (satisface "varf <= -3 dBFS")."""
    peak = np.max(np.abs(sig))
    if peak < 1e-9:
        return sig
    target = 10 ** (peak_dbfs / 20)
    return sig * (target / peak)


def band_noise(dur, lo, hi, seed):
    """Zgomot alb trecut prin FFT ca sa ramana doar banda [lo, hi] Hz -- fara scipy, doar numpy."""
    rng = np.random.default_rng(seed)
    n = int(SR * dur)
    noise = rng.uniform(-1, 1, n)
    spec = np.fft.rfft(noise)
    freqs = np.fft.rfftfreq(n, 1 / SR)
    spec = spec * ((freqs >= lo) & (freqs <= hi))
    return np.fft.irfft(spec, n)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def write_wav(path, sig):
    pcm = np.clip(sig, -1, 1)
    pcm = (pcm * 32767).astype(np.int16)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())


def to_ogg(wav_path, ogg_path):
    # -q 5: calitate buna pentru sunete scurte, fara sa umfle inutil niste fisiere de <2.5s.
    subprocess.run(
        [OGGENC, "-Q", "-q", "5", "-o", ogg_path, wav_path],
        check=True,
    )


# ---- cele 8 sunete [Assets.sounds] --------------------------------------------------------------


def make_splash():
    # catch -> stropit (throttled in SoundController): zgomot mediu-inalt care se stinge repede,
    # plus o "picatura" a carei frecventa aluneca in jos -- ca o bucata mica cazand in apa
    dur = 0.28
    body = band_noise(dur, 800, 4500, seed=1) * exp_decay(dur, 0.05)
    plip_dur = 0.12
    tt = t_axis(plip_dur)
    drop = np.sin(2 * np.pi * (700 - 2200 * tt) * tt) * exp_decay(plip_dur, 0.025)
    return fade_edges(normalize(mix(body * 0.7, drop * 0.5)))


def make_coin():
    # Sold/HandDelivered -> coin: ding luminos, doua note simultane (cvinta), scurt si moale
    dur = 0.28
    a = sine(1568, dur) * exp_decay(dur, 0.09)  # G6
    b = sine(2349, dur) * exp_decay(dur, 0.07)  # D7
    return fade_edges(normalize(mix(a * 0.6, b * 0.4)))


def make_build():
    # PadBought -> build: "thunk" de lemn -- bataie joasa + zgomot filtrat jos
    dur = 0.22
    thud = sine(110, dur) * exp_decay(dur, 0.05)
    knock = band_noise(dur, 100, 900, seed=2) * exp_decay(dur, 0.035)
    return fade_edges(normalize(mix(thud * 0.8, knock * 0.5)))


def make_register():
    # Sold/HandDelivered -> register: doua tonuri ascendente, ca o casa de marcat cantata
    n1, n2 = 0.16, 0.24
    first = sine(1046, n1) * exp_decay(n1, 0.06)  # C6
    second = sine(1568, n2) * exp_decay(n2, 0.09)  # G6
    sig = np.concatenate([first * 0.7, np.zeros(int(SR * 0.02)), second * 0.7])
    return fade_edges(normalize(sig))


def make_chime():
    # named catch -> chime: arpegiu pentatonic in urcare, ca un glockenspiel -- pitch-ul pe tier
    # se aplica in joc (SoundController.Play cu pitch); fisierul e baza (tier comun)
    notes = [880, 1046, 1318, 1760]  # A5 C6 E6 A6
    dur_each = 0.16
    gap = 0.05
    sig = np.zeros(int(SR * (len(notes) * gap + dur_each + 0.3)))
    for i, f in enumerate(notes):
        d = dur_each + 0.1
        tone = sine(f, d) * exp_decay(d, 0.18)
        overtone = sine(f * 2, d) * exp_decay(d, 0.1) * 0.25
        part = (tone + overtone) * (0.55 - i * 0.05)
        start = int(SR * i * gap)
        sig[start : start + len(part)] += part
    return fade_edges(normalize(sig))


def make_bell():
    # landing_bell -> bell: fundamentala + doua armonice usor dezacordate (bataie naturala de
    # clopot real), plic lung -- cel mai mare sunet, pentru ceremonia de 3s
    dur = 2.0
    fundamental = sine(392, dur) * exp_decay(dur, 0.7)  # G4
    partial2 = sine(392 * 2.01, dur) * exp_decay(dur, 0.55) * 0.5
    partial3 = sine(392 * 2.99, dur) * exp_decay(dur, 0.4) * 0.3
    strike = band_noise(0.05, 400, 6000, seed=3) * exp_decay(0.05, 0.015)
    sig = mix(fundamental, partial2, partial3)
    sig[: len(strike)] += strike * 0.6
    return fade_edges(normalize(sig))


def make_click():
    # menu buttons -> click: tic scurt de interfata, aproape neutru
    dur = 0.11
    sig = band_noise(dur, 1500, 7000, seed=4) * exp_decay(dur, 0.02)
    return fade_edges(normalize(sig), ms=3)


def make_pop():
    # pops (contorul care sare, traista plina) -> pop: sinusoida care aluneca repede in sus
    dur = 0.14
    tt = t_axis(dur)
    freq = 500 + 900 * (tt / dur)
    sig = np.sin(2 * np.pi * np.cumsum(freq) / SR) * exp_decay(dur, 0.045)
    return fade_edges(normalize(sig))


def make_wheel():
    # SpinWheel -> wheel: clichetul rotii, care se RARESTE. Ticurile stau la intervale ce cresc
    # geometric, deci urechea aude roata incetinind chiar daca animatia inca se invarte; un tren
    # de ticuri egale ar fi sunat a masina de scris [D43: nimic nu se intampla in tacere].
    dur = 1.9
    out = np.zeros(int(SR * dur))
    t, gap = 0.0, 0.045
    while t < dur - 0.05:
        tick_dur = 0.035
        tick = band_noise(tick_dur, 1200, 6000, seed=7 + int(t * 1000) % 97)
        tick = tick * exp_decay(tick_dur, 0.006)
        tick = tick + sine(880, tick_dur) * exp_decay(tick_dur, 0.008) * 0.4
        start = int(t * SR)
        n = min(len(tick), len(out) - start)
        out[start : start + n] += tick[:n] * (1.0 - 0.45 * (t / dur))
        t += gap
        gap *= 1.075
    return fade_edges(normalize(out))


def make_saw():
    # gaterul taie [D48] -> saw: bazait scurt de panza. Zgomotul trecut prin banda medie e "lemnul",
    # modulatia de amplitudine la ~38 Hz sunt dintii care trec prin el, iar tonul care coboara usor
    # e panza care incetineste sub sarcina. Scurt (0.55 s): se aude la cel mult 1.2 s o data.
    dur = 0.55
    tt = t_axis(dur)
    body = band_noise(dur, 900, 5200, seed=11)
    teeth = 0.55 + 0.45 * np.sin(2 * np.pi * 38 * tt) ** 2
    hum = np.sin(2 * np.pi * np.cumsum(340 - 60 * (tt / dur)) / SR)
    env = np.minimum(1.0, tt / 0.04) * exp_decay(dur, 0.32)
    return fade_edges(normalize(mix(body * teeth * 0.75, hum * 0.35) * env))


SOUNDS = {
    "splash": make_splash,
    "saw": make_saw,
    "wheel": make_wheel,
    "coin": make_coin,
    "build": make_build,
    "register": make_register,
    "chime": make_chime,
    "bell": make_bell,
    "click": make_click,
    "pop": make_pop,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    keys = sys.argv[1:] or list(SOUNDS.keys())
    for key in keys:
        if key not in SOUNDS:
            print(f"  ! cheie necunoscuta: {key} (una din {', '.join(SOUNDS)})")
            continue
        sig = SOUNDS[key]()
        ogg_path = os.path.join(OUT, f"sfx_{key}.ogg")
        fd, wav_path = tempfile.mkstemp(suffix=".wav")
        os.close(fd)
        try:
            write_wav(wav_path, sig)
            to_ogg(wav_path, ogg_path)
        finally:
            os.remove(wav_path)
        dur = len(sig) / SR
        peak_dbfs = 20 * np.log10(max(1e-9, np.max(np.abs(sig))))
        print(f"  sfx_{key:10s} {dur:5.2f}s  peak {peak_dbfs:5.1f} dBFS  -> {ogg_path}")


if __name__ == "__main__":
    main()
