"""Satie, Gnossienne No. 3 (1890), as note data for render.py.

Source: the first edition, Paris: Rouart, Lerolle & Cie., 1913 (public domain), scan in
src/score/satie-gnossiennes-1913.pdf, pages 5-6. Read bar by bar from that scan.

The score has no barlines; bars here follow its 4/4 left-hand pattern (54 bars).
Melody tokens: "Pitch:eighths" for a note, "r:eighths" for a rest, "_:eighths" to hold the previous
note on into this bar, "g:Pitch" for a grace note before the next note. A bare pitch is one eighth.
Left hand per bar: bass note on beat 1 (held all bar), chord on beat 2 (half) and beat 4 (quarter).
"""

A1 = "A5 A5 D#5 D#5 F#5 F#5:3"
A2 = "r:2 E5 E5 D#5 D#5 C5 C5"
A3 = "B4 B4:3 r:4"
REST = "r:8"
D1 = "E4 F#4 G4 A#4 B4 C#5 E5 C#5"
D2 = "B4 A#4 G4 F#4 E4 F#4 G4 A#4"
D3 = "B4 C#5 E5 C#5 B4 A#4 G4 F#4"
D5 = "D5 D5:3 r:4"
F1 = "G#4 B4 C5 D#5 D5 C5 B4 G#4"
F2 = "C5 C5:3 r:4"

MELODY = [
    # A
    A1, A2, A3, REST, A1, A2, A3,
    "g:B4 D5:2 B4 B4 C5 C5:3", A3,
    # B
    "g:B4 D5:8", "_:2 B4 B4 D5 D5 B4 B4",
    "G#4 A4 B4 D5 B4 A4 G#4 A4", "B4 D5 B4 A4 G#4 A4 B4 D5",
    "F5 F5 A4 A4:3 r:2", REST,
    # C
    "E5 E5 A#4 A#4 C#5 C#5:3", "r:2 B4 B4 A#4 A#4 G4 G4", "F#4 F#4:3 r:4", REST,
    "E5 E5 A#4 A#4 C#5 C#5:3", "r:2 B4 B4 A#4 A#4 G4 G4", "F#4 F#4:3 r:4",
    "g:F#4 A4:8",
    # D, twice
    D1, D2, D3, D1, D5, REST,
    D1, D2, D3, D1, D5,
    # E
    "g:F#4 A4:8", "_:4 r:4", "g:C5 G#4:8", "_:4 r:4",
    # F
    F1, F2, "g:B4 D5:8", "_:4 r:4", F1, F2, "g:B4 D5:8",
    # A again
    A1, A2, A3, REST, A1, A2,
    "B4 B4:3 r:2 B4 B4", "E5 E5:3 r:4", REST,
]

Am = ("A2", "C4 E4 A4")
Em = ("E2", "G3 B3 E4")
Dm = ("D2", "A3 D4 F4")
Bm = ("B1", "F#3 B3 D4")
Fm = ("F2", "G#3 C4 F4")
LEFT = [
    Am, Am, Em, Em, Am, Am, Em, ("D3", "A3 D4 F4"), ("E2", "G#3 B3 E4"),
    Dm, Dm, Dm, Dm, ("A1", "A3 C4 E4"), ("A2", "A3 C4 E4"),
    Em, Em, Bm, Bm, Em, Em, Bm, ("F#1", "A3 C#4 F#4"),
    Em, Em, Em, Em, Bm, Bm,
    Em, Em, Em, Em, Bm,
    ("A1", "A3 C4 E4"), ("A2", "A3 C4 E4"), Fm, Fm,
    Fm, Fm, Dm, Dm, Fm, Fm, Dm,
    Am, Am, Em, Em, Am, Am, Em, ("A1", "A3 C4 E4"), ("A2", "A3 C4 E4"),
]

# Bars that close a phrase: the player lingers at their end.
PHRASE_ENDS = {4, 9, 15, 19, 23, 29, 34, 36, 38, 40, 42, 44, 45, 49, 54}
# Swells written in the score (bar: peak extra loudness, 0..1).
SWELLS = {12: 0.25, 13: 0.15, 25: 0.3, 26: 0.2, 31: 0.25, 32: 0.15, 39: 0.25, 43: 0.25}

assert len(MELODY) == 54 and len(LEFT) == 54
