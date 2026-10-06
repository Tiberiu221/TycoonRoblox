#!/usr/bin/env python3
"""Sunetul filmului Barajului [D70, lotul A2]: 17 s de film peste satul adevarat, apoi jocul se reincarca in lumea 2.
Compus si sintetizat aici, de la zero, cu instrumentele satului din make_music.py (lauta, fluierul de lemn, padul,
kalimba, toba de rama, toaca) si cu uneltele din make_sounds.py -- nicio mostra, niciun drept de autor in afara de al
nostru. Trei sunete (si o alternativa de ascultat):

  music_dam_film   EXACT 17,0 s, stereo 44,1 kHz, in Re major, pe fazele filmului (DamMath.FILM):
                     0-2  s  clopotele      un singur dang cald de clopot si un pad tinut
                     2-7  s  uita-te         inceputul temei raului, lent si nostalgic (fluier, lauta rara, kalimba)
                     7-11 s  oamenii         un puls de mers (bas, toba de rama moale, shaker foarte slab), melodia urca
                     11-14 s zidul creste    ritm hotarat (toba, toaca ca niste ciocane), armonia urca: Sol, La, La/Do#
                     14-17 s cartonul        acordul de Re plin, rezolvat, care SUNA (lauta rulata, clopotul Re3, basul) si se
                                             stinge singur; fluierul si padul se termina devreme (~15,2 s), stingerea de siguranta
                                             a masterului e doar de la 16,0 la 17,0 s
  sfx_film_build   2,6 s mono (11,0 -> 13,6 s din film): santierul sub muzica -- dalta pe piatra, tocuri de ciocan de lemn pe
                   grinda, doua pietre puse jos, o franghie care scartaie prin scripete (stick-slip lent). Neregulat, in straturi,
                   mai incet decat muzica la acelasi nivel (varf <= -6 dBFS). Ultima piatra cade la 13,375 s, apoi e liniste pana la
                   13,6 s: cand se intalnesc jumatatile zidului, lucrul amuteste si bufnetul se aude singur.
  sfx_film_close   2,5 s mono (13,6 -> 16,1 s): clipa in care se intalnesc cele doua jumatati ale zidului: un bufnet de piatra cu
                   un scrasnet piatra-pe-piatra deasupra, apoi apa care urca in spatele zidului (pat jos + clipocit + bule),
                   stinsa la zero (varf <= -3 dBFS).
  sfx_film_build_altcreak   (doar de ascultat) acelasi santier cu prima varianta a scartaitului (zumzet de 70-150/s), ca owner-ul
                   sa aleaga dupa ureche; nu e pe lista de urcat.

REVIZUIREA VERIFICATORULUI (2026-10-04), ce s-a schimbat fata de prima varianta:
  * close: apa se aude acum si pe telefon: patul de 35-900 Hz ramane, peste el un clipocit de 500-1100 / 1000-2400 Hz cu modulatie
    neregulata de 3-6 Hz care urmeaza umflarea, plus 26 de bule Minnaert (400-2000 Hz, urca in ton, mai dese cand apa e sus) cu
    ~14 dB sub tot restul (inainte 33). Bufnetul: coboara pana la 55 Hz (nu 36), are corp la 180/310/540/760 Hz si un scrasnet
    de 0,12 s la 800-3000 Hz, taiat sub 40 Hz inainte de normalizare. Nivelul apei = acordul din carton pe 500-1000 Hz (WATER_DB).
  * build: totul sub 90 Hz taiat; pietrele pe corp de ~104-134 Hz + 'toc' tonal 300-900 Hz + granulatie 1-3,5 kHz, cu saturare
    blanda (mai sus pe telefon); tocurile de ciocan sunt altceva decat toaca din muzica (lemn dens de 215-255 Hz + clinchet de
    ~1,5 kHz) si cad la mijloc intre loviturile muzicii (0,125 + k x 0,25 s dupa 11,0 s), ca sa nu se auda dublu; scartaitul
    e acum alunecare-agatare lenta (26-58/s, rezonanta 430-920 Hz, 6-10 ms), nu zumzet.
  * muzica: finalul sta pe acord, nu pe fluier (fluier 1,0 s, pad pana la 15,3 + 1,2 s, bas cu stingere mai lenta); pad-ul de La
    se termina la 14,0 (pad_r), nu se mai amesteca in Re; shaker foarte slab pe grila de 0,5 s la oameni si la zid; gol de ciocane
    la 13,6 s pentru bufnetul inchiderii.
  * previzualizari: film_mix_preview.mp3 (muzica + cele doua efecte, la volumele din joc) si film_mix_default_levels.mp3
    (muzica la 0,096 = nivelul implicit din joc), plus tabelul de masuratori de la sfarsitul rularii.

A DOUA REVIZIE (verificatorul final, 2026-10-04), masurata pe fisierele native (tabelul de la sfarsitul rularii):
  * close: bufnetul era SUB apa (ponderat A, max pe 50 ms: -19,6 fata de -13,5 dBFS). Acum bufnetul trece printr-o saturare blanda (tanh,
    ca la stone_set), partialele de 540 / 760 Hz tin dublu, iar apa coboara (WATER_DB -20,5 -> -21,5, dar pe un bufnet mai plin): bufnetul e
    cu +1,5 dB peste apa (ponderat A), +0,9 (ponderat A + trece-sus 300 Hz) si +2,2 (doar trece-sus 300 Hz, cum o masurase verificatorul).
    Modulatia clipocitului are podea (0,45 + 0,55 x zgomot, minim 0,25; inainte cadea la zero): pe 0,6-1,5 s nivelul pe 100 ms oscileaza
    in ~3 dB (inainte 10,5 dB). Bulele sunt la -9,5 dB sub restul apei (inainte -14).
  * build: dalta +5,4 dB (castig x1,3, nu x0,7); trei dalti care cadeau peste loviturile muzicii au ton mai sus si, doua, castig mai
    mare, ca sa intre in banda 3-8 kHz unde muzica e goala. Varful fisierului ramane pe piatra mare (12,627 s, -6,5 dBFS).
  * muzica: Do#-ul din arpegiile de lauta (12,75 / 13,0 / 13,75 s) nu mai trece de 13,8 si e mai slab (x0,35): Do# fata de Re pe 14,0-14,3 s
    de la -2,3 la -11,5 dB (tinta: cel mult -10). Fluierul: fiecare nota e corectata dupa lantul masterului (reverbul facea dinamica
    melodiei: La4 iesea cu +6,5 dB, Fa#5 cu +3,7); acum fiecare nota sta in +-1,2 dB de castigul scris, singura sau in pista fluierului.
    Doua mici schimbari scrise: La5 de la 10,0 dureaza 0,9 s (nu 1,0), iar Fa#5 de la 14,0 are castig 0,24 (nu 0,205), ca terta acordului sa
    nu ramana slaba dupa corectie.

LEGAREA IN JOC (pentru cine leaga sunetul in DamFilm.luau / SoundController / MusicController):
  1. NU canta music_dam_film prin SoundController.Play: acela pune Debris:AddItem(sound, 4) si ar taia piesa la 4 s. Un Sound al
     lui, pe grupul "Music" (cum face MusicController.PlayCue in arborele de lucru), incarcat dinainte (ContentProvider:
     PreloadAsync pe Assets.soundUrl(Assets.music.dam_film), inainte de startedAt) si pornit pe cadrul lui render(0), ca sa nu
     intarzie fata de imagine. Skip si Stop il stinge in ~0,2 s si il opresc (EndCue are azi CUE_FADE = 0,6 s); Seek pune
     TimePosition = t; PlayCard (cartonul pierdut) il porneste de la TimePosition 14.
  2. DamFilm.render canta azi SoundController.Play("bell") la faza "bells" si "chime" la PlayCard / la carton: sfx_bell e Sol4 (392 Hz)
     peste dangul de Re4 al muzicii, iar chime = La5-Do6-Mi6-La6 pune un Do natural (a saptea mica) pe rezolvarea in Re major.
     Amandoua se scot cand dam_film e urcat (dangul si acordul sunt deja in muzica).
  3. Bucla raului (music_river, 84 BPM) trebuie oprita cat canta cuvertura asta de 60 BPM, altfel canta doua piese deodata: in
     arborele de lucru MusicController.PlayCue o stinge lin (CUE_FADE) si EndCue o readuce; DamFilm trebuie sa treaca mereu pe
     la ele (Play, Skip, sfarsit, Stop, PlayCard).
  4. Momentele efectelor: film_build la 11,0 s (inceputul fazei "build"); film_close la 13,6 s = 14,0 - DamMath.FILM_MEET_BEFORE
     (0,4), adica in clipa in care frame.built ajunge la 1. Nu la 14,0: acolo cad toba, basul Re2 si hum-ul clopotului muzicii.
  5. NIVELURI: SoundController.VOLUME are film_build 0,45 si film_close 0,7, ca la restul efectelor, dar muzica din panou e la
     nivelul 4 din 10 = 0,6 x 0,16 = 0,096, iar efectele la 10 = 1,0. Fata de muzica, efectele ies deci cu +13,4 dB (build) si
     +17,3 dB (close) mai sus decat in film_mix_preview.mp3 (care le pune la 0,45 / 0,7 peste muzica la 1,0). Echilibrul din
     film_mix_preview.mp3 se obtine fie cantand cele doua efecte pe grupul "Music" al cuverturii, la 0,45 / 0,7, fie lasandu-le pe
     "Effects" cu VOLUME de ~0,043 / ~0,067 (0,45 si 0,7 x 0,096); 0,10 / 0,15-0,25 le-ar lasa tot cu +7...+11 dB prea sus.
     film_mix_default_levels.mp3 arata ce s-ar auzi azi, la nivelurile implicite.

Tot filmul se programeaza in SECUNDE ABSOLUTE (nu pe masuri): fazele filmului sunt 2 / 5 / 4 / 3 / 3 secunde, iar o
grila de 0,5 s le prinde pe toate. make_music.start(60, ...) da BEAT = 1 s, deci "batai" = secunde la fluier.
Fara bucla: acordul final se stinge singur, nu se aduna peste inceput (de aceea nu apelam make_music.finish, care
indoaie coada peste inceput).

Folosire: python3 scripts/audio/a2_film.py [music|build|close|altcreak ...] [--out DIR]
Implicit scrie in caietul de lucru al lotului A2 (NU in assets/audio): ce urca scripts/upload_assets.py --audio se
muta de acolo abia dupa acordul owner-ului (sau se ruleaza cu --out assets/audio). Scrie si previzualizarea
sound_preview.png (forma de unda + spectrograma, cu limitele fazelor la 2, 7, 11, 14 s si un panou cu mixul) si MP3-uri de ascultat.
"""
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.dont_write_bytecode = True  # importul make_music / make_sounds nu lasa __pycache__ in repo
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_music as mm  # noqa: E402  (instrumentele muzicii satului)
import make_sounds as ms  # noqa: E402  (uneltele efectelor: WAV mono, to_ogg, band_noise, normalize)

SR = mm.SR
FILM_SECONDS = 17.0
# Fazele filmului, ca in DamMath.FILM (de la, pana la, nume)
PHASES = [(0, 2, "bells"), (2, 7, "look"), (7, 11, "people"), (11, 14, "build"), (14, 17, "card")]
# caietul de lucru al lotului A2 (vezi antetul)
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "art"))
import scratch  # noqa: E402  (folderul de lucru: DRIFTWOOD_SCRATCH sau .scratch/)
DEFAULT_OUT = scratch.folder("a2")
LAME = mm.LAME


# ---- instrumente noi (restul vin din make_music) ------------------------------------------------------


def bell(freq, dur, amp_tilt=1.0):
    """Clopotul Morii: nota loviturii + 'hum'-ul o octava dedesubt + parțiale de clopot (terta MAJORA, ca sa fie cald
    pe un acord de Re major, nu intunecat), doua voci usor dezacordate (batai lente, ca la un clopot adevarat), un
    zgomot scurt de lovitura si o mica scadere de ton dupa lovitura."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    # (raport, amplitudine, constanta de stingere in secunde): sunetele joase dureaza, cele inalte pier repede
    parts = [
        (0.5, 0.55, 2.8), (1.0, 1.0, 2.4), (1.0028, 0.5, 2.1), (1.26, 0.30, 1.5), (1.5, 0.36, 1.6),
        (2.0, 0.55, 1.15), (2.51, 0.16, 0.75), (3.0, 0.20, 0.65), (4.17, 0.08 * amp_tilt, 0.38),
    ]
    out = np.zeros(n)
    settle = 1 + 0.006 * np.exp(-t / 0.05)  # tonul se asaza dupa lovitura
    for ratio, amp, tau in parts:
        phase = 2 * np.pi * np.cumsum(freq * ratio * settle) / SR
        out += amp * np.sin(phase) * np.exp(-t / tau)
    strike = mm.band_noise(int(0.03 * SR), 500, 5200, 31)
    strike = strike * np.exp(-np.arange(len(strike)) / (0.007 * SR)) * 0.30
    out[: len(strike)] += strike
    a = max(1, int(0.004 * SR))
    out[:a] *= np.linspace(0, 1, a)  # fara pocnet la primul esantion
    r = max(1, int(0.12 * SR))
    out[-r:] *= np.linspace(1, 0, r)
    return out / (np.max(np.abs(out)) + 1e-9)


def mallet_wood(freq, tau=0.03):
    """Ciocan de lemn pe lemn, mai plin si mai jos decat toaca din make_music (aceea e 980 Hz): o lovitura care coboara
    putin in ton, un partial inarmonic, un mic clic de atac."""
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    f = freq * (1 + 0.22 * np.exp(-t / 0.012))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / tau)
    over = 0.35 * np.sin(2 * np.pi * freq * 2.7 * t) * np.exp(-t / (tau * 0.35))
    click = mm.band_noise(n, 900, 4200, int(freq)) * np.exp(-t / 0.003) * 0.35
    s = body + over + click
    return s / (np.max(np.abs(s)) + 1e-9)


# ---- muzica -------------------------------------------------------------------------------------------


def lute_note(note, t, ring, vel, bass=False, until=None):
    """O ciupitura de lauta. `until` = clipa (in secunde) la care coarda se opreste, ca o mana pe ea: sunetul nu trece de ea (pluck
    are oricum stingere liniara de 50 ms la capat, deci nu pocneste). [director] Do#-urile din arpegiile de dinaintea acordului de
    Re (12,75 / 13,0 / 13,75 s, ring 1,4 s) treceau de 14,0 si se auzeau sub Re (Do# la -1,8 dB fata de Re pe 14,0-14,3 s): acum
    se opresc la 14,0. Apelurile la mm.human / mm.rng raman aceleasi ca fara `until` (restul piesei iese neschimbat)."""
    if until is not None:
        ring = max(0.06, min(ring, until - t))
    mm.place(mm.pluck(mm.hz(note), ring, bright=0.86 if bass else 0.95), t + mm.human(), vel * mm.rng.uniform(0.9, 1.0), -0.25)


def bass_note(note, t, ring, vel):
    """Basul din make_music (coarda jos, armonice putine, stingere repede)."""
    mm.place(mm.pluck(mm.hz(note), ring, bright=0.6, harmonics=6, decay_base=0.9, decay_slope=1.6), t + mm.human(0.004), vel, 0)


FLUTE_COMP = True  # False = castigurile asa cum sunt scrise (pentru a vedea tabelul "inainte")
FLUTE_LOG = []  # cate o linie pe nota de fluier, pentru tabelul din raport (vezi `flute`)
FLUTE_TRIM = []  # dB pe nota, din trecerea precedenta (vezi make_music): echilibreaza masura izolata cu cea din mix
_NOM = [np.zeros(0), np.zeros(0)]  # pista fluierului la castigurile scrise (necorectate), stanga / dreapta: referinta masuratorilor
_IRS = {}  # raspunsurile de reverb ale masterului (aceleasi doua ca in master_music), calculate o singura data


def master_irs():
    if not _IRS:
        _IRS["L"], _IRS["R"] = mm.reverb_ir(11), mm.reverb_ir(23)
    return _IRS["L"], _IRS["R"]


def master_chain(left, right, wet=True):
    """Lantul masterului muzicii, fara taieturile si stapanirea de la urma: 0,82 uscat + 0,34 reverb (doua raspunsuri diferite, stanga /
    dreapta), apoi egalizarea. Il foloseste master_music si, la fel, masuratorile fluierului (`wet=False` = fara reverb, ca sa se
    vada ce schimba reverbul)."""
    irl, irr = master_irs()
    out_l, out_r = left * 0.82, right * 0.82
    if wet:
        out_l = out_l + mm.convolve(left, irl) * 0.34
        out_r = out_r + mm.convolve(right, irr) * 0.34
    return mm.tilt(out_l), mm.tilt(out_r)


def window_power(left, right, i0, i1):
    """Puterea medie a mixului mono ((L + R) / 2: asa se aude pe un difuzor mic si asa il masoara verificatorul) pe esantioanele [i0, i1)."""
    return np.mean(((left[i0:i1] + right[i0:i1]) / 2) ** 2) + 1e-18


def flute(midi, t, secs, gain):
    """O nota de fluier (mm.flute_note, BEAT = 1 s), cu nivelul CORECTAT dupa lantul masterului. [director] Reverbul (doua raspunsuri de
    zgomot de 2,3 s) nu raspunde la fel la toate inaltimile: o nota tinuta 1 s iesea cu pana la +7 dB (La4) sau -3 dB (Do#5) fata de
    castigul scris, deci reverbul, nu castigurile, facea dinamica melodiei. Aici nota se randeaza SINGURA (pe tablouri temporare; aceleasi
    apeluri la mm.rng ca fara corectie, deci restul piesei nu se schimba), trece prin lant cu si fara reverb, se masoara puterea pe corpul
    notei [t, t + secs] (mixul mono), iar nota se scaleaza cu diferenta: dupa lant ea sta, singura, la nivelul castigului scris (cel
    uscat). `FLUTE_TRIM` mai muta nota cu cateva zecimi de dB, ca si masura din pista intreaga a fluierului (cu cozile notelor vecine)
    sa ramana aproape de castigul scris."""
    real = (mm.fluteToneL, mm.fluteToneR, mm.fluteEnvTrack)
    mm.fluteToneL, mm.fluteToneR, mm.fluteEnvTrack = (np.zeros(mm.TOTAL) for _ in range(3))
    mm.flute_note(midi, t, secs / mm.BEAT, gain, 0.2)  # BEAT = 1 s
    tone_l, tone_r, env = mm.fluteToneL, mm.fluteToneR, mm.fluteEnvTrack
    mm.fluteToneL, mm.fluteToneR, mm.fluteEnvTrack = real
    # felia notei: de la 0,1 s inainte de ea pana la sfarsitul ei + coada reverbului
    a = max(0, int((t - 0.1) * SR))
    b = min(mm.TOTAL, int((t + secs + 0.18 + 2.4) * SR))
    wet_l, wet_r = master_chain(tone_l[a:b], tone_r[a:b])
    dry_l, dry_r = master_chain(tone_l[a:b], tone_r[a:b], wet=False)
    w0, w1 = int(t * SR) - a, int((t + secs) * SR) - a
    dev = 10 * np.log10(window_power(wet_l, wet_r, w0, w1) / window_power(dry_l, dry_r, w0, w1))
    i = len(FLUTE_LOG)
    trim = FLUTE_TRIM[i] if i < len(FLUTE_TRIM) else 0.0
    k = 10 ** ((trim - np.clip(dev, -10, 10)) / 20) if FLUTE_COMP else 1.0
    mm.fluteToneL += tone_l * k
    mm.fluteToneR += tone_r * k
    mm.fluteEnvTrack[:] = np.maximum(mm.fluteEnvTrack, env * k)
    _NOM[0] += tone_l
    _NOM[1] += tone_r
    FLUTE_LOG.append({"t": t, "midi": midi, "secs": secs, "gain": gain, "dev": dev, "trim": trim, "k_db": 20 * np.log10(k)})


def flute_context():
    """Cat de sus sta fiecare nota in pista fluierului ASA CUM E ea in mix (toate notele impreuna, cu cozile reverbului vecinelor), fata
    de aceeasi nota la castigul scris, fara reverb: (wet - dry nominal) in dB, pe [t, t + secs], mixul mono."""
    wl, wr = master_chain(mm.fluteToneL, mm.fluteToneR)
    dl, dr = master_chain(_NOM[0], _NOM[1], wet=False)
    out = []
    for r in FLUTE_LOG:
        i0, i1 = int(r["t"] * SR), int((r["t"] + r["secs"]) * SR)
        out.append(10 * np.log10(window_power(wl, wr, i0, i1) / window_power(dl, dr, i0, i1)))
    return out


def kal(midi, t, gain):
    mm.place(mm.kalimba(mm.hz(midi)), t + mm.human(0.01), gain * mm.rng.uniform(0.85, 1.0), 0.45)


def pad(midis, t0, secs, gain, preroll=0.5):
    """Padul are atac de 0,9 s: il pornim cu o jumatate de secunda inainte, ca sa fie sus pe batai, cand acordul se schimba."""
    start = max(0.0, t0 - preroll)
    mm.pad_chord(midis, start, (secs + (t0 - start)) / mm.BAR, gain)


def pad_r(midis, t0, secs, gain, preroll=0.5, release=1.2):
    """Ca `pad`, dar cu stingerea reglabila (pad_chord din make_music o are fixa la 1,2 s). Acordul ramane sus pana la t0 + secs
    si se stinge liniar in `release` secunde: pentru o schimbare de acord la o bataie anume, ca acordul vechi sa nu se
    mai auda sub cel nou (aceleasi voci, aceleasi faze la intamplare ca la pad_chord)."""
    start = max(0.0, t0 - preroll)
    dur = secs + (t0 - start)
    n = int((dur + release) * SR)
    t = np.arange(n) / SR
    left = np.zeros(n)
    right = np.zeros(n)
    for m in midis:
        f = mm.hz(m)
        for side, cents in ((left, -5), (right, 5)):
            fd = f * 2 ** (cents / 1200)
            for k in range(1, 6):
                side += (1 / k ** 2.2) * np.sin(2 * np.pi * fd * k * t + mm.rng.uniform(0, 6.28))
    env = np.ones(n)
    a = int(0.9 * SR)
    env[:a] = np.linspace(0, 1, a)
    rel_start = int(dur * SR)
    env[rel_start:] = np.linspace(1, 0, n - rel_start)
    norm = max(np.max(np.abs(left)), np.max(np.abs(right))) + 1e-9
    i = int(start * SR)
    m_len = min(n, mm.TOTAL - i)
    mm.mixL[i : i + m_len] += (left * env / norm)[:m_len] * gain
    mm.mixR[i : i + m_len] += (right * env / norm)[:m_len] * gain


def bass_long(note, t, ring, vel):
    """Basul acordului final: aceeasi coarda ca bass_note, dar cu stingere de doua ori mai lenta, ca sa fie printre ultimele
    voci care se aud (impreuna cu clopotul si lauta), nu printre primele care pier."""
    mm.place(mm.pluck(mm.hz(note), ring, bright=0.6, harmonics=6, decay_base=0.45, decay_slope=0.9), t + mm.human(0.004), vel, 0)


def compose_music():
    mm.start(60, 4, 20261003)  # BEAT = 1 s, BAR = 4 s, buffer de 21 s (17 s + coada reverbului)
    FLUTE_LOG.clear()
    _NOM[0], _NOM[1] = np.zeros(mm.TOTAL), np.zeros(mm.TOTAL)
    CH = mm.CHORD  # acord -> (bas, bas2, (m1, m2, m3))

    # ===== 0-2 s, clopotele: un dang, un pad tinut ========================================================
    mm.place(bell(mm.hz(62), 5.0), 0.0, 0.42, -0.1)  # Re4; hum-ul e Re3
    pad(mm.PAD["D"], 0.0, 2.0, 0.080)

    # ===== 2-7 s, "look how far you've come": inceputul temei raului, lent (1 s pe bataie) =================
    # F#4 La4 Re5 Mi5 | Do#5 -- ca prima masura din MEL_A, intinsa, apoi Do#5 ramane in aer (nu se rezolva pana la 7 s)
    flute(66, 2.0, 1.0, 0.165)
    flute(69, 3.0, 1.0, 0.170)
    flute(74, 4.0, 1.5, 0.175)
    flute(76, 5.5, 0.5, 0.170)
    flute(73, 6.0, 1.0, 0.170)
    # acorduri: Re (2-4), Sol (4-6), La (6-7); padul le leaga
    pad(mm.PAD["D"], 2.0, 2.0, 0.068)
    pad(mm.PAD["G"], 4.0, 2.0, 0.068)
    pad(mm.PAD["A"], 6.0, 1.0, 0.068)
    # lauta rara: o ciupitura pe secunda (bas, mijloc, bas2, mijloc sus), ca in A1 al raului
    for (chord, t0, count) in (("D", 2.0, 2), ("G", 4.0, 2), ("A", 6.0, 1)):
        bass, bass2, (m1, m2, m3) = CH[chord]
        seq = [(bass, True, 2.4), (m2, False, 1.8)]
        for i in range(count):
            note, is_bass, ring = seq[i % 2]
            lute_note(note, t0 + i, ring, 0.32 * (1.0 if i == 0 else 0.8), is_bass)
    # picaturi de kalimba, rare
    kal(81, 3.5, 0.11)
    kal(78, 5.0, 0.11)
    kal(73 + 12, 6.5, 0.09)

    # ===== 7-11 s, "everyone lends a hand": puls de mers, melodia urca =====================================
    # Si4 Re5 F#5 La5: arpegiul de Si minor in urcare, o nota pe secunda; sub Sol (9-11) F#5 si La5 sunt maj7 si 9
    flute(71, 7.0, 1.0, 0.180)
    flute(74, 8.0, 1.0, 0.195)
    flute(78, 9.0, 1.0, 0.210)
    flute(81, 10.0, 0.9, 0.225)  # 0,9 s (nu 1,0): coada lui La5 nu se mai aduna peste Re5-ul de la 11,0 (abaterea acelei note din pista fluierului: 1,5 -> 1,2 dB)
    pad(mm.PAD["Bm"], 7.0, 2.0, 0.074)
    pad(mm.PAD["G"], 9.0, 2.0, 0.078)
    # lauta pe optimi (0,5 s): arpegiu usor, doar notele de mijloc; basul merge: radacina pe secunda, cvinta pe jumatate
    for (chord, t0) in (("Bm", 7.0), ("G", 9.0)):
        bass, bass2, (m1, m2, m3) = CH[chord]
        seq = [m1, m2, m3, m2]
        for i in range(4):  # un acord = 2 s = patru optimi
            lute_note(seq[i], t0 + i * 0.5, 1.6, 0.30 * (1.0 if i == 0 else 0.78))
    for (root, fifth, t0) in ((47, 54, 7.0), (47, 54, 8.0), (43, 50, 9.0), (43, 50, 10.0)):
        bass_note(root, t0, 1.4, 0.26)
        bass_note(fifth, t0 + 0.5, 1.0, 0.17)
    # pasii: toba de rama, moale, stanga-dreapta; o atingere de pregatire la 6,5 s
    mm.place(mm.frame_drum(), 6.5 + mm.human(0.003), 0.045, 0)
    for i in range(8):
        t = 7.0 + i * 0.5
        mm.place(mm.frame_drum(), t + mm.human(0.003), 0.125 if i % 2 == 0 else 0.075, 0)
    kal(81, 8.0, 0.10)
    kal(83, 10.0, 0.10)
    # [director] aerul de peste 8 kHz: un shaker foarte moale pe grila de 0,5 s, cu accent pe contratimp, ca in sectiunile raului
    for i in range(8):
        mm.place(mm.shaker_hit(1.0 if i % 2 else 0.55), 7.0 + i * 0.5 + mm.human(0.004), 0.04, 0.55)

    # ===== 11-14 s, "the old village becomes the Dam": ritm hotarat, armonia urca ==========================
    # Re5 Mi5 F#5 Sol5 -> 14.0 F#5: Sol5 e septima lui La7, se rezolva in treapta a treia a lui Re (V7 -> I)
    flute(74, 11.0, 1.0, 0.205)
    flute(76, 12.0, 1.0, 0.215)
    flute(78, 13.0, 0.5, 0.225)
    flute(79, 13.5, 0.5, 0.230)
    pad(mm.PAD["G"], 11.0, 1.0, 0.088)
    # [director] stingerea de 1,2 s a lui pad() tinea La-ul (Do#, Mi) si sub Re-ul de la 14,0: aici stingerea e de 0,4-0,5 s,
    # ca ultimul La sa se termine la 14,0, exact cand intra acordul final
    pad_r(mm.PAD["A"], 12.0, 1.0, 0.094, release=0.4)
    pad_r(mm.PAD["A"], 13.0, 0.5, 0.100, release=0.5)
    # lauta urca pe sfert de secunda: bas, mijloc 1, 2, 3 -- tot mai sus, tot mai tare
    build_arps = {
        11.0: ([43, 55, 59, 62], 0.34),
        12.0: ([45, 52, 57, 61], 0.36),
        13.0: ([49, 52, 57, 61], 0.38),  # La/Do#: baza urca spre Re
    }
    # [director] Do# e sensibila lui Re, dar cu coada de reverb si cu Do#-ul ramas din arpegiu murdarea acordul de la 14,0 (Do# la
    # -1,8 dB fata de Re pe 14,0-14,3 s; tinta: cel mult -10): Do#-urile (12,75 / 13,0 / 13,75 s) sunt mai slabe (x0,35) si coarda
    # lor se opreste la 13,8; restul notelor se opresc la 14,0. Masurat dupa lant: vezi tabelul de la sfarsitul rularii.
    for t0, (notes, vel) in build_arps.items():
        for i, note in enumerate(notes):
            leading = note % 12 == 1
            lute_note(note, t0 + i * 0.25, 1.4, vel * (1.0 if i == 0 else 0.82) * (0.35 if leading else 1.0), bass=(i == 0),
                      until=13.8 if leading else 14.0)
    # basul bate pe jumatati: Sol Sol La La Do# Mi -- se aude cum urca
    for (note, t, v) in ((43, 11.0, 0.30), (43, 11.5, 0.20), (45, 12.0, 0.32), (45, 12.5, 0.22), (49, 13.0, 0.34), (52, 13.5, 0.24)):
        bass_note(note, t, 0.9, v)
    # toba pe jumatati (accent pe secunda), toaca ca niste ciocane pe sferturi, in doua inaltimi
    for i in range(6):
        t = 11.0 + i * 0.5
        mm.place(mm.frame_drum(), t + mm.human(0.003), 0.20 if i % 2 == 0 else 0.14, 0)
    for k in range(3):
        t = 11.0 + k
        mm.place(mm.woodblock(), t + 0.25 + mm.human(0.004), 0.055, -0.5)
        mm.place(mallet_wood(640), t + 0.75 + mm.human(0.004), 0.075, 0.4)
    # ultima jumatate de secunda: ciocane care cresc spre acordul final. [director] Fara lovitura la 13,625: la 13,6 cele
    # doua jumatati ale zidului se intalnesc (DamMath.FILM_MEET_BEFORE = 0,4 inaintea cartonului, sfx_film_close), iar bufnetul
    # acela trebuie sa se auda singur, nu ca un dublu lovit cu ciocanul; ciocanele reiau dupa el, tot mai dese
    for k, t in ((0, 13.5), (2, 13.75), (3, 13.875)):
        mm.place(mallet_wood(700 + 40 * k), t, 0.05 + 0.02 * k, -0.2 + 0.2 * k)
    for i in range(6):  # [director] shaker-ul mai prezent decat la oameni: santierul e mai aglomerat
        mm.place(mm.shaker_hit(1.0 if i % 2 else 0.55), 11.0 + i * 0.5 + mm.human(0.004), 0.06, 0.55)
    # kalimba urca pe optimi: Sol5 La5 Do#6 Mi6 Sol6 (septima lui La7 e Sol)
    for (note, t, g) in ((79, 11.5, 0.13), (81, 12.0, 0.14), (85, 12.5, 0.15), (88, 13.0, 0.16), (91, 13.5, 0.17)):
        kal(note, t, g)

    # ===== 14-17 s, cartonul: acordul de Re plin, rezolvat, care suna si se stinge =========================
    mm.place(bell(mm.hz(50), 6.0, 0.6), 14.0, 0.34, 0.0)  # Re3: dangul de inchidere, mai adanc si mai moale
    # [director] acordul sa SUNE, nu sa fie un fluier tinut si stins: padul si fluierul se termina devreme (padul sus pana la
    # 15,3 + stingere de 1,2 s; fluierul pana la ~15,2), iar ultimele voci care pier sunt clopotul Re3, lauta rulata si basul
    pad((50, 57, 62, 66, 69, 74), 14.0, 1.3, 0.125, preroll=0.1)
    bass_long(38, 14.0, 3.6, 0.36)  # Re2
    bass_long(50, 14.0, 3.2, 0.20)  # Re3
    for k, note in enumerate((50, 57, 62, 66, 69, 74)):  # lauta, acordul cantat in jos-sus, cu intarziere de 35 ms
        lute_note(note, 14.0 + 0.035 * k, 3.4, 0.34 * (0.92 ** k) if k else 0.34, bass=(k < 2))
    lute_note(74, 15.2, 2.4, 0.15)
    lute_note(69, 15.7, 2.2, 0.11)
    mm.place(mm.frame_drum(), 14.0, 0.26, 0)
    # F#5: treapta a treia, nota in care se rezolva Sol5. 1,0 s, ca celelalte note ale frazei: la 1,4 s coada reverbului ei mai
    # tinea F# deasupra lui Re pana pe la 15,8 (chroma), la 1,0 s Re conduce de la 15,5
    flute(78, 14.0, 1.0, 0.24)  # castig mai mare (era 0,205): dupa corectia de nivel nu mai ia +4 dB de la reverb, iar terta acordului sa nu ramana slaba
    for (note, t, g) in ((86, 14.15, 0.14), (81, 14.5, 0.12), (90, 15.0, 0.10), (86, 15.6, 0.07)):
        kal(note, t, g)


def master_music():
    """Suflul fluierului, reverbul, egalizarea (aceleasi ca la piesele satului), apoi taiat la 17,0 s, cu stingere pana la
    zero exact pe ultimul esantion si un fade de intrare de 10 ms. Fara indoirea cozii peste inceput (nu e bucla)."""
    total = mm.TOTAL
    breath = mm.band_noise(total, 1800, 7500, 4242) * 0.065
    left = mm.mixL + (mm.fluteToneL + breath * mm.fluteEnvTrack * 0.8)
    right = mm.mixR + (mm.fluteToneR + breath * mm.fluteEnvTrack)
    outL, outR = master_chain(left, right)  # FFT circular: bufferul de 21 s se termina in liniste, nimic nu se infasoara

    n = int(FILM_SECONDS * SR)
    outL, outR = outL[:n].copy(), outR[:n].copy()
    t = np.arange(n) / SR
    # stingerea finala, doar ca plasa de siguranta (acordul se stinge singur): de la 16,0 la 17,0 s, jumatate de cosinus;
    # 17,0 s = zero. Se aplica dupa reverb, ca sa nu ramana nimic de taiat.
    x = np.clip((t - 16.0) / 1.0, 0, 1)
    fade_out = 0.5 * (1 + np.cos(np.pi * x))
    fade_out[-1] = 0.0
    fade_in = np.minimum(1.0, t / 0.010)
    env = fade_out * fade_in
    outL *= env
    outR *= env

    # stapanire blanda a varfurilor (ca in make_music.finish), apoi varful la -3,1 dBFS (un pic sub -3, ca pragul sa
    # ramana adevarat si dupa rotunjirea la 16 biti)
    peak = max(np.max(np.abs(outL)), np.max(np.abs(outR)))
    outL, outR = outL / peak * 0.9, outR / peak * 0.9
    outL, outR = np.tanh(outL * 1.25) / np.tanh(1.25), np.tanh(outR * 1.25) / np.tanh(1.25)
    peak = max(np.max(np.abs(outL)), np.max(np.abs(outR)))
    target = 10 ** (-3.1 / 20)
    return outL / peak * target, outR / peak * target


def make_music():
    """Compune de patru ori (1 s fiecare, aceeasi samanta: aceleasi note, aceleasi faze): dupa fiecare trecere se masoara notele de
    fluier in pista lor intreaga si se aduce `FLUTE_TRIM` la jumatate din abaterea gasita, ca abaterea sa se imparta egal intre
    masura izolata (nota singura) si cea din pista, nu sa stea toata pe una. La urma ramane compozitia ultimei treceri."""
    FLUTE_TRIM.clear()
    for it in range(4):
        compose_music()
        ctx = flute_context()
        for r, c in zip(FLUTE_LOG, ctx):
            r["ctx"] = c
            r["iso"] = r["dev"] + r["k_db"]  # nota singura, dupa lant, fata de aceeasi nota la castigul scris
        if it < 3 and FLUTE_COMP:
            FLUTE_TRIM[:] = [-(r["ctx"] - r["trim"]) / 2 for r in FLUTE_LOG]  # ctx fara trim = ctx - trim; trim nou = jumatate, cu semn schimbat
    return master_music()


# ---- efectele -----------------------------------------------------------------------------------------


def _norm(x):
    return x / (np.max(np.abs(x)) + 1e-9)


def highpass(x, fc, order=2):
    """Filtru trece-sus Butterworth aplicat in FFT, fara faza (numpy pur, fara scipy). Pe ultima axa. Folosit si la masuratori
    ('telefonul': 300 Hz) si la efecte (taie ce nu se aude pe difuzorul unui telefon si doar mananca din varf). Se umple cu
    zerouri (0,3 s) in jurul semnalului: fara ele FFT-ul e circular, iar bufnetul de la inceput ar suna in ultimele milisecunde
    ale fisierului (masurat: -50 dBFS de zgomot lent in coada, in loc de liniste)."""
    n = x.shape[-1]
    pad = int(0.3 * SR)
    xp = np.concatenate([np.zeros(x.shape[:-1] + (pad,)), x, np.zeros(x.shape[:-1] + (pad,))], axis=-1)
    m = xp.shape[-1]
    f = np.fft.rfftfreq(m, 1 / SR)
    mag = 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-3)) ** (2 * order))
    mag[0] = 0.0
    return np.fft.irfft(np.fft.rfft(xp, axis=-1) * mag, m, axis=-1)[..., pad : pad + n]


def band_db(x, lo, hi, t0, t1):
    """Nivelul (dBFS, RMS) al benzii [lo, hi] Hz pe fereastra [t0, t1) s; x (n,) sau (2, n), mediat pe canale."""
    seg = np.atleast_2d(x)[:, int(t0 * SR) : int(t1 * SR)]
    n = seg.shape[-1]
    f = np.fft.rfftfreq(n, 1 / SR)
    sp = np.fft.rfft(seg * np.hanning(n), axis=-1) * ((f >= lo) & (f < hi))
    y = np.fft.irfft(sp, n, axis=-1) / np.sqrt(np.mean(np.hanning(n) ** 2))
    return 10 * np.log10(np.mean(y ** 2) + 1e-14)


def a_weight(x, hp=None):
    """Ponderare A (IEC 61672) aplicata in FFT, fara faza, cu zerouri in jur ca la `highpass`; `hp` = si un trece-sus Butterworth de
    ordin 2 la acea frecventa (difuzorul unui telefon). Normalizata la 0 dB pe 1 kHz."""
    n = len(x)
    pad = int(0.3 * SR)
    xp = np.concatenate([np.zeros(pad), x, np.zeros(pad)])
    m = len(xp)
    f = np.maximum(np.fft.rfftfreq(m, 1 / SR), 1e-3)
    ra = (12194 ** 2 * f ** 4) / ((f ** 2 + 20.6 ** 2) * np.sqrt((f ** 2 + 107.7 ** 2) * (f ** 2 + 737.9 ** 2)) * (f ** 2 + 12194 ** 2))
    mag = ra * 10 ** (2.0 / 20)
    if hp:
        mag = mag / np.sqrt(1.0 + (hp / f) ** 4)
    mag[0] = 0.0
    return np.fft.irfft(np.fft.rfft(xp) * mag, m)[pad : pad + n]


def max_rms_db(x, t0, t1, win=0.05, hop=0.005):
    """Cel mai tare RMS (dB) pe ferestre de `win` s, cu pasul `hop`, in [t0, t1)."""
    w = int(win * SR)
    best = -200.0
    for s0 in np.arange(t0, t1 - win + 1e-9, hop):
        i = int(s0 * SR)
        best = max(best, 10 * np.log10(np.mean(x[i : i + w] ** 2) + 1e-14))
    return best


def window_db(x, t0, t1):
    seg = x[int(t0 * SR) : int(t1 * SR)]
    return 10 * np.log10(np.mean(seg ** 2) + 1e-14)


NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def chroma_db(x, t0, t1, lo=70.0, hi=2000.0):
    """Cromagrama pe [t0, t1) s: energia pe cele 12 clase de inaltime (70-2000 Hz, fiecare bin la cel mai apropiat semiton, fereastra
    Hann, mixul mono), in dB fata de clasa cea mai tare. Intoarce un vector de 12 valori (C, C#, D, ...)."""
    mono = x.mean(axis=0) if x.ndim == 2 else x
    seg = mono[int(t0 * SR) : int(t1 * SR)]
    size = 1 << 17
    sp = np.abs(np.fft.rfft(seg * np.hanning(len(seg)), size)) ** 2
    f = np.fft.rfftfreq(size, 1 / SR)
    sel = (f >= lo) & (f < hi)
    pc = np.round(12 * np.log2(f[sel] / 440.0) + 69).astype(int) % 12
    e = np.zeros(12)
    np.add.at(e, pc, sp[sel])
    return 10 * np.log10(e / e.max() + 1e-12)


def burst(d, lo, hi, seed, tau):
    """Zgomot de banda [lo, hi] Hz cu plic exponential (stingere `tau`), de ENERGIE FIXA: _norm(band_noise) * exp aduna prea mult
    sau prea putin dupa samanta, cand plicul e de cateva milisecunde (maximul zgomotului cade oriunde, nu in primele ms). Aici
    energia e cea a unui zgomot cu RMS 0,28 (aproape ca varful 1 de la _norm), deci castigurile ramase din _norm raman bune."""
    t = ms.t_axis(d)
    y = ms.band_noise(d, lo, hi, seed) * np.exp(-t / tau)
    return y * 0.28 * np.sqrt((tau / 2.0) / (np.sum(y ** 2) / SR + 1e-18))


def chisel(f, seed):
    """Dalta pe piatra: un 'tink' scurt de metal (trei partiale inarmonice care pier repede), un clic de atac si un 'toc'
    surd al pietrei dedesubt."""
    d = 0.14
    t = ms.t_axis(d)
    ring = (np.sin(2 * np.pi * f * t) * np.exp(-t / 0.011)
            + 0.45 * np.sin(2 * np.pi * f * 1.59 * t) * np.exp(-t / 0.006)
            + 0.30 * np.sin(2 * np.pi * f * 2.31 * t) * np.exp(-t / 0.004))
    tick = _norm(ms.band_noise(d, 2500, 9500, seed)) * np.exp(-t / 0.0018) * 0.7
    body = np.sin(2 * np.pi * 380 * t) * np.exp(-t / 0.012) * 0.35
    return ring * 0.6 + tick + body


def thock(f, seed):
    """Ciocan de lemn pe o grinda, ca sunet de santier: un 'toc' DENS si jos (corpul grinzii la 200-350 Hz, care coboara putin
    in ton) cu un mic ciocnit de ~1,5 kHz deasupra. Cu intentie altceva decat mallet_wood din muzica (640-820 Hz, usor si
    sec): ca sa se auda ca alta sursa, nu ca o a doua lovitura la ciocanul din melodie."""
    d = 0.16
    t = ms.t_axis(d)
    fm = f * (1 + 0.16 * np.exp(-t / 0.012))
    body = np.sin(2 * np.pi * np.cumsum(fm) / SR) * np.exp(-t / 0.042)
    body += 0.40 * np.sin(2 * np.pi * f * 1.93 * t) * np.exp(-t / 0.018)
    knock = burst(d, 1100, 2000, seed, 0.0045) * 2.2
    knock += 0.70 * np.sin(2 * np.pi * 1480 * t + seed) * np.exp(-t / 0.009) + 0.36 * np.sin(2 * np.pi * 2250 * t) * np.exp(-t / 0.005)  # lemnul suna
    tick = burst(d, 2600, 5200, seed + 1, 0.0014) * 0.5
    y = body * 0.9 + knock + tick
    return np.tanh(1.8 * y / np.max(np.abs(y))) / np.tanh(1.8)  # saturare blanda: mai plin la acelasi varf


def stone_set(low=1.0, seed=7):
    """O piatra pusa jos: un scrasnet de granulatie (se aude cum e coborata), apoi bufnetul. Intoarce (semnal, indexul atingerii).
    [director] Bufnetul nu mai e sub-bas: corpul e la ~100-130 Hz (nu la 52), cu un 'toc' de 300-900 Hz si o granulatie de
    1-3 kHz deasupra, ca sa se auda si pe difuzorul unui telefon. `low` ridica totul (piatra mica)."""
    ds = 0.22
    ts = ms.t_axis(ds)
    gate = np.abs(_norm(ms.band_noise(ds, 10, 34, seed + 1)))  # granulatia: aluneca si se opreste
    scrape = _norm(ms.band_noise(ds, 250, 2900, seed)) * gate * (ts / ds) ** 0.7 * 0.30
    d = 0.55
    t = ms.t_axis(d)
    f = (104 + 30 * np.exp(-t / 0.045)) * low
    thud = 0.60 * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.07)
    thud += 0.22 * np.sin(2 * np.pi * 2.0 * np.cumsum(f) / SR) * np.exp(-t / 0.035)
    thud += 0.35 * burst(d, 110 * low, 420 * low, seed + 2, 0.060) * 3.4  # corpul pietrei
    # 'tocul': piatra sunatoare, cateva rezonante inarmonice (300-900 Hz) care se sting in 30-50 ms, plus zgomot; partialele
    # (tonale) tin energia in banda asta mult mai bine decat zgomotul, la acelasi varf
    for fr, amp, tau in ((310, 0.38, 0.050), (470, 0.32, 0.042), (690, 0.28, 0.034)):
        thud += amp * np.sin(2 * np.pi * fr * low * t + seed) * np.exp(-t / tau)
    thud += 0.40 * burst(d, 300 * low, 900 * low, seed + 3, 0.032) * 3.4
    # fisura: granulatia de 1-3,5 kHz si cateva clinchete de piatra (1,3 si 2,1 kHz): ce se aude acolo unde muzica e linistita
    thud += 1.00 * burst(d, 1000, 3500, seed + 4, 0.014) * 3.4
    for fr, amp, tau in ((1290, 0.50, 0.030), (2130, 0.34, 0.020)):
        thud += amp * np.sin(2 * np.pi * fr * t + 2 * seed) * np.exp(-t / tau)
    thud += 0.12 * burst(d, 3500, 7000, seed + 5, 0.004) * 3.4  # clicul atingerii
    # saturare blanda a atingerii (ca la un limitator): fisura de la inceput, cea mai inalta, se rotunjeste, iar corpul si 'tocul'
    # raman mai sus fata de ea la acelasi varf; adauga si armonice, bune pe difuzoare mici
    thud = np.tanh(2.4 * thud / np.max(np.abs(thud))) / np.tanh(2.4)
    return np.concatenate([scrape, thud]), len(scrape)


def creak_buzz(dur, seed, f_lo=900.0, f_hi=1500.0, rate_lo=70.0, rate_hi=120.0):
    """Franghia prin scripete, prima varianta (cea de dinainte de verificator, pastrata ca alternativa de ascultat): un tren
    neregulat de zvacnituri de rezonanta, 70-120 pe secunda, cu frecventa rezonantei care aluneca odata cu incordarea franghiei,
    taiat de un plic lent si de pauze de agatare; deasupra, foșnetul fibrelor. La ureche poate iesi mai degraba un zumzet."""
    r = np.random.default_rng(seed)
    n = int(dur * SR)
    out = np.zeros(n)
    pn = int(0.014 * SR)
    pt = np.arange(pn) / SR
    t = 0.0
    while t < dur - 0.02:
        x = t / dur
        rate = rate_lo + (rate_hi - rate_lo) * np.sin(np.pi * x) ** 1.2 + r.uniform(-8, 8)
        fr = f_lo + (f_hi - f_lo) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.7 * x + seed))
        pulse = (np.sin(2 * np.pi * fr * pt) + 0.5 * np.sin(2 * np.pi * 2.4 * fr * pt)) * np.exp(-pt / 0.0032)
        i = int(t * SR)
        m = min(pn, n - i)
        out[i : i + m] += pulse[:m] * r.uniform(0.6, 1.0)
        t += (1.0 / max(rate, 20.0)) * r.uniform(0.82, 1.22)
    stick = np.clip(_norm(ms.band_noise(dur, 3, 9, seed + 5)) * 1.6 + 0.55, 0, 1)  # cand "se agata", scartaitul se opreste
    swell = np.sin(np.pi * np.linspace(0, 1, n)) ** 0.8
    fibre = _norm(ms.band_noise(dur, 1500, 5000, seed + 6)) * 0.07 * swell
    return _norm(out) * stick * swell + fibre


def creak(dur, seed, f_lo=430.0, f_hi=820.0, rate_lo=26.0, rate_hi=58.0, tau_lo=0.010, tau_hi=0.006):
    """Franghia prin scripete, varianta a doua [director]: o franghie adevarata nu zumzaie, ci se AGATA si ALUNECA, lent: 25-60
    de alunecari pe secunda (de la ~25 la ~60 pe masura ce se incordeaza, cum urca piatra), cu +-20% neregularitate, iecare
    alunecare un clinchet scurt al scripetelui de lemn: rezonanta lui la 400-900 Hz (urca putin odata cu incordarea), cu o
    stingere mai lunga (6-10 ms) decat la zumzetul din prima varianta. Plicul urca lent si se rupe la sfarsit (franghia se opreste
    cand piatra ajunge jos); intre alunecari, un foșnet slab al fibrelor."""
    r = np.random.default_rng(seed)
    n = int(dur * SR)
    out = np.zeros(n)
    pn = int(0.05 * SR)
    pt = np.arange(pn) / SR
    t = 0.0
    while t < dur - 0.03:
        x = t / dur
        tension = x ** 1.1
        rate = rate_lo + (rate_hi - rate_lo) * tension
        fr = (f_lo + (f_hi - f_lo) * (0.25 + 0.75 * tension)) * r.uniform(0.9, 1.1)
        tau = tau_lo + (tau_hi - tau_lo) * tension
        pulse = (np.sin(2 * np.pi * fr * pt) + 0.45 * np.sin(2 * np.pi * 2.13 * fr * pt) * np.exp(-pt / (tau * 0.5))) * np.exp(-pt / tau)
        click = _norm(ms.band_noise(0.004, 1500, 4500, int(t * 1000) + seed)) * np.exp(-np.arange(int(0.004 * SR)) / (0.0012 * SR))
        i = int(t * SR)
        m = min(pn, n - i)
        out[i : i + m] += pulse[:m] * r.uniform(0.55, 1.0)
        out[i : i + len(click)] += click[: n - i] * 0.5
        t += (1.0 / rate) * r.uniform(0.8, 1.2)
    stick = np.clip(_norm(ms.band_noise(dur, 2, 6, seed + 5)) * 1.4 + 0.6, 0, 1)  # cand "se agata", alunecarile se rarefiaza
    env = np.minimum(1.0, np.linspace(0, dur, n) / 0.18) ** 1.2
    env[-int(0.02 * SR):] *= np.linspace(1, 0, int(0.02 * SR))
    fibre = _norm(ms.band_noise(dur, 1500, 5000, seed + 6)) * 0.05 * env
    return _norm(out) * stick * env + fibre


def put(buf, sig, t, gain):
    i = int(t * SR)
    if i >= len(buf):
        return
    m = min(len(sig), len(buf) - i)
    buf[i : i + m] += sig[:m] * gain


# Santierul sub muzica porneste la 11,0 s; zidul se inchide la 13,6 s (DamMath.FILM_MEET_BEFORE = 0,4 inaintea cartonului).
# dalta: (moment in fisier, frecventa tink-ului, castig relativ); 11,0 s + moment = momentul din film. [director] Dupa verificator:
# castigul general x1,3 (era 0,7: +5,4 dB), iar trei dalti care cadeau peste loviturile muzicii (toaca la 11,25, toba si shaker la 11,5 si
# la 13,0) au primit ton mai sus (tink-ul de 2,6-2,8 kHz iese din banda 3-8 kHz, unde muzica e aproape goala) si, doua, castig mai mare
CHISELS = [(0.08, 3100, 0.55), (0.25, 3300, 0.50), (0.37, 3350, 0.40), (0.52, 3400, 0.45), (1.08, 3000, 0.40), (1.22, 3000, 0.40),
           (1.78, 3200, 0.46), (2.02, 3150, 0.55), (2.20, 3050, 0.30)]
CHISELS_V1 = [(0.08, 3100, 0.55), (0.25, 2800, 0.50), (0.37, 3350, 0.40), (0.52, 2950, 0.30), (1.08, 2600, 0.48), (1.22, 3000, 0.40),
              (1.78, 3200, 0.46), (2.02, 2750, 0.38), (2.20, 3050, 0.30)]  # prima varianta, cu castig 0,7: doar pentru comparatia din raport
CHISEL_GAIN = 1.3
BUILD_AT = 11.0
MEET_AT = 13.6
BUILD_SECONDS = MEET_AT - BUILD_AT  # 2,6 s: santierul se opreste cand se intalnesc jumatatile zidului


def make_build(kind="rope", chisels=None, chisel_gain=None):
    """Santierul: rar si neregulat, 2,6 s (11,0-13,6 s), apoi liniste: cand cele doua jumatati se ating (sfx_film_close), lucrul
    se opreste. Dalta in rafale mici, ciocanul de lemn (toc dens, jos), piatra coborata cat scartaie franghia (se opreste cand
    piatra ajunge jos), apoi alt scartait scurt si o piatra mai mica.
    [director] Lovituri de ciocan si de piatra la 0,125 s + k x 0,25 fata de pornire, adica la mijloc intre loviturile muzicii
    (toba pe 0,5 s, toaca la +0,25, ciocanul melodiei la +0,75): se aud ca alt strat, nu ca o dublura la 50-80 ms. Tot ce
    e sub 90 Hz e taiat (muzica are acolo toba, basul si padul): fara el varful ramane pe ce se aude pe un telefon."""
    buf = np.zeros(int(round(SR * BUILD_SECONDS)))  # 114660 esantioane exact (2,6 s)
    if kind == "buzz":  # prima varianta a scartaitului (alternativa de ascultat, sfx_film_build_altcreak)
        c1, c2 = creak_buzz(1.28, 3, 900, 1500, 70, 120), creak_buzz(0.36, 9, 1250, 1900, 95, 150)
    else:
        c1, c2 = creak(1.28, 3), creak(0.36, 9, 560, 920, 34, 62)
    put(buf, c1, 0.30, 0.85)  # franghia ridica piatra, se opreste inainte de atingere
    put(buf, c2, 1.97, 0.62)  # a doua, mai scurta si mai sus
    for i, (t, f, g) in enumerate(CHISELS if chisels is None else chisels):
        put(buf, chisel(f, 40 + i), t, g * (CHISEL_GAIN if chisel_gain is None else chisel_gain))
    for i, (t, f, g) in enumerate(((0.625, 240, 0.85), (0.875, 215, 0.75), (1.875, 255, 0.95), (2.125, 230, 0.80))):
        put(buf, thock(f, 90 + i), t, g)
    block, hit = stone_set(1.0, 7)
    put(buf, block, 1.625 - hit / SR, 1.0)  # atingerea la 1,625 s (12,625 s in film), cand se opreste scartaitul
    small, hit2 = stone_set(1.45, 17)
    put(buf, small, 2.375 - hit2 / SR, 0.85)  # piatra mica, la 2,375 s: tacerea de dinaintea bufnetului de la 2,6 s
    buf = highpass(buf, 90.0)
    buf = ms.fade_edges(buf, ms=5)
    r = int(0.12 * SR)  # coada: 120 ms de stingere lina (piatra mica de la 13,375 s mai sunase inca la 13,6 s)
    buf[-r:] *= np.linspace(1, 0, r)
    return ms.normalize(buf, -6.5)


def minnaert(f0, seed=0):
    """O bula de aer care urca prin apa: un sinus la frecventa lui Minnaert (f0 ~ 3/raza, 400-2000 Hz inseamna raze de 1,5-7,5 mm),
    amortizat de apa, care urca in ton cat bula se rotunjeste (modelul lui van den Doel: d = 0,043 f0 + 0,0014 f0^1,5; ton x
    (1 + 0,1 d t))."""
    d = 0.043 * f0 + 0.0014 * f0 ** 1.5
    n = int(min(0.15, 6.0 / d) * SR)
    t = np.arange(n) / SR
    f = f0 * (1 + 0.1 * d * t)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-d * t)
    a = max(1, int(0.0006 * SR))
    s[:a] *= np.linspace(0, 1, a)
    return s


# nivelul clipocitului din inchidere pe 500-1000 Hz, in dBFS (dupa normalizarea la -3,1): langa acordul din carton (14,0-15,9 s), care
# sta pe 500-1000 Hz la ~-21,0 dBFS la volum 1,0 (tinta: apa in 3 dB de el), si cu bufnetul cu 0...+3 dB peste apa (ponderat A, max pe 50 ms).
# [verificatorul final] Era -20,5, iar bufnetul era cu 6 dB SUB apa; apoi -23,5 (verificatorul); cu bufnetul mai plin si bulele mai
# tari, -21,5 tine ambele tinte
WATER_DB = -21.5
# modulatia clipocitului: nivelul oscileaza 3-6 ori pe secunda intre WATER_AM_MIN si 1 (inainte cadea la zero: apa 'se taia' si
# sarea cu 10 dB de la o suta de milisecunde la alta); dupa verificator: podea ridicata (0,45 + 0,55 x zgomot, minim 0,25; verificatorul
# propusese 0,35 / 0,15: la 100 ms tot mai sarea cu 7-8 dB)
CLOSE_INFO = {}  # masuratori scoase de make_close pentru raport
WATER_AM_FLOOR = 0.45
WATER_AM_MIN = 0.25
BUBBLES_DB = -9.5  # bulele fata de restul apei, pe 0,4-2,3 s (inainte -14)
THUD_DRIVE = 2.4  # cat de tare e saturat bufnetul inchiderii (tanh): mai plin la acelasi varf


def make_close():
    """Cele doua jumatati se intalnesc: un bufnet de piatra (corp la 55-125 Hz, 'toc' de piatra la 180-760 Hz) cu un scrasnet scurt
    piatra-pe-piatra deasupra (0,12 s, 800-3000 Hz), cateva pietricele care se aseaza, apoi apa care urca in spatele zidului:
    patul jos (35-900 Hz, umflare cu timbru care urca), peste el clipocitul (500-1100 si 1000-2400 Hz, cu modulatie neregulata de 3-6 Hz care
    urmeaza umflarea) si bule care urca (Minnaert), tot mai dese pe masura ce apa creste; stinsa la zero la 2,5 s.
    [director] Apa trebuie sa se auda si pe un difuzor de telefon: clipocitul si bulele stau la 400-2400 Hz, unde e si acordul
    din cartonul filmului, iar bufnetul nu mai cheltuieste varful pe sub-bas (taiat sub 40 Hz inainte de normalizare).
    [verificatorul final] Bufnetul trebuie sa se auda MAI TARE decat apa, nu sub ea: partialele de 540 / 760 Hz tin de doua ori mai mult
    (tau 0,08 / 0,06 s), tot bufnetul (corp + toc + zgomot + scrasnet) trece printr-o saturare blanda (tanh, THUD_DRIVE) ca la stone_set,
    deci are mai multa energie pe 200-3000 Hz la acelasi varf (-3,1 dBFS), iar apa coboara (WATER_DB). Masurat: cu 0...+3 dB peste apa si
    ponderat A, si cu trece-sus de 300 Hz (telefon). Clipocitul are modulatia cu podea (nu mai cade la zero), bulele sunt mai tari."""
    dur = 2.5
    n = int(SR * dur)
    t = ms.t_axis(dur)
    out = np.zeros(n)
    # bufnetul: corp (55 Hz in jos de la 125), 'toc' de piatra (180 si 310 Hz) si zgomot de corp 150-450 Hz
    f = 55 + 70 * np.exp(-t / 0.05)
    thud = 0.55 * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.15)
    thud += 0.30 * np.sin(2 * np.pi * 2.0 * np.cumsum(f) / SR) * np.exp(-t / 0.08)
    thud += 0.75 * np.sin(2 * np.pi * 180 * t * (1 + 0.08 * np.exp(-t / 0.03))) * np.exp(-t / 0.075)
    thud += 0.55 * np.sin(2 * np.pi * 310 * t) * np.exp(-t / 0.05)
    thud += 0.50 * np.sin(2 * np.pi * 540 * t) * np.exp(-t / 0.08) + 0.40 * np.sin(2 * np.pi * 760 * t) * np.exp(-t / 0.06)  # piatra suna
    boom = _norm(ms.band_noise(dur, 60, 300, 51)) * np.exp(-t / 0.13) * 0.40
    knock = _norm(ms.band_noise(dur, 150, 450, 53)) * np.exp(-t / 0.07) * 0.80
    # scrasnetul piatra-pe-piatra: 0,12 s de granulatie 800-3000 Hz, cu un clic de atac; se aude cum se "aseaza" jumatatile
    gd = 0.12
    tg = ms.t_axis(gd)
    gate = np.clip(np.abs(_norm(ms.band_noise(gd, 25, 110, 55))) * 1.6 + 0.25, 0, 1)
    grind = _norm(ms.band_noise(gd, 800, 3000, 54)) * gate * np.exp(-tg / 0.075) * 1.05
    crack = _norm(ms.band_noise(0.02, 1800, 5200, 56)) * np.exp(-ms.t_axis(0.02) / 0.0035) * 0.55
    out += thud + boom + knock
    out[: len(grind)] += grind
    out[: len(crack)] += crack
    out = np.tanh(THUD_DRIVE * out / np.max(np.abs(out))) / np.tanh(THUD_DRIVE)  # saturare blanda a bufnetului (ca la stone_set)
    # pietricele care se aseaza dupa lovitura
    for k, (tt, g) in enumerate([(0.11, 0.07), (0.19, 0.05), (0.33, 0.06), (0.52, 0.03)]):
        put(out, _norm(ms.band_noise(0.04, 1500, 6000, 60 + k)) * np.exp(-ms.t_axis(0.04) / 0.008), tt, g)
    # apa: umflare (plic care urca ~0,8 s si coboara la zero exact la 2,5 s)
    x = np.clip((t - 0.20) / 2.30, 0, 1)
    env = np.sin(np.pi * x ** 0.78) ** 2  # varful la x = 0,41, adica ~1,15 s
    bands = [(35, 150, 0.2, 0.8), (110, 340, 0.7, 1.1), (260, 900, 1.1, 1.5)]  # (jos, sus, varful, latimea) -- timbrul urca
    water = np.zeros(n)
    for i, (lo, hi, peak, width) in enumerate(bands):
        layer = _norm(ms.band_noise(dur, lo, hi, 70 + i))
        w = np.exp(-(((t - 0.15) - peak) / width) ** 2)
        water += layer * w * (0.80 if i == 0 else 0.55 if i == 1 else 0.30)
    wobble = 0.8 + 0.2 * _norm(ms.band_noise(dur, 1.5, 6, 80))  # clipocitul apei: clatinare lenta a nivelului
    bed = water * env * wobble * 1.05
    # clipocitul: doua benzi de zgomot (500-1400 si 1200-2800 Hz) cu modulatie neregulata de 3-6 Hz, adanca, care urmeaza umflarea
    slosh = np.zeros(n)
    for i, (lo, hi, gain) in enumerate(((500, 1100, 1.0), (1000, 2400, 0.12))):
        am = np.clip(WATER_AM_FLOOR + (1 - WATER_AM_FLOOR) * _norm(ms.band_noise(dur, 3.0, 6.0, 90 + i)), WATER_AM_MIN, 1.0)
        slosh += _norm(ms.band_noise(dur, lo, hi, 95 + i)) * am * gain
    slosh *= env ** 0.8
    # bulele: ~26 de clinchete Minnaert (400-2000 Hz, urca in ton), la momente intamplatoare, mai dese cand apa e mai sus
    r = np.random.default_rng(31)
    cdf = np.cumsum(env[int(0.30 * SR) : int(2.30 * SR)] ** 1.2)
    cdf /= cdf[-1]
    bubbles = np.zeros(n)
    for tt in np.sort(0.30 + 2.0 * np.interp(r.uniform(0, 1, 26), cdf, np.linspace(0, 1, len(cdf)))):
        f0 = float(np.exp(r.uniform(np.log(400), np.log(2000))))
        put(bubbles, minnaert(f0), tt, r.uniform(0.45, 1.0))
    # echilibrul stratului de apa [director]. Varful fisierului e bufnetul de la inceput (apa vine dupa 0,2 s), deci nivelul de
    # dupa normalizare se stie inainte de a aduna apa: clipocitul se aduce la WATER_DB (acordul din carton pe 500-1000 Hz, masurat pe
    # muzica la volum 1,0, ajustat ca bufnetul sa iasa cu 0...+3 dB peste apa, ponderat A), iar bulele la BUBBLES_DB sub tot restul
    # (-9,5; inainte -14, iar in prima varianta -33). Rezultatul, cu tot cu tot (pat + clipocit + bule), fata de acord pe 14,0-15,9 s:
    # +0,2 dB pe 500-1000 Hz si +1,6 dB pe 1-2 kHz la volum 1,0 (-2,9 / -1,5 la volumul din joc, 0,7): vezi tabelul de la sfarsitul rularii.
    scale = 10 ** (-3.1 / 20) / np.max(np.abs(out))
    lvl = band_db(slosh * scale, 500, 1000, 0.4, 2.3)
    slosh *= 10 ** ((WATER_DB - lvl) / 20)
    win = (int(0.4 * SR), int(2.3 * SR))
    mix_ = out + bed + slosh
    ref = np.sqrt(np.mean(mix_[win[0] : win[1]] ** 2))
    b_rms = np.sqrt(np.mean(bubbles[win[0] : win[1]] ** 2))
    bubbles *= (ref * 10 ** (BUBBLES_DB / 20)) / (b_rms + 1e-9)
    out = mix_ + bubbles
    CLOSE_INFO["bubbles_db"] = 20 * np.log10(np.sqrt(np.mean(bubbles[win[0] : win[1]] ** 2)) / ref)  # bule fata de restul apei, 0,4-2,3 s
    out = highpass(out, 40.0)  # fara sub-bas inainte de normalizare: varful nu se mai cheltuieste pe ce nu se aude
    out = ms.fade_edges(out, ms=5)
    out[-int(0.05 * SR):] *= np.linspace(1, 0, int(0.05 * SR))
    return ms.normalize(out, -3.1)


# ---- iesirea ------------------------------------------------------------------------------------------


def write_stereo(path, left, right):
    mm.write_wav(path, left, right)


def decoded_peak_db(path):
    """Varful (dBFS) al fisierului asa cum il aude jocul, adica dupa decodare: un codec cu pierderi poate trece cu cateva
    zecimi de dB peste varful PCM de la intrare."""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-acodec", "pcm_f32le", "-"],
                         check=True, capture_output=True).stdout
    return 20 * np.log10(max(np.max(np.abs(np.frombuffer(raw, dtype=np.float32))), 1e-12))


def encode(write, base, sig, limit_db):
    """Scrie WAV, il converteste in OGG cu acelasi convertor ca make_sounds, apoi masoara varful OGG-ului decodat; daca
    depaseste `limit_db`, coboara semnalul cu depasirea (+0,05 dB) si reia. Intoarce semnalul final. Apoi MP3-ul de ascultat."""
    for _ in range(5):
        write(base + ".wav", sig)
        ms.to_ogg(base + ".wav", base + ".ogg")
        peak = decoded_peak_db(base + ".ogg")
        if peak <= limit_db:
            break
        sig = sig * 10 ** (-(peak - limit_db + 0.05) / 20)
    subprocess.run([LAME, "--silent", "-V", "2", base + ".wav", base + ".mp3"], check=True)
    return sig, decoded_peak_db(base + ".ogg")


def stats(name, sig):
    a = sig if sig.ndim == 1 else sig.T
    peak = np.max(np.abs(a))
    rms = np.sqrt(np.mean(a ** 2))
    seconds = (sig.shape[-1]) / SR
    return {
        "name": name,
        "dur": seconds,
        "peak_db": 20 * np.log10(max(peak, 1e-12)),
        "rms_db": 20 * np.log10(max(rms, 1e-12)),
    }


# ---- previzualizarea: forma de unda + spectrograma (fara matplotlib: numpy + PIL) ---------------------

MAGMA = [(0.0, (0, 0, 4)), (0.25, (60, 15, 110)), (0.5, (150, 45, 125)), (0.75, (240, 105, 95)), (1.0, (252, 253, 191))]


def colormap(v):
    xs = [p for p, _ in MAGMA]
    return np.stack([np.interp(v, xs, [c[k] for _, c in MAGMA]) for k in range(3)], axis=-1).astype(np.uint8)


def spectrogram_img(x, width, height, fmin=40.0, fmax=12000.0, n_fft=2048, hop=512, floor_db=-78.0):
    pad_ = n_fft // 2
    xp = np.pad(x, (pad_, pad_))
    nfr = 1 + (len(xp) - n_fft) // hop
    idx = np.arange(n_fft)[None, :] + hop * np.arange(nfr)[:, None]
    spec = np.abs(np.fft.rfft(xp[idx] * np.hanning(n_fft), axis=1)) ** 2
    # frecventa pe scara logaritmica: fiecare rand al imaginii = o frecventa, interpolata intre doua binuri
    freqs = np.geomspace(fmin, fmax, height)[::-1]
    pos = freqs / (SR / n_fft)
    lo = np.floor(pos).astype(int)
    fr = pos - lo
    rows = spec[:, lo] * (1 - fr) + spec[:, np.minimum(lo + 1, spec.shape[1] - 1)] * fr  # (frames, height)
    db = 10 * np.log10(rows + 1e-14)
    db = np.clip((db - db.max()) , floor_db, 0)
    img = colormap((db - floor_db) / -floor_db).transpose(1, 0, 2)
    return Image.fromarray(img).resize((width, height), Image.BILINEAR)


def load_font(size):
    for path in ("/System/Library/Fonts/Helvetica.ttc", "/System/Library/Fonts/HelveticaNeue.ttc", "/System/Library/Fonts/Geneva.ttf"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def preview(items, path):
    """items: lista de (titlu, semnal (n,) sau (2, n), faze sau None, rezumat[, marcaje]). Un bloc pe sunet: forma de unda deasupra,
    spectrograma dedesubt (frecventa logaritmica 40 Hz - 12 kHz). Marcajele (secunda, eticheta) sunt linii albe punctate:
    momentele in care pornesc efectele peste muzica, in blocul mixului."""
    W, left, right = 1760, 78, 24
    pw = W - left - right
    wave_h, spec_h = 150, 230
    block_h = 36 + wave_h + 8 + spec_h + 34
    H = 64 + block_h * len(items)
    img = Image.new("RGB", (W, H), (22, 22, 28))
    d = ImageDraw.Draw(img)
    f_big, f_mid, f_small = load_font(24), load_font(16), load_font(13)
    d.text((left, 16), "A2 film sound: waveform + log-frequency spectrogram (40 Hz - 12 kHz)", fill=(235, 235, 240), font=f_big)
    phase_colors = [(120, 160, 255), (90, 200, 160), (240, 190, 90), (240, 120, 90), (200, 140, 255)]
    y = 64
    for item in items:
        title, sig, phases, info = item[:4]
        marks = item[4] if len(item) > 4 else []
        mono = sig if sig.ndim == 1 else sig.mean(axis=0)
        dur = len(mono) / SR
        d.text((left, y + 4), title, fill=(235, 235, 240), font=f_mid)
        d.text((left + 330, y + 6), info, fill=(170, 175, 190), font=f_small)
        wy, sy = y + 36, y + 36 + wave_h + 8
        # forma de unda: minim/maxim pe coloana
        d.rectangle([left, wy, left + pw, wy + wave_h], fill=(30, 30, 38))
        cols = np.linspace(0, len(mono), pw + 1).astype(int)
        mid = wy + wave_h // 2
        d.line([left, mid, left + pw, mid], fill=(60, 60, 72))
        for c in range(pw):
            seg = mono[cols[c] : max(cols[c + 1], cols[c] + 1)]
            d.line([left + c, mid - int(seg.max() * wave_h / 2 / 0.75), left + c, mid - int(seg.min() * wave_h / 2 / 0.75)], fill=(120, 190, 230))
        img.paste(spectrogram_img(mono, pw, spec_h), (left, sy))
        # axa de timp si limitele fazelor
        step = 1.0 if dur > 6 else 0.5
        ticks = np.arange(0, dur + 1e-6, step)
        for tk in ticks:
            x = left + int(pw * tk / dur)
            d.line([x, sy + spec_h, x, sy + spec_h + 5], fill=(180, 180, 190))
            d.text((x - 8, sy + spec_h + 8), f"{tk:g}", fill=(170, 175, 190), font=f_small)
        d.text((left + pw - 40, sy + spec_h + 8), "s", fill=(170, 175, 190), font=f_small)
        if phases:
            for k, (a, b, name) in enumerate(phases):
                xa, xb = left + int(pw * a / dur), left + int(pw * b / dur)
                col = phase_colors[k % len(phase_colors)]
                d.text((xa + 6, wy + 4), f"{name}  {a}-{b} s", fill=col, font=f_small)
                if a > 0:
                    d.line([xa, wy, xa, sy + spec_h], fill=col, width=2)
        for tm, label in marks:
            xm = left + int(pw * tm / dur)
            for yy in range(wy, sy + spec_h, 8):
                d.line([xm, yy, xm, yy + 4], fill=(245, 245, 250), width=2)
            d.text((xm + 5, sy + spec_h - 18), label, fill=(245, 245, 250), font=f_small)
        # axa frecventelor
        for fq in (100, 1000, 10000):
            frac = np.log(fq / 40.0) / np.log(12000.0 / 40.0)
            yy = sy + spec_h - int(spec_h * frac)
            d.line([left - 5, yy, left, yy], fill=(180, 180, 190))
            d.text((left - 52, yy - 8), f"{fq // 1000}k" if fq >= 1000 else str(fq), fill=(170, 175, 190), font=f_small)
        y += block_h
    img.save(path)


# ---- mixul de ascultat si masuratorile (cat se aude fiecare lucru peste muzica) -----------------------

# volumele efectelor din joc (SoundController.VOLUME) si fereastra in care porneste fiecare
VOL_BUILD = 0.45
VOL_CLOSE = 0.70
BANDS = [(125, 250), (250, 500), (500, 1000), (1000, 2000), (2000, 4000), (4000, 8000)]


def mix_down(music, build, close, music_gain=1.0, vol_build=VOL_BUILD, vol_close=VOL_CLOSE):
    """Muzica (2, n) cu santierul la 11,0 s si inchiderea la 13,6 s, la volumele din joc. Efectele sunt mono: in ambele canale."""
    out = music * music_gain
    for sig, t0, vol in ((build, BUILD_AT, vol_build), (close, MEET_AT, vol_close)):
        i = int(t0 * SR)
        m = min(len(sig), out.shape[1] - i)
        out[:, i : i + m] += sig[None, :m] * vol
    return out


def placed(sig, t0, n, vol=1.0):
    """Efectul mono pus la t0 s intr-un tablou de n esantioane (ca sa-l comparam cu muzica pe aceeasi fereastra)."""
    out = np.zeros(n)
    i = int(t0 * SR)
    m = min(len(sig), n - i)
    out[i : i + m] = sig[:m] * vol
    return out


def report(music, build, close):
    """Cat de sus sta fiecare efect fata de muzica, pe benzi, pe ferestrele scurte in care se aude (60 ms dupa fiecare lovitura) si
    pe cea lunga a apei, prin 300 Hz trece-sus (un difuzor de telefon) si la volumele din joc. Valorile sunt in dB, "+" = efectul
    e mai sus decat muzica in acea banda. 'unitate' = fisierele asa cum sunt (aceeasi amplitudine, ca la verificator); 'joc' =
    cu SoundController.VOLUME (santier 0,45, inchidere 0,7) peste muzica la 1,0."""
    n = music.shape[1]
    ph = highpass(music, 300.0)
    for_ = lambda vol: placed(close, MEET_AT, n, vol)  # noqa: E731
    print("  Masuratori (efect - muzica, dB; + = efectul e mai sus). Ferestre scurte: 60 ms dupa lovitura.")

    def row(e, m, w0, w1, bands):
        return "  ".join(f"{lo}-{hi}: {band_db(e, lo, hi, w0, w1) - band_db(m, lo, hi, w0, w1):+5.1f}" for lo, hi in bands)

    # 1) apa din inchidere fata de acordul din carton (14,0-15,9 s): tinta director = in ~3 dB pe 500-2000 Hz
    wb = ((500, 1000), (1000, 2000), (300, 2000))
    e1, e7 = for_(1.0), for_(VOL_CLOSE)
    print("    apa fata de acordul din carton, 14,0-15,9 s (tinta: in ~3 dB pe 500-2000 Hz):")
    print(f"      unitate        {row(e1, music, 14.0, 15.9, wb)}")
    print(f"      joc (x{VOL_CLOSE})     {row(e7, music, 14.0, 15.9, wb)}")
    print(f"      telefon, unit. {row(highpass(e1, 300.0), ph, 14.0, 15.9, wb)}   (300 Hz trece-sus pe ambele; 300-2000 = tot ce aude telefonul din acord)")
    print(f"      telefon, joc   {row(highpass(e7, 300.0), ph, 14.0, 15.9, wb)}")
    # 2) bufnetul inchiderii, primele 60 ms: pe un telefon se aude prin benzile de sus
    cb = ((60, 150), (150, 450), (450, 900), (900, 3000), (3000, 8000))
    print("    bufnetul inchiderii (13,6-13,66 s):")
    print(f"      unitate        {row(e1, music, MEET_AT, MEET_AT + 0.06, cb)}")
    print(f"      joc (x{VOL_CLOSE})     {row(e7, music, MEET_AT, MEET_AT + 0.06, cb)}")
    # 2b) [director] bufnetul fata de apa, asa cum se aude: ponderat A (urechea), maximul pe 50 ms; 'telefon' = si trece-sus 300 Hz
    print("    bufnet fata de apa (maximul RMS pe 50 ms; bufnet 0-0,2 s, apa 0,3-2,4 s; tinta: bufnetul cu 0...+3 dB peste apa, in toate trei):")
    for nm, weigh in (("ponderat A                 ", lambda y: a_weight(y)),
                      ("ponderat A + trece-sus 300 Hz", lambda y: a_weight(y, 300.0)),
                      ("doar trece-sus 300 Hz (telefon)", lambda y: highpass(y, 300.0))):
        aw = weigh(close)
        th, wa = max_rms_db(aw, 0.0, 0.2), max_rms_db(aw, 0.3, 2.4)
        print(f"      {nm:32s} bufnet {th:6.1f} dBFS   apa {wa:6.1f} dBFS   diferenta {th - wa:+.1f} dB")
    print("      (inainte de revizie, aceleasi masuratori: ponderat A -19,6 / -13,5 = -6,1; doar trece-sus 300 Hz -17,9 / -12,6 = -5,3)")
    # 2c) apa: nivelul pe 100 ms (modulatia nu trebuie sa taie apa) si bulele
    v = np.array([window_db(close, s0, s0 + 0.1) for s0 in np.arange(0.5, 2.4, 0.1)])
    print("    apa, RMS pe 100 ms (dBFS), de la 0,5 s: " + " ".join(f"{a:.0f}" for a in v))
    body = v[1:10]  # 0,6-1,5 s: cat plicul umflarii e aproape de varf; dincolo de el apa scade singura
    print(f"      pe 0,6-1,5 s: intre {body.min():.1f} si {body.max():.1f} dBFS, adica {body.max() - body.min():.1f} dB, pas maxim intre ferestre vecine "
          f"{np.max(np.abs(np.diff(body))):.1f} dB (inainte: 10,5 dB pe aceeasi fereastra, cu pasi de pana la 10,5); podea de modulatie "
          f"{WATER_AM_MIN} (inainte 0), bule {CLOSE_INFO['bubbles_db']:+.1f} dB fata de restul apei (inainte -14)")
    # 3) santierul: piatra pusa jos, ciocanele, dalta -- fiecare pe benzile in care muzica e linistita
    bb = ((90, 300), (300, 900), (900, 3000), (3000, 8000))
    b1, b45 = placed(build, BUILD_AT, n, 1.0), placed(build, BUILD_AT, n, VOL_BUILD)
    print("    santierul, pe loviturile lui (unitate / joc x%.2f):" % VOL_BUILD)
    for nm, dt in (("piatra mare", 1.625), ("piatra mica", 2.375), ("toc de ciocan", 0.625), ("toc de ciocan", 0.875),
                   ("toc de ciocan", 1.875), ("toc de ciocan", 2.125), ("dalta", 0.25), ("dalta", 1.78)):
        tt = BUILD_AT + dt
        print(f"      {nm:14s} la {tt:6.3f} s  unitate: {row(b1, music, tt, tt + 0.06, bb)}")
        print(f"      {'':14s}                 joc:      {row(b45, music, tt, tt + 0.06, bb)}")
    old_build = placed(make_build(chisels=CHISELS_V1, chisel_gain=0.7), BUILD_AT, n, 1.0)  # varianta de dinainte, aceeasi pietre, aceeasi scara
    print("    dalta, 3-8 kHz fata de muzica, 60 ms dupa fiecare (unitate; 'inainte' = lista si castigul de dinainte de revizie):")
    row_c = []
    for t_c, f_c, g_c in CHISELS:
        tt = BUILD_AT + t_c
        d_mu = band_db(music, 3000, 8000, tt, tt + 0.06)
        row_c.append(f"{tt:.2f}s {band_db(b1, 3000, 8000, tt, tt + 0.06) - d_mu:+.1f} (inainte {band_db(old_build, 3000, 8000, tt, tt + 0.06) - d_mu:+.1f})")
    print("      " + ";  ".join(row_c))
    chis_new = max(np.max(np.abs(build[int(t_c * SR) : int((t_c + 0.05) * SR)])) for t_c, _, _ in CHISELS)
    chis_old = max(np.max(np.abs(old_build[int((BUILD_AT + t_c) * SR) : int((BUILD_AT + t_c + 0.05) * SR)])) for t_c, _, _ in CHISELS_V1)
    print(f"      cea mai tare dalta (primele 50 ms): {20 * np.log10(chis_new):.1f} dBFS (inainte {20 * np.log10(chis_old):.1f}); "
          f"media celor noua, pe 3-8 kHz: {np.mean([band_db(b1, 3000, 8000, BUILD_AT + t_c, BUILD_AT + t_c + 0.06) - band_db(old_build, 3000, 8000, BUILD_AT + t_c, BUILD_AT + t_c + 0.06) for t_c, _, _ in CHISELS]):+.1f} dB fata de inainte")
    i_pk = int(np.argmax(np.abs(build)))
    stones = {"piatra mare": 1.625, "piatra mica": 2.375}
    near = min(stones, key=lambda k: abs(stones[k] - i_pk / SR))
    print(f"      varful fisierului: la {BUILD_AT + i_pk / SR:.3f} s ({near}, atingerea la {BUILD_AT + stones[near]:.3f} s), "
          f"{20 * np.log10(np.abs(build[i_pk])):.1f} dBFS")
    # 4) cat din varf se aude pe un difuzor de telefon
    print("    ce ramane pe un difuzor de telefon (trece-sus 300 Hz):")
    for nm, sig in (("sfx_film_build", build), ("sfx_film_close", close)):
        hp = highpass(sig, 300.0)
        print(f"      {nm}: varf intreg {20 * np.log10(np.max(np.abs(sig))):.1f} dBFS, dupa trece-sus {20 * np.log10(np.max(np.abs(hp))):.1f} dBFS")
    r100 = lambda x: 20 * np.log10(np.sqrt(np.mean(x[: int(0.1 * SR)] ** 2)) + 1e-12)  # noqa: E731
    print(f"      sfx_film_close, RMS primele 100 ms: {r100(close):.1f} dBFS intreg, {r100(highpass(close, 300.0)):.1f} dBFS pe telefon "
          f"(inainte de verificator: -11 -> -28)")
    # 5) la nivelurile implicite din joc muzica e mult mai jos decat in mixul de mai sus
    print(f"    ATENTIE nivelurile din joc: muzica la nivelul implicit 4 din 10 = 0,6 x 0,16 = 0,096, efectele la nivelul 10 = 1,0, deci "
          f"fata de mixul de mai sus efectele sunt cu {20 * np.log10(1 / 0.096):.1f} dB mai sus (santier {20 * np.log10(VOL_BUILD / 0.096):+.1f} dB, "
          f"inchidere {20 * np.log10(VOL_CLOSE / 0.096):+.1f} dB fata de muzica la volum egal): vezi film_mix_default_levels.mp3")


def music_report(sig):
    """Cromagrama acordului de la 14,0 s (Do# nu trebuie sa-l murdareasca pe Re) si tabelul notelor de fluier (nivel dupa lant fata de
    castigul scris: izolat si in pista fluierului)."""
    print("    cromagrama (70-2000 Hz, mono, fata de clasa cea mai tare; tinta: Do# cel mult -10 dB fata de Re pe 14,0-14,3 s):")
    for a, b in ((14.0, 14.3), (14.3, 14.7), (15.2, 15.6)):
        d = chroma_db(sig, a, b)
        top = ", ".join(f"{NOTE_NAMES[i]} {d[i]:+.1f}" for i in np.argsort(-d)[:5])
        print(f"      {a:4.1f}-{b:4.1f} s: {top}   -> Do# fata de Re {d[1] - d[2]:+.1f} dB")
    print("    fluierul, nivel dupa lantul masterului (mixul mono, [t, t + durata]) fata de castigul scris, dB: 'izolat' = nota singura, 'in pista' =")
    print("    toate notele fluierului impreuna (cu cozile vecinelor); tinta: fiecare in +-1,5 dB; 'brut' = abaterea reverbului inainte de corectie")
    print("       t(s)  nota  durata  castig   brut   corectie   izolat  in pista")
    for r in FLUTE_LOG:
        nm = f"{NOTE_NAMES[r['midi'] % 12]}{r['midi'] // 12 - 1}"
        print(f"      {r['t']:5.2f}  {nm:4s}  {r['secs']:5.1f}   {r['gain']:.3f}  {r['dev']:+5.1f}   {r['k_db']:+6.1f}    {r['iso']:+6.1f}   {r['ctx']:+6.1f}")
    w_iso, w_ctx = max(abs(r["iso"]) for r in FLUTE_LOG), max(abs(r["ctx"]) for r in FLUTE_LOG)
    print(f"      abaterea cea mai mare dupa corectie: izolat {w_iso:.2f} dB, in pista {w_ctx:.2f} dB (tinta 1,5); "
          f"inainte de corectie: {max(abs(r['dev']) for r in FLUTE_LOG):.1f} dB")
    # linistea de la sfarsit, asa cum ajunge in WAV (16 biti)
    pcm = np.round(np.clip(sig, -1, 1) * 32767).astype(np.int16)
    tail = int(np.max(np.abs(pcm[:, -int(0.01 * SR) :])))
    print(f"    capat (WAV pe 16 biti): ultimele 10 ms au varful {tail} din 32767 ({'liniste digitala' if tail == 0 else 'NU e liniste digitala'}), "
          f"{pcm.shape[1]} de esantioane = {pcm.shape[1] / SR:.3f} s")


def write_mix_preview(out, mix, name):
    """Mixul normalizat la -3 dBFS (rapoartele dintre straturi raman cele ale mixului) ca MP3 de ascultat."""
    peak = np.max(np.abs(mix))
    y = mix * (10 ** (-3.1 / 20) / peak)
    base = os.path.join(out, name)
    mm.write_wav(base + ".wav", y[0], y[1])
    subprocess.run([LAME, "--silent", "-V", "2", base + ".wav", base + ".mp3"], check=True)
    os.remove(base + ".wav")
    return y, 20 * np.log10(peak)


# ---- main ---------------------------------------------------------------------------------------------


def main():
    args = sys.argv[1:]
    out = DEFAULT_OUT
    if "--out" in args:
        i = args.index("--out")
        out = args[i + 1]
        del args[i : i + 2]
    keys = args or ["music", "build", "close", "altcreak"]
    os.makedirs(out, exist_ok=True)
    items = []
    results = []
    finals = {}  # semnalele finale (dupa scaderea de varf de la encode), pentru mix si masuratori
    for key in keys:
        if key == "music":
            L, R = make_music()
            base = os.path.join(out, "music_dam_film")
            sig, ogg_peak = encode(lambda p, x: write_stereo(p, x[0], x[1]), base, np.stack([L, R]), -3.05)
            st = stats("music_dam_film", sig)
            ph_rms = []
            for a, b, nm in PHASES:
                seg = sig[:, int(a * SR) : int(b * SR)]
                ph_rms.append(f"{nm} {20 * np.log10(np.sqrt(np.mean(seg ** 2)) + 1e-12):.1f}")
            first = np.max(np.abs(sig[:, : int(0.05 * SR)]))
            last = np.max(np.abs(sig[:, -int(0.05 * SR) :]))
            print(f"  music_dam_film   {st['dur']:7.3f}s  peak {st['peak_db']:6.2f} dBFS  rms {st['rms_db']:6.2f} dBFS  "
                  f"primul/ultimul esantion {sig[0, 0]:+.5f}/{sig[0, -1]:+.5f}  (max 50 ms: inceput {first:.4f}, sfarsit {last:.5f})  OGG decodat: {ogg_peak:.2f} dBFS")
            print(f"    RMS pe faze (dBFS): " + ", ".join(ph_rms))
            music_report(sig)
            items.append(("music_dam_film  (stereo, 17.0 s)", sig, PHASES,
                          f"peak {st['peak_db']:.2f} dBFS   rms {st['rms_db']:.2f} dBFS"))
            results.append(base)
            finals["music"] = sig
        elif key in ("build", "close", "altcreak"):
            sig = make_close() if key == "close" else make_build("buzz" if key == "altcreak" else "rope")
            fname = {"build": "sfx_film_build", "close": "sfx_film_close", "altcreak": "sfx_film_build_altcreak"}[key]
            base = os.path.join(out, fname)
            sig, ogg_peak = encode(ms.write_wav, base, sig, -3.05 if key == "close" else -6.05)
            st = stats(fname, sig)
            print(f"  {fname:24s} {st['dur']:6.3f}s  peak {st['peak_db']:6.2f} dBFS  rms {st['rms_db']:6.2f} dBFS  "
                  f"primul/ultimul esantion {sig[0]:+.5f}/{sig[-1]:+.5f}  OGG decodat: {ogg_peak:.2f} dBFS")
            if key != "altcreak":  # alternativa de ascultat nu are panou in previzualizare
                items.append((f"{fname}  (mono, {st['dur']:.2f} s)", sig, None,
                              f"peak {st['peak_db']:.2f} dBFS   rms {st['rms_db']:.2f} dBFS"))
            results.append(base)
            finals[key] = sig
        else:
            print(f"  ! cheie necunoscuta: {key} (music, build, close sau altcreak)")
    if all(k in finals for k in ("music", "build", "close")):
        music, build, close = finals["music"], finals["build"], finals["close"]
        mix, raw_peak = write_mix_preview(out, mix_down(music, build, close), "film_mix_preview")
        # la nivelurile implicite din joc muzica e la 0,096 (nivelul 4 din 10 x 0,6 x 0,16), efectele la 1,0 (nivelul 10): vezi antetul
        write_mix_preview(out, mix_down(music, build, close, music_gain=0.096), "film_mix_default_levels")
        print(f"  mix (muzica + santier la {BUILD_AT} s x{VOL_BUILD} + inchidere la {MEET_AT} s x{VOL_CLOSE}): varf brut {raw_peak:.2f} dBFS, "
              f"normalizat la -3,1; film_mix_default_levels = muzica la 0,096 (nivelul implicit din joc)")
        items.append(("film_mix_preview  (stereo, 17.0 s)", mix, PHASES,
                      f"music + sfx_film_build x{VOL_BUILD} at {BUILD_AT} s + sfx_film_close x{VOL_CLOSE} at {MEET_AT} s, normalized to -3.1 dBFS",
                      [(BUILD_AT, f"sfx_film_build {BUILD_AT} s"), (MEET_AT, f"sfx_film_close {MEET_AT} s")]))
        report(music, build, close)
    if len(items) == 4:
        preview(items, os.path.join(out, "sound_preview.png"))
        print(f"  previzualizare: {os.path.join(out, 'sound_preview.png')}")
    for base in results:
        print(f"  {base}.wav / .ogg / .mp3")


if __name__ == "__main__":
    main()
